#!/usr/bin/env python3
"""Local RFC 6455 handshake/frame contract for the optional PHP adapter."""

from __future__ import annotations

import base64
import hashlib
import pathlib
import socketserver
import struct
import subprocess
import threading

ROOT = pathlib.Path(__file__).resolve().parents[2]
received: dict[str, object] = {}


def read_exact(stream, count: int) -> bytes:
    data = stream.read(count)
    if len(data) != count:
        raise EOFError("short WebSocket frame")
    return data


def send_frame(stream, opcode: int, payload: bytes) -> None:
    if len(payload) >= 126:
        header = bytes([0x80 | opcode, 126]) + struct.pack("!H", len(payload))
    else:
        header = bytes([0x80 | opcode, len(payload)])
    stream.write(header + payload)
    stream.flush()


class Handler(socketserver.StreamRequestHandler):
    def handle(self) -> None:
        first = self.rfile.readline().decode().strip()
        headers = {}
        while True:
            line = self.rfile.readline().decode().strip()
            if not line:
                break
            name, value = line.split(":", 1)
            headers[name.lower()] = value.strip()
        received["path"] = first.split()[1]
        received["auth"] = headers.get("authorization")
        key = headers["sec-websocket-key"]
        accept = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
        self.wfile.write(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                          f"Sec-WebSocket-Accept: {accept}\r\n\r\n").encode())
        self.wfile.flush()
        send_frame(self.wfile, 1, b'{"type":"Connected","request_id":"ws-contract","sequence_id":0}')
        while True:
            first, second = read_exact(self.rfile, 2)
            opcode = first & 0x0F
            length = second & 0x7F
            if length == 126:
                length = struct.unpack("!H", read_exact(self.rfile, 2))[0]
            elif length == 127:
                length = struct.unpack("!Q", read_exact(self.rfile, 8))[0]
            mask = read_exact(self.rfile, 4) if second & 0x80 else b""
            payload = read_exact(self.rfile, length)
            if mask:
                payload = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
            if opcode == 2:
                received["audio"] = payload
            elif opcode == 8:
                send_frame(self.wfile, 8, payload)
                break


def main() -> None:
    server = socketserver.TCPServer(("127.0.0.1", 0), Handler)
    server.timeout = 5
    thread = threading.Thread(target=server.handle_request, daemon=True)
    thread.start()
    try:
        code = (
            "require 'sdks/php/vendor/autoload.php'; "
            "$client = new DeepgramSdkLab\\Client('test-key', null, $argv[1]); "
            "$stream = $client->listen->connectV2(); "
            "$stream->sendAudio(chr(1).chr(2)); "
            "$event = $stream->receive(); "
            "if ($event->type !== 'Connected' || $event->payload->requestId !== 'ws-contract') { exit(1); } "
            "$stream->close();"
        )
        subprocess.run(["php", "-r", code, "--", f"http://127.0.0.1:{server.server_address[1]}"],
                       cwd=ROOT, check=True, timeout=15)
        thread.join(timeout=5)
        assert received["path"] == "/v2/listen?model=flux-general-en", received
        assert received["auth"] == "Token test-key", received
        assert received["audio"] == b"\x01\x02", received
        print("PHP WebSocket adapter contract passed")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

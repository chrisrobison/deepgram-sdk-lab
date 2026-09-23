#!/usr/bin/env python3
"""Exercise the PHP cURL file transport against a local HTTP server."""

from __future__ import annotations

import http.server
import pathlib
import subprocess
import tempfile
import threading

ROOT = pathlib.Path(__file__).resolve().parents[2]
FIXTURE = (ROOT / "tests/fixtures/prerecorded-response.json").read_bytes()
received: dict[str, object] = {}


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        size = int(self.headers.get("Content-Length", "0"))
        received.update(path=self.path, body=self.rfile.read(size), auth=self.headers.get("Authorization"),
                        content_type=self.headers.get("Content-Type"))
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(FIXTURE)))
        self.end_headers()
        self.wfile.write(FIXTURE)

    def log_message(self, format: str, *args: object) -> None:
        pass


def main() -> None:
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with tempfile.NamedTemporaryFile(suffix=".wav") as audio:
            audio.write(b"\x01\x02\x03\x04")
            audio.flush()
            code = (
                "require 'sdks/php/tests/bootstrap.php'; "
                "$client = new DeepgramSdkLab\\Client('test-key', null, $argv[2]); "
                "$result = $client->listen->transcribeFile($argv[1], 'audio/wav'); "
                "if ($result->metadata->requestId === '') { exit(1); }"
            )
            subprocess.run(["php", "-r", code, "--", audio.name, f"http://127.0.0.1:{server.server_port}"],
                           cwd=ROOT, check=True, timeout=30)
        assert received["path"] == "/v1/listen?model=nova-3", received
        assert received["body"] == b"\x01\x02\x03\x04", received
        assert received["auth"] == "Token test-key", received
        assert received["content_type"] == "audio/wav", received
        print("PHP cURL file upload contract passed")
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()

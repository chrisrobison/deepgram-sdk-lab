<?php
declare(strict_types=1);

namespace DeepgramSdkLab\Realtime;

use DeepgramSdkLab\ConfigurationException;
use WebSocket\Client as WebSocketClient;

/** Optional adapter. Install phrity/websocket:^3.8 for live realtime use. */
final class PhritySocket implements Socket
{
    private WebSocketClient $client;

    /** @param array<string, string> $headers */
    public function __construct(string $url, array $headers)
    {
        if (!class_exists(WebSocketClient::class)) {
            throw new ConfigurationException('Realtime requires: composer require phrity/websocket:^3.8');
        }
        $this->client = new WebSocketClient($url);
        foreach ($headers as $name => $value) { $this->client->addHeader($name, $value); }
    }

    public function connect(): void { $this->client->connect(); }
    public function sendBinary(string $bytes): void { $this->client->binary($bytes); }
    public function sendText(string $text): void { $this->client->text($text); }
    public function receive(): Frame
    {
        $message = $this->client->receive();
        return new Frame($message->getContent(), $message->getOpcode() === 'binary');
    }
    public function close(): void { $this->client->close(); }
}

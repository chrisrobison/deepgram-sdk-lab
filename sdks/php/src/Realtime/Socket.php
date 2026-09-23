<?php
declare(strict_types=1);
namespace DeepgramSdkLab\Realtime;
interface Socket
{
    public function connect(): void;
    public function sendBinary(string $bytes): void;
    public function sendText(string $text): void;
    public function receive(): Frame;
    public function close(): void;
}

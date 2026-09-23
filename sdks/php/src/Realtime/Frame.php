<?php
declare(strict_types=1);
namespace DeepgramSdkLab\Realtime;
final readonly class Frame
{
    public function __construct(public string $content, public bool $binary) {}
}

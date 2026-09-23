<?php
declare(strict_types=1);
namespace DeepgramSdkLab;
final readonly class SpeechAudio
{
    public function __construct(
        public string $bytes,
        public string $contentType,
        public ?string $requestId,
        public ?string $modelName,
    ) {}
}

<?php
declare(strict_types=1);
namespace DeepgramSdkLab;
class ApiException extends DeepgramException
{
    public function __construct(int $status, public readonly ?string $requestId, string $message)
    { parent::__construct("Deepgram HTTP $status (request " . ($requestId ?? 'unknown') . "): $message", $status); }
}

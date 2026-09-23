<?php
declare(strict_types=1);
namespace DeepgramSdkLab;
class MalformedResponseException extends DeepgramException
{
    public function __construct(string $message, public readonly ?string $requestId = null, ?\Throwable $previous = null)
    { parent::__construct($message, 0, $previous); }
}

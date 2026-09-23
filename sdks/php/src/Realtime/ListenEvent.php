<?php
declare(strict_types=1);

namespace DeepgramSdkLab\Realtime;

/** Payload is a generated model for known event types; unknown events retain decoded JSON. */
final readonly class ListenEvent
{
    public function __construct(public string $type, public mixed $payload) {}
}

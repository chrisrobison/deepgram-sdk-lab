<?php
declare(strict_types=1);

namespace DeepgramSdkLab\Realtime;

use DeepgramSdkLab\ConfigurationException;
use DeepgramSdkLab\ConnectionException;
use DeepgramSdkLab\Generated\ListenV1_ListenV1Metadata;
use DeepgramSdkLab\Generated\ListenV1_ListenV1Results;
use DeepgramSdkLab\Generated\ListenV1_ListenV1SpeechStarted;
use DeepgramSdkLab\Generated\ListenV1_ListenV1UtteranceEnd;
use DeepgramSdkLab\Generated\ListenV2_ListenV2ConfigureFailure;
use DeepgramSdkLab\Generated\ListenV2_ListenV2ConfigureSuccess;
use DeepgramSdkLab\Generated\ListenV2_ListenV2Connected;
use DeepgramSdkLab\Generated\ListenV2_ListenV2FatalError;
use DeepgramSdkLab\Generated\ListenV2_ListenV2TurnInfo;
use JsonException;
use Throwable;

final class ListenStream
{
    private bool $closed = false;

    public function __construct(private readonly Socket $socket, private readonly string $version)
    {
        if (!in_array($version, ['v1', 'v2'], true)) { throw new ConfigurationException('Invalid Listen version'); }
    }

    public function sendAudio(string $bytes): void
    {
        $this->ensureOpen();
        if ($bytes === '') { return; }
        try { $this->socket->sendBinary($bytes); }
        catch (Throwable $error) { $this->fail($error); }
    }

    public function finalize(): void
    {
        if ($this->version !== 'v1') { throw new ConfigurationException('Finalize requires Listen v1'); }
        $this->control('Finalize');
    }

    public function forceEndTurn(): void
    {
        if ($this->version !== 'v2') { throw new ConfigurationException('ForceEndTurn requires Listen v2'); }
        $this->control('ForceEndTurn');
    }

    private function control(string $type): void
    {
        $this->ensureOpen();
        try { $this->socket->sendText(json_encode(['type' => $type], JSON_THROW_ON_ERROR)); }
        catch (Throwable $error) { $this->fail($error); }
    }

    public function receive(): ListenEvent
    {
        $this->ensureOpen();
        try { $frame = $this->socket->receive(); }
        catch (Throwable $error) { $this->fail($error); }
        if ($frame->binary) { return new ListenEvent('UnexpectedBinary', $frame->content); }
        try {
            $data = json_decode($frame->content, true, 512, JSON_THROW_ON_ERROR);
            if (!is_array($data) || array_is_list($data)) { return new ListenEvent('Malformed', $frame->content); }
            $type = $data['type'] ?? null;
            if (!is_string($type)) { return new ListenEvent('Unknown', $data); }
            $model = match ($type) {
                'Results' => ListenV1_ListenV1Results::class,
                'Metadata' => ListenV1_ListenV1Metadata::class,
                'UtteranceEnd' => ListenV1_ListenV1UtteranceEnd::class,
                'SpeechStarted' => ListenV1_ListenV1SpeechStarted::class,
                'Connected' => ListenV2_ListenV2Connected::class,
                'TurnInfo' => ListenV2_ListenV2TurnInfo::class,
                'ConfigureSuccess' => ListenV2_ListenV2ConfigureSuccess::class,
                'ConfigureFailure' => ListenV2_ListenV2ConfigureFailure::class,
                'Error' => ListenV2_ListenV2FatalError::class,
                default => null,
            };
            if ($model === null) { return new ListenEvent($type, $data); }
            try { $payload = $model::fromArray($data); }
            catch (Throwable) { return new ListenEvent('Malformed', $frame->content); }
            if ($type === 'Error') {
                $this->closed = true;
                $this->socket->close();
            }
            return new ListenEvent($type, $payload);
        } catch (JsonException) {
            return new ListenEvent('Malformed', $frame->content);
        }
    }

    /** @return \Generator<ListenEvent> */
    public function events(): \Generator
    {
        while (!$this->closed) { yield $this->receive(); }
    }

    public function close(): void
    {
        if ($this->closed) { return; }
        $this->closed = true;
        try { $this->socket->sendText('{"type":"CloseStream"}'); }
        finally { $this->socket->close(); }
    }

    private function ensureOpen(): void
    {
        if ($this->closed) { throw new ConnectionException('Listen stream is closed'); }
    }

    private function fail(Throwable $error): never
    {
        $this->closed = true;
        $this->socket->close();
        throw new ConnectionException('Listen stream interrupted; audio was not replayed: ' . $error->getMessage(), 0, $error);
    }
}

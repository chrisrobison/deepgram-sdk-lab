<?php
declare(strict_types=1);

namespace DeepgramSdkLab;

use DeepgramSdkLab\Generated\SpeakV1Request;
use DeepgramSdkLab\Generated\SpecVersion;

final readonly class Speak
{
    public function __construct(private Client $client) {}

    /** @param array<string, string|int|bool> $options */
    public function generate(string $text, array $options = []): SpeechAudio
    {
        if ($text === '') { throw new ConfigurationException('Text is empty'); }
        $body = json_encode(new SpeakV1Request(text: $text), JSON_THROW_ON_ERROR);
        $response = $this->client->post(SpecVersion::SPEAK_V1_PATH, $options + ['model' => 'aura-2-asteria-en'], $body, 'application/json');
        $contentType = $response->header('content-type');
        if ($contentType === null || !str_starts_with(strtolower($contentType), 'audio/') || $response->body === '') {
            throw new MalformedResponseException('Expected nonempty audio response', $response->header('dg-request-id'));
        }
        return new SpeechAudio($response->body, $contentType, $response->header('dg-request-id'), $response->header('dg-model-name'));
    }
}

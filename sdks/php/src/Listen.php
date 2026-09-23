<?php
declare(strict_types=1);

namespace DeepgramSdkLab;

use DeepgramSdkLab\Generated\ListenV1RequestUrl;
use DeepgramSdkLab\Generated\ListenV1Response;
use DeepgramSdkLab\Generated\SpecVersion;
use DeepgramSdkLab\Http\FileBody;
use DeepgramSdkLab\Realtime\ListenStream;
use DeepgramSdkLab\Realtime\Socket;
use JsonException;
use Throwable;

final readonly class Listen
{
    public function __construct(private Client $client) {}

    /** @param array<string, string|int|bool> $options */
    public function transcribeUrl(string $url, array $options = []): ListenV1Response
    {
        if (!filter_var($url, FILTER_VALIDATE_URL)) { throw new ConfigurationException('Invalid audio URL'); }
        $body = json_encode(new ListenV1RequestUrl(url: $url), JSON_THROW_ON_ERROR);
        return $this->decode($this->client->post(SpecVersion::LISTEN_V1_PATH, $options + ['model' => 'nova-3'], $body, 'application/json'));
    }

    /** @param array<string, string|int|bool> $options */
    public function transcribeBytes(string $audio, string $contentType, array $options = []): ListenV1Response
    {
        if ($audio === '') { throw new ConfigurationException('Audio is empty'); }
        return $this->decode($this->client->post(SpecVersion::LISTEN_V1_PATH, $options + ['model' => 'nova-3'], $audio, $contentType));
    }

    /** @param array<string, string|int|bool> $options */
    public function transcribeFile(string $path, string $contentType, array $options = []): ListenV1Response
    {
        return $this->decode($this->client->post(SpecVersion::LISTEN_V1_PATH, $options + ['model' => 'nova-3'], new FileBody($path), $contentType));
    }

    /** @param array<string, string|int|bool> $options */
    public function connectV1(string $model = 'nova-3', array $options = [], ?Socket $socket = null): ListenStream
    {
        return $this->client->openListenStream('v1', $options + ['model' => $model], $socket);
    }

    /** @param array<string, string|int|bool> $options */
    public function connectV2(string $model = 'flux-general-en', array $options = [], ?Socket $socket = null): ListenStream
    {
        if (array_key_exists('encoding', $options) !== array_key_exists('sample_rate', $options)) {
            throw new ConfigurationException('Raw Flux audio requires both encoding and sample_rate');
        }
        return $this->client->openListenStream('v2', $options + ['model' => $model], $socket);
    }

    private function decode(\DeepgramSdkLab\Http\Response $response): ListenV1Response
    {
        try {
            $data = json_decode($response->body, true, 512, JSON_THROW_ON_ERROR);
            if (!is_array($data)) { throw new \UnexpectedValueException('Expected JSON object'); }
            return ListenV1Response::fromArray($data);
        } catch (Throwable $error) {
            throw new MalformedResponseException('Could not decode transcription response', $response->header('dg-request-id'), $error);
        }
    }
}

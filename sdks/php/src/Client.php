<?php
declare(strict_types=1);

namespace DeepgramSdkLab;

use DeepgramSdkLab\Http\CurlTransport;
use DeepgramSdkLab\Http\FileBody;
use DeepgramSdkLab\Http\Request;
use DeepgramSdkLab\Http\Response;
use DeepgramSdkLab\Http\Transport;

final class Client
{
    public const VERSION = '0.1.0';
    public readonly Listen $listen;
    public readonly Speak $speak;
    private readonly Transport $transport;

    public function __construct(
        private readonly string $apiKey,
        ?Transport $transport = null,
        private readonly string $baseUrl = 'https://api.deepgram.com',
        private readonly int $maxAttempts = 1,
    ) {
        if (trim($apiKey) === '') { throw new ConfigurationException('API key is empty'); }
        if ($maxAttempts < 1) { throw new ConfigurationException('maxAttempts must be at least one'); }
        $parts = parse_url($baseUrl);
        if (!is_array($parts) || !isset($parts['host']) || (($parts['scheme'] ?? '') !== 'https' && !in_array($parts['host'], ['localhost', '127.0.0.1'], true))) {
            throw new ConfigurationException('baseUrl must use HTTPS except for localhost');
        }
        $this->transport = $transport ?? new CurlTransport();
        $this->listen = new Listen($this);
        $this->speak = new Speak($this);
    }

    /** @param array<string, string|int|bool> $query */
    public function post(string $path, array $query, string|FileBody $body, string $contentType): Response
    {
        $parameters = [];
        foreach ($query as $key => $value) { $parameters[$key] = is_bool($value) ? ($value ? 'true' : 'false') : (string) $value; }
        $url = rtrim($this->baseUrl, '/') . $path . ($parameters === [] ? '' : '?' . http_build_query($parameters, '', '&', PHP_QUERY_RFC3986));
        $request = new Request('POST', $url, [
            'Authorization' => 'Token ' . $this->apiKey,
            'Content-Type' => $contentType,
            'User-Agent' => 'deepgram-sdk-lab-php/' . self::VERSION,
        ], $body);
        for ($attempt = 1; $attempt <= $this->maxAttempts; $attempt++) {
            $response = $this->transport->send($request);
            if ($response->status >= 200 && $response->status < 300) { return $response; }
            if (in_array($response->status, [429, 503], true) && $attempt < $this->maxAttempts) {
                usleep(250_000);
                continue;
            }
            $message = self::errorMessage($response->body) ?? 'HTTP error';
            $id = $response->header('dg-request-id');
            if (in_array($response->status, [401, 403], true)) { throw new AuthenticationException($response->status, $id, $message); }
            throw new ApiException($response->status, $id, $message);
        }
        throw new TransportException('Retry attempts exhausted');
    }

    private static function errorMessage(string $body): ?string
    {
        $decoded = json_decode($body, true);
        if (is_array($decoded)) {
            foreach (['message', 'err_msg', 'error'] as $key) {
                if (isset($decoded[$key]) && is_string($decoded[$key])) { return $decoded[$key]; }
            }
        }
        return $body === '' ? null : $body;
    }
}

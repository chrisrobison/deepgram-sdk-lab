<?php
declare(strict_types=1);

namespace DeepgramSdkLab\Http;

use DeepgramSdkLab\TransportException;

final class CurlTransport implements Transport
{
    public function __construct(private readonly int $timeoutSeconds = 60) {}

    public function send(Request $request): Response
    {
        $handle = curl_init($request->url);
        if ($handle === false) { throw new TransportException('Could not initialize cURL'); }
        $headers = [];
        curl_setopt_array($handle, [
            CURLOPT_CUSTOMREQUEST => $request->method,
            CURLOPT_HTTPHEADER => array_map(static fn (string $key, string $value): string => "$key: $value", array_keys($request->headers), array_values($request->headers)),
            CURLOPT_POSTFIELDS => $request->body,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => $this->timeoutSeconds,
            CURLOPT_HEADERFUNCTION => static function ($handle, string $line) use (&$headers): int {
                if (str_starts_with($line, 'HTTP/')) { $headers = []; }
                $position = strpos($line, ':');
                if ($position !== false) { $headers[strtolower(trim(substr($line, 0, $position)))] = trim(substr($line, $position + 1)); }
                return strlen($line);
            },
        ]);
        try {
            $body = curl_exec($handle);
            if ($body === false) { throw new TransportException(curl_error($handle)); }
            return new Response(curl_getinfo($handle, CURLINFO_RESPONSE_CODE), $headers, $body);
        } finally {
            curl_close($handle);
        }
    }
}

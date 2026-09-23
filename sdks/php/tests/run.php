<?php
declare(strict_types=1);

require __DIR__ . '/bootstrap.php';

use DeepgramSdkLab\AuthenticationException;
use DeepgramSdkLab\Client;
use DeepgramSdkLab\Generated\ListenV1Response;
use DeepgramSdkLab\Http\FileBody;
use DeepgramSdkLab\Http\Request;
use DeepgramSdkLab\Http\Response;
use DeepgramSdkLab\Http\Transport;

final class FakeTransport implements Transport
{
    public ?Request $request = null;
    public function __construct(public Response $response) {}
    public function send(Request $request): Response
    {
        $this->request = $request;
        return $this->response;
    }
}

function check(bool $condition, string $message): void
{
    if (!$condition) { throw new RuntimeException($message); }
}

$fixture = file_get_contents(dirname(__DIR__, 3) . '/tests/fixtures/prerecorded-response.json');
check($fixture !== false, 'Fixture missing');
$decoded = ListenV1Response::fromArray(json_decode($fixture, true, 512, JSON_THROW_ON_ERROR));
check($decoded->metadata->requestId === '550e8400-e29b-41d4-a716-446655440000', 'Request ID decoding');
check($decoded->results->channels[0]->alternatives[0]->words[0]->end === 0.4, 'Numeric-string word timing');
check($decoded->metadata->modelInfo['nova-3']['name'] === 'nova-3', 'Unknown model metadata preserved');

$transport = new FakeTransport(new Response(200, ['dg-request-id' => 'test-id', 'content-type' => 'application/json'], $fixture));
$result = (new Client('test-key', $transport))->listen->transcribeUrl('https://example.com/audio.wav', ['smart_format' => true]);
check($result->results->channels[0]->alternatives[0]->transcript === 'Hello world.', 'Transcript decoding');
check(str_contains($transport->request->url, 'smart_format=true'), 'Boolean query encoding');
check($transport->request->headers['Authorization'] === 'Token test-key', 'Authorization header');
check($transport->request->headers['User-Agent'] === 'deepgram-sdk-lab-php/0.1.0', 'User agent');

$temporary = tempnam(sys_get_temp_dir(), 'deepgram-audio-');
check($temporary !== false, 'Could not create audio fixture');
try {
    file_put_contents($temporary, "\x01\x02\x03");
    (new Client('test-key', $transport))->listen->transcribeFile($temporary, 'audio/wav');
    check($transport->request->body instanceof FileBody && $transport->request->body->size === 3, 'File body streams without buffering');
} finally {
    unlink($temporary);
}

$transport->response = new Response(200, ['content-type' => 'audio/mpeg', 'dg-request-id' => 'tts-id'], "\x01\x02");
$audio = (new Client('test-key', $transport))->speak->generate('Hello', ['model' => 'aura-2-thalia-en']);
check($audio->bytes === "\x01\x02" && $audio->requestId === 'tts-id', 'TTS binary response');
check(str_contains($transport->request->url, 'model=aura-2-thalia-en'), 'TTS model override');

$transport->response = new Response(401, ['dg-request-id' => 'auth-id'], '{"message":"invalid key"}');
try {
    (new Client('test-key', $transport))->listen->transcribeUrl('https://example.com/audio.wav');
    throw new RuntimeException('Authentication error missing');
} catch (AuthenticationException $error) {
    check($error->requestId === 'auth-id' && $error->getCode() === 401, 'Authentication error context');
}

echo "PHP offline contracts passed\n";

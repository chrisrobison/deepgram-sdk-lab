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
use DeepgramSdkLab\Realtime\Frame;
use DeepgramSdkLab\Realtime\Socket;

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

final class FakeSocket implements Socket
{
    /** @var list<Frame> */
    public array $frames = [];
    /** @var list<string> */
    public array $binarySent = [];
    /** @var list<string> */
    public array $textSent = [];
    public bool $closed = false;
    public bool $connected = false;
    public function connect(): void { $this->connected = true; }
    public function sendBinary(string $bytes): void { $this->binarySent[] = $bytes; }
    public function sendText(string $text): void { $this->textSent[] = $text; }
    public function receive(): Frame
    {
        if ($this->frames === []) { throw new RuntimeException('Simulated server close'); }
        return array_shift($this->frames);
    }
    public function close(): void { $this->closed = true; }
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

$socket = new FakeSocket();
$socket->frames = [
    new Frame('{"type":"Connected","request_id":"flux-id","sequence_id":0}', false),
    new Frame('{"type":"TurnInfo","request_id":"flux-id","sequence_id":1,"event":"EndOfTurn","turn_index":0,"audio_window_start":0,"audio_window_end":"1.3","transcript":"Hello","words":[],"end_of_turn_confidence":0.86}', false),
    new Frame('{"type":"FutureEvent","detail":2}', false),
    new Frame('{broken', false),
];
$stream = (new Client('test-key', $transport))->listen->connectV2(options: ['encoding' => 'linear16', 'sample_rate' => 16000], socket: $socket);
check($socket->connected, 'Realtime connect');
$stream->sendAudio("\x01");
$stream->sendAudio("\x02");
check($socket->binarySent === ["\x01", "\x02"], 'Partial audio chunks preserve order');
$stream->forceEndTurn();
check($socket->textSent[0] === '{"type":"ForceEndTurn"}', 'Flux control message');
check($stream->receive()->payload->requestId === 'flux-id', 'Typed Connected event');
check($stream->receive()->payload->audioWindowEnd === 1.3, 'Typed TurnInfo numeric string');
check($stream->receive()->type === 'FutureEvent', 'Unknown event preserved');
check($stream->receive()->type === 'Malformed', 'Malformed event surfaced');
$stream->close();
check($socket->closed, 'Client close');
try { $stream->sendAudio('late'); throw new RuntimeException('Send after close was accepted'); }
catch (DeepgramSdkLab\ConnectionException) {}

$socket = new FakeSocket();
$socket->frames = [new Frame('{"type":"Results","channel_index":[0,1],"duration":1,"start":0,"channel":{"alternatives":[]},"metadata":{"request_id":"v1-id","model_info":{"name":"nova-3","version":"1","arch":"test"},"model_uuid":"model-id"}}', false)];
$stream = (new Client('test-key', $transport))->listen->connectV1(socket: $socket);
check($stream->receive()->payload->metadata->requestId === 'v1-id', 'Typed v1 Results');
$stream->finalize();
check($socket->textSent[0] === '{"type":"Finalize"}', 'V1 control message');
$stream->close();

echo "PHP offline contracts passed\n";

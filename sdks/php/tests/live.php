<?php
declare(strict_types=1);

require __DIR__ . '/bootstrap.php';

if (($argv[1] ?? '') !== '--live' || !getenv('DEEPGRAM_API_KEY')) {
    fwrite(STDERR, "Live tests require: DEEPGRAM_API_KEY=... php tests/live.php --live\n");
    exit(2);
}

$client = new DeepgramSdkLab\Client(getenv('DEEPGRAM_API_KEY'));
$result = $client->listen->transcribeUrl('https://dpgr.am/spacewalk.wav');
if ($result->metadata->requestId === '' || count($result->results->channels) === 0) {
    throw new RuntimeException('Live transcription result was incomplete');
}
$audio = $client->speak->generate('Hello from Deepgram SDK Lab.');
if ($audio->bytes === '' || $audio->requestId === null) {
    throw new RuntimeException('Live speech response was incomplete');
}
$flux = $client->listen->connectV2(options: ['encoding' => 'linear16', 'sample_rate' => 16000]);
$flux->close();
echo "PHP live smoke tests passed\n";

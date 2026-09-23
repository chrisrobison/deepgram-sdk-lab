<?php
declare(strict_types=1);

require dirname(__DIR__) . '/vendor/autoload.php';

if (count($argv) !== 2 || !getenv('DEEPGRAM_API_KEY')) {
    fwrite(STDERR, "Usage: DEEPGRAM_API_KEY=... php examples/transcribe.php <wav-file>\n");
    exit(2);
}

try {
    $client = new DeepgramSdkLab\Client(getenv('DEEPGRAM_API_KEY'));
    $result = $client->listen->transcribeFile($argv[1], 'audio/wav');
    echo 'Request: ' . $result->metadata->requestId . PHP_EOL;
    foreach ($result->results->channels as $channel) {
        echo ($channel->alternatives[0]->transcript ?? '') . PHP_EOL;
    }
} catch (Throwable $error) {
    fwrite(STDERR, $error->getMessage() . PHP_EOL);
    exit(1);
}

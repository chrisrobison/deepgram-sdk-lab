# PHP package

The PHP SDK targets PHP 8.2+ with ext-curl and ext-json. It requires no framework. `composer install` enables PSR-4 autoloading. REST and an optional blocking Listen v1/v2 WebSocket client are covered by offline contracts; live smoke tests are opt-in. Install `phrity/websocket:^3.8` to use realtime in a production install. The library is a development dependency here so its adapter is tested in CI.

```php
require 'vendor/autoload.php';
$client = new DeepgramSdkLab\Client(getenv('DEEPGRAM_API_KEY'));
$result = $client->listen->transcribeUrl('https://dpgr.am/spacewalk.wav');
echo $result->results->channels[0]->alternatives[0]->transcript;
```

`Client` accepts an optional `Transport` implementation for testing or host application integration. The default `CurlTransport` supports REST without a PSR dependency. This is deliberate: no PSR HTTP implementation can be assumed in a standalone Composer package, while the small transport interface remains replaceable. The file helper streams audio from disk through cURL, so it does not load the entire file into memory.

Realtime usage is blocking and fits CLI or long-running worker processes:

```php
$stream = $client->listen->connectV2(options: ['encoding' => 'linear16', 'sample_rate' => 16000]);
$stream->sendAudio($linear16Chunk);
foreach ($stream->events() as $event) {
    if ($event->type === 'TurnInfo') {
        echo $event->payload->transcript . PHP_EOL;
    }
}
```

Close the stream explicitly. Unknown server messages retain their decoded JSON payload; malformed messages surface as `Malformed`. Reconnect after audio submission is not automatic because replay could duplicate or omit speech.

Run `php tests/run.php` offline. Live tests require both credentials and an explicit flag: `DEEPGRAM_API_KEY=... php tests/live.php --live`.

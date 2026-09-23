# PHP package

The PHP SDK targets PHP 8.2+ with ext-curl and ext-json. It requires no framework. `composer install` enables PSR-4 autoloading. REST is working in offline contract tests; live smoke tests are opt-in. Realtime WebSocket support is not implemented yet.

```php
require 'vendor/autoload.php';
$client = new DeepgramSdkLab\Client(getenv('DEEPGRAM_API_KEY'));
$result = $client->listen->transcribeUrl('https://dpgr.am/spacewalk.wav');
echo $result->results->channels[0]->alternatives[0]->transcript;
```

`Client` accepts an optional `Transport` implementation for testing or host application integration. The default `CurlTransport` supports REST without a PSR dependency. This is deliberate: no PSR HTTP implementation can be assumed in a standalone Composer package, while the small transport interface remains replaceable. The file helper streams audio from disk through cURL, so it does not load the entire file into memory.

Run `php tests/run.php` offline. Live tests require both credentials and an explicit flag: `DEEPGRAM_API_KEY=... php tests/live.php --live`.

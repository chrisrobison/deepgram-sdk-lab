<?php
declare(strict_types=1);

require dirname(__DIR__) . '/tests/bootstrap.php';

if (count($argv) !== 3 || !ctype_digit($argv[2]) || (int) $argv[2] < 1) {
    fwrite(STDERR, "usage: php decode.php <fixture.json> <iterations>\n");
    exit(2);
}
$json = file_get_contents($argv[1]);
if ($json === false) { throw new RuntimeException('Fixture unreadable'); }
$array = json_decode($json, true, 512, JSON_THROW_ON_ERROR);
$iterations = (int) $argv[2];
$checksum = 0;
$start = microtime(true);
for ($i = 0; $i < $iterations; $i++) {
    $result = DeepgramSdkLab\Generated\ListenV1Response::fromArray($array);
    $checksum += count($result->results->channels);
}
$seconds = microtime(true) - $start;
printf("php decode_count=%d seconds=%.4f per_second=%d peak_bytes=%d checksum=%d\n",
    $iterations, $seconds, (int) ($iterations / $seconds), memory_get_peak_usage(true), $checksum);

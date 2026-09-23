<?php
declare(strict_types=1);

namespace DeepgramSdkLab\Http;

use DeepgramSdkLab\ConfigurationException;

final readonly class FileBody
{
    public int $size;

    public function __construct(public string $path)
    {
        if (!is_file($path) || !is_readable($path)) { throw new ConfigurationException("Cannot read audio file: $path"); }
        $size = filesize($path);
        if ($size === false || $size <= 0) { throw new ConfigurationException("Audio file is empty or unreadable: $path"); }
        $this->size = $size;
    }
}

<?php
declare(strict_types=1);

namespace DeepgramSdkLab\Internal;

use UnexpectedValueException;

final class Wire
{
    /** @param array<string, mixed> $data */
    public static function required(array $data, string $key): mixed
    {
        if (!array_key_exists($key, $data) || $data[$key] === null) {
            throw new UnexpectedValueException("Missing required field: {$key}");
        }
        return $data[$key];
    }

    /** @return array<string, mixed> */
    public static function object(mixed $value): array
    {
        if (!is_array($value) || (array_is_list($value) && $value !== [])) {
            throw new UnexpectedValueException('Expected JSON object');
        }
        return $value;
    }

    /** @return list<mixed> */
    public static function array(mixed $value): array
    {
        if (!is_array($value) || !array_is_list($value)) {
            throw new UnexpectedValueException('Expected JSON array');
        }
        return $value;
    }

    public static function string(mixed $value): string
    {
        if (!is_string($value)) { throw new UnexpectedValueException('Expected JSON string'); }
        return $value;
    }

    public static function integer(mixed $value): int
    {
        if (!is_int($value)) { throw new UnexpectedValueException('Expected JSON integer'); }
        return $value;
    }

    public static function number(mixed $value): float
    {
        if (!is_float($value) && !is_int($value) && !(is_string($value) && is_numeric($value))) {
            throw new UnexpectedValueException('Expected JSON number or numeric string');
        }
        return (float) $value;
    }

    public static function boolean(mixed $value): bool
    {
        if (!is_bool($value)) { throw new UnexpectedValueException('Expected JSON boolean'); }
        return $value;
    }
}

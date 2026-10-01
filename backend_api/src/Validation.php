<?php

declare(strict_types=1);

final class Validation
{
    // Mismo formato que otp_auth y el gateway OTP: +591 + 8 dígitos.
    public static function phone(mixed $phone): ?string
    {
        if (!is_string($phone)) {
            return null;
        }
        return preg_match('/^\+591\d{8}$/', $phone) ? $phone : null;
    }

    // Mismo formato que emite el gateway OTP: 32 bytes en base64url.
    public static function sessionToken(mixed $token): ?string
    {
        if (!is_string($token)) {
            return null;
        }
        return preg_match('/^[A-Za-z0-9_-]{43}$/', $token) ? $token : null;
    }

    /**
     * Texto libre opcional: null o "" se guardan como null.
     * Devuelve false si el valor no es válido.
     */
    public static function optionalText(mixed $value, int $maxLength): string|null|false
    {
        if ($value === null) {
            return null;
        }
        if (!is_string($value)) {
            return false;
        }
        $value = trim(preg_replace('/\s+/u', ' ', $value) ?? '');
        if ($value === '') {
            return null;
        }
        return mb_strlen($value) <= $maxLength ? $value : false;
    }
}

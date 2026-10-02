<?php

declare(strict_types=1);

final class Media
{
    /**
     * URL pública de un archivo de media (ruta relativa guardada en la BD).
     * En flamenco media_base_url apunta al directorio de media del entorno; en
     * dev se deriva del request para que funcione igual desde el emulador
     * Android (10.0.2.2) que desde el simulador iOS (localhost).
     */
    public static function url(?string $path, array $config): ?string
    {
        if ($path === null) {
            return null;
        }
        return self::baseUrl($config) . '/' . ltrim($path, '/');
    }

    private static function baseUrl(array $config): string
    {
        if (!empty($config['media_base_url'])) {
            return rtrim($config['media_base_url'], '/');
        }
        $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
        $basePath = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? '/'), '/');
        return "$scheme://{$_SERVER['HTTP_HOST']}$basePath/media";
    }
}

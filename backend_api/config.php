<?php

declare(strict_types=1);

// Sin variables de entorno: en flamenco corremos en el pool PHP-FPM compartido
// de gyros, cuyo entorno no controlamos sin sudo. Cada entorno sobreescribe
// estos valores con un config.local.php no versionado.
$defaults = [
    'env' => 'dev',
    'db' => [
        'dsn' => 'pgsql:host=db;port=5432;dbname=hobbystore_dev',
        'user' => 'hobby',
        'password' => 'hobby',
        'schema' => 'hobbystore',
    ],
    'otp_session_url' => 'mock',
    'auth_cache_seconds' => 600,
    'min_app_version' => '0.0.0',
];

$localOverridesFile = __DIR__ . '/config.local.php';
if (file_exists($localOverridesFile)) {
    $overrides = require $localOverridesFile;
    return array_replace_recursive($defaults, is_array($overrides) ? $overrides : []);
}

return $defaults;

<?php

declare(strict_types=1);

/** @var Router $router */
/** @var array $config */

$router->get('/v1/health', static function () use ($config): never {
    try {
        $pdo = Db::connect($config['db']);
        $lastMigration = $pdo->query('SELECT max(version) FROM schema_migrations')->fetchColumn();
        Response::json([
            'status' => 'ok',
            'env' => $config['env'],
            'api_version' => API_VERSION,
            'db' => 'ok',
            'schema' => $pdo->query('SELECT current_schema()')->fetchColumn(),
            'last_migration' => $lastMigration,
        ]);
    } catch (Throwable $e) {
        error_log('[hobbystore] health: ' . $e->getMessage());
        Response::json(['status' => 'degraded', 'env' => $config['env'], 'db' => 'error'], 503);
    }
});

$router->get('/v1/config', static function () use ($config): never {
    Response::json(['min_app_version' => $config['min_app_version']]);
});

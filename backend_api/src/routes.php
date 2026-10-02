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

$router->get('/v1/me', static function () use ($config): never {
    $pdo = Db::connect($config['db']);
    MeController::show($pdo, Auth::requirePhone($pdo, $config));
});

$router->patch('/v1/me', static function () use ($config): never {
    $pdo = Db::connect($config['db']);
    MeController::update($pdo, Auth::requirePhone($pdo, $config));
});

$router->get('/v1/home', static function () use ($config): never {
    CatalogController::home(Db::connect($config['db']), $config);
});

$router->get('/v1/categories', static function () use ($config): never {
    CatalogController::categories(Db::connect($config['db']));
});

$router->get('/v1/products', static function () use ($config): never {
    CatalogController::products(Db::connect($config['db']), $config);
});

$router->get('/v1/products/{id}', static function (string $id) use ($config): never {
    CatalogController::product(Db::connect($config['db']), $config, $id);
});

$router->get('/v1/stores/{slug}', static function (string $slug) use ($config): never {
    CatalogController::store(Db::connect($config['db']), $config, $slug);
});

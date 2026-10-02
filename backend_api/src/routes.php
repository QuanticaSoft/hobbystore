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

// Favoritos y carrito: requieren sesión.
$withUser = static function (callable $handler) use ($config): callable {
    return static function (string ...$params) use ($handler, $config): never {
        $pdo = Db::connect($config['db']);
        $handler($pdo, Users::idForPhone($pdo, Auth::requirePhone($pdo, $config)), ...$params);
    };
};

$router->get('/v1/favorites', $withUser(static fn(PDO $pdo, int $userId) =>
    FavoritesController::index($pdo, $config, $userId)));

$router->put('/v1/favorites/{id}', $withUser(static fn(PDO $pdo, int $userId, string $id) =>
    FavoritesController::add($pdo, $userId, $id)));

$router->delete('/v1/favorites/{id}', $withUser(static fn(PDO $pdo, int $userId, string $id) =>
    FavoritesController::remove($pdo, $userId, $id)));

$router->get('/v1/cart', $withUser(static fn(PDO $pdo, int $userId) =>
    CartController::show($pdo, $config, $userId)));

$router->put('/v1/cart/{id}', $withUser(static fn(PDO $pdo, int $userId, string $id) =>
    CartController::setQuantity($pdo, $config, $userId, $id)));

$router->delete('/v1/cart/{id}', $withUser(static fn(PDO $pdo, int $userId, string $id) =>
    CartController::remove($pdo, $config, $userId, $id)));

$router->post('/v1/orders', $withUser(static fn(PDO $pdo, int $userId) =>
    OrdersController::create($pdo, $config, $userId)));

$router->get('/v1/orders', $withUser(static fn(PDO $pdo, int $userId) =>
    OrdersController::index($pdo, $userId)));

$router->patch('/v1/orders/{id}', $withUser(static fn(PDO $pdo, int $userId, string $id) =>
    OrdersController::updateStatus($pdo, $userId, $id)));

<?php

declare(strict_types=1);

require_once __DIR__ . '/Response.php';
require_once __DIR__ . '/Db.php';
require_once __DIR__ . '/Router.php';
require_once __DIR__ . '/Validation.php';
require_once __DIR__ . '/Auth.php';
require_once __DIR__ . '/Media.php';
require_once __DIR__ . '/Users.php';
require_once __DIR__ . '/Money.php';
require_once __DIR__ . '/ImageUpload.php';
require_once __DIR__ . '/Controllers/CatalogController.php';
require_once __DIR__ . '/Controllers/FavoritesController.php';
require_once __DIR__ . '/Controllers/CartController.php';
require_once __DIR__ . '/Controllers/OrdersController.php';
require_once __DIR__ . '/Controllers/MyProductsController.php';
require_once __DIR__ . '/Controllers/MeController.php';

const API_VERSION = '0.5.0';

$config = require dirname(__DIR__) . '/config.php';

set_exception_handler(static function (Throwable $e): void {
    error_log('[hobbystore] ' . $e->getMessage());
    Response::error('Error interno.', 500);
});

$router = new Router();
require __DIR__ . '/routes.php';
$router->dispatch($_SERVER['REQUEST_METHOD'] ?? 'GET', Router::requestPath());

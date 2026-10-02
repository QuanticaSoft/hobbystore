<?php

declare(strict_types=1);

/**
 * Catálogo público (sin sesión): Home, categorías, productos y tiendas.
 * Solo se muestran productos activos de particulares o de tiendas aprobadas.
 */
final class CatalogController
{
    private const PAGE_SIZE = 20;
    private const HOME_LATEST_COUNT = 10;
    private const MAX_QUERY_LENGTH = 80;

    public const VISIBLE_PRODUCTS = "p.status = 'active' AND (p.store_id IS NULL OR s.status = 'approved')";

    // Datos de una tarjeta de producto: primera imagen y nombre del vendedor.
    public const PRODUCT_SUMMARY_SELECT = "
        SELECT p.id, p.title, p.price_bob, p.condition, p.city, p.created_at, p.stock, p.seller_user_id,
               s.slug AS store_slug, s.name AS store_name, u.display_name AS seller_name,
               (SELECT pi.thumb_path FROM product_images pi
                 WHERE pi.product_id = p.id ORDER BY pi.sort LIMIT 1) AS thumb_path
        FROM products p
        JOIN users u ON u.id = p.seller_user_id
        LEFT JOIN stores s ON s.id = p.store_id";

    public static function home(PDO $pdo, array $config): never
    {
        $banners = $pdo->query(
            "SELECT id, title, image_path, link_url FROM banners
             WHERE active AND (starts_at IS NULL OR starts_at <= now()) AND (ends_at IS NULL OR ends_at > now())
             ORDER BY sort, id"
        )->fetchAll();

        $stores = $pdo->query(
            "SELECT slug, name, logo_path, city FROM stores
             WHERE status = 'approved' AND is_featured ORDER BY name"
        )->fetchAll();

        $latest = $pdo->query(
            self::PRODUCT_SUMMARY_SELECT . ' WHERE ' . self::VISIBLE_PRODUCTS .
            ' ORDER BY p.created_at DESC, p.id DESC LIMIT ' . self::HOME_LATEST_COUNT
        )->fetchAll();

        Response::json([
            'banners' => array_map(static fn(array $b) => [
                'id' => (int) $b['id'],
                'title' => $b['title'],
                'image_url' => Media::url($b['image_path'], $config),
                'link_url' => $b['link_url'],
            ], $banners),
            'featured_stores' => array_map(static fn(array $s) => self::presentStoreSummary($s, $config), $stores),
            'latest_products' => array_map(static fn(array $p) => self::presentProductSummary($p, $config), $latest),
        ]);
    }

    public static function categories(PDO $pdo): never
    {
        $rows = $pdo->query(
            "SELECT c.id, c.slug, c.name,
                    (SELECT count(*) FROM products p LEFT JOIN stores s ON s.id = p.store_id
                      WHERE p.category_id = c.id AND " . self::VISIBLE_PRODUCTS . ") AS product_count
             FROM categories c ORDER BY c.sort"
        )->fetchAll();

        Response::json(['categories' => array_map(static fn(array $c) => [
            'id' => (int) $c['id'],
            'slug' => $c['slug'],
            'name' => $c['name'],
            'product_count' => (int) $c['product_count'],
        ], $rows)]);
    }

    /** Filtros opcionales: category (slug), store (slug), q (texto), page (desde 1). */
    public static function products(PDO $pdo, array $config): never
    {
        $conditions = [self::VISIBLE_PRODUCTS];
        $params = [];

        if (isset($_GET['category']) && $_GET['category'] !== '') {
            $conditions[] = 'p.category_id = (SELECT id FROM categories WHERE slug = :category)';
            $params['category'] = (string) $_GET['category'];
        }
        if (isset($_GET['store']) && $_GET['store'] !== '') {
            $conditions[] = 's.slug = :store';
            $params['store'] = (string) $_GET['store'];
        }
        $query = trim((string) ($_GET['q'] ?? ''));
        if ($query !== '') {
            if (mb_strlen($query) > self::MAX_QUERY_LENGTH) {
                Response::error('La búsqueda es demasiado larga.');
            }
            // Se escapan los comodines de LIKE para buscar el texto tal cual. Se usa
            // "!" y no la barra invertida porque el parser de PDO la toma como escape
            // de la comilla y deja de reconocer los placeholders que siguen.
            $conditions[] = "(p.title ILIKE :q_title ESCAPE '!' OR p.description ILIKE :q_description ESCAPE '!')";
            $pattern = '%' . str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $query) . '%';
            $params['q_title'] = $params['q_description'] = $pattern;
        }

        $page = filter_var($_GET['page'] ?? 1, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        if ($page === false) {
            Response::error('Página inválida.');
        }

        // Se pide uno de más para saber si hay otra página sin un COUNT aparte.
        $statement = $pdo->prepare(
            self::PRODUCT_SUMMARY_SELECT . ' WHERE ' . implode(' AND ', $conditions) .
            ' ORDER BY p.created_at DESC, p.id DESC LIMIT ' . (self::PAGE_SIZE + 1) .
            ' OFFSET ' . (($page - 1) * self::PAGE_SIZE)
        );
        $statement->execute($params);
        $rows = $statement->fetchAll();

        Response::json([
            'items' => array_map(
                static fn(array $p) => self::presentProductSummary($p, $config),
                array_slice($rows, 0, self::PAGE_SIZE)
            ),
            'page' => $page,
            'has_more' => count($rows) > self::PAGE_SIZE,
        ]);
    }

    public static function product(PDO $pdo, array $config, string $id): never
    {
        if (!ctype_digit($id)) {
            Response::error('Producto no encontrado.', 404);
        }

        $statement = $pdo->prepare(
            "SELECT p.id, p.title, p.description, p.price_bob, p.condition, p.stock, p.city, p.created_at,
                    c.slug AS category_slug, c.name AS category_name,
                    u.display_name AS seller_name, u.city AS seller_city,
                    s.slug AS store_slug, s.name AS store_name, s.logo_path AS store_logo_path,
                    s.city AS store_city, s.delivery_options
             FROM products p
             JOIN categories c ON c.id = p.category_id
             JOIN users u ON u.id = p.seller_user_id
             LEFT JOIN stores s ON s.id = p.store_id
             WHERE p.id = :id AND " . self::VISIBLE_PRODUCTS
        );
        $statement->execute(['id' => $id]);
        $product = $statement->fetch();
        if ($product === false) {
            Response::error('Producto no encontrado.', 404);
        }

        $images = $pdo->prepare('SELECT path, thumb_path FROM product_images WHERE product_id = ? ORDER BY sort');
        $images->execute([$id]);

        $isStore = $product['store_slug'] !== null;
        Response::json(['product' => [
            'id' => (int) $product['id'],
            'title' => $product['title'],
            'description' => $product['description'],
            'price_bob' => (float) $product['price_bob'],
            'condition' => $product['condition'],
            'stock' => (int) $product['stock'],
            'city' => $product['city'],
            'created_at' => $product['created_at'],
            'category' => ['slug' => $product['category_slug'], 'name' => $product['category_name']],
            'images' => array_map(static fn(array $i) => [
                'url' => Media::url($i['path'], $config),
                'thumb_url' => Media::url($i['thumb_path'], $config),
            ], $images->fetchAll()),
            'seller' => [
                'type' => $isStore ? 'store' : 'user',
                'name' => $isStore ? $product['store_name'] : ($product['seller_name'] ?? 'Vendedor'),
                'city' => $isStore ? $product['store_city'] : $product['seller_city'],
                'store_slug' => $product['store_slug'],
                'logo_url' => Media::url($product['store_logo_path'], $config),
                'delivery_options' => $isStore ? json_decode($product['delivery_options'], true) : [],
            ],
        ]]);
    }

    public static function store(PDO $pdo, array $config, string $slug): never
    {
        $statement = $pdo->prepare(
            "SELECT s.slug, s.name, s.logo_path, s.description, s.city, s.delivery_options,
                    (SELECT count(*) FROM products p WHERE p.store_id = s.id AND p.status = 'active') AS product_count
             FROM stores s WHERE s.slug = ? AND s.status = 'approved'"
        );
        $statement->execute([$slug]);
        $store = $statement->fetch();
        if ($store === false) {
            Response::error('Tienda no encontrada.', 404);
        }

        Response::json(['store' => [
            ...self::presentStoreSummary($store, $config),
            'description' => $store['description'],
            'delivery_options' => json_decode($store['delivery_options'], true),
            'product_count' => (int) $store['product_count'],
        ]]);
    }

    /** Devuelve el producto (id, vendedor, stock) o responde 404. */
    public static function requireVisibleProduct(PDO $pdo, string $productId): array
    {
        if (!ctype_digit($productId)) {
            Response::error('Producto no encontrado.', 404);
        }
        $statement = $pdo->prepare(
            'SELECT p.id, p.seller_user_id, p.stock FROM products p
             LEFT JOIN stores s ON s.id = p.store_id
             WHERE p.id = ? AND ' . CatalogController::VISIBLE_PRODUCTS
        );
        $statement->execute([$productId]);
        $product = $statement->fetch();
        if ($product === false) {
            Response::error('Producto no encontrado.', 404);
        }
        return $product;
    }

    private static function presentStoreSummary(array $store, array $config): array
    {
        return [
            'slug' => $store['slug'],
            'name' => $store['name'],
            'city' => $store['city'],
            'logo_url' => Media::url($store['logo_path'], $config),
        ];
    }

    public static function presentProductSummary(array $product, array $config): array
    {
        return [
            'id' => (int) $product['id'],
            'title' => $product['title'],
            'price_bob' => (float) $product['price_bob'],
            'condition' => $product['condition'],
            'city' => $product['city'],
            'thumb_url' => Media::url($product['thumb_path'], $config),
            'seller_name' => $product['store_name'] ?? $product['seller_name'] ?? 'Vendedor',
            'store_slug' => $product['store_slug'],
        ];
    }
}

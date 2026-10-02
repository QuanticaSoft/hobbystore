<?php

declare(strict_types=1);

/**
 * Publicaciones del propio usuario (vender). Un producto nace pausado, recibe
 * sus fotos de a una y recién entonces se activa: así nunca aparece en el
 * catálogo sin fotos ni a medio subir.
 */
final class MyProductsController
{
    /** Publicaciones activas permitidas a un particular (las tiendas no tienen tope). */
    public const PARTICULAR_ACTIVE_LIMIT = 5;
    private const MAX_IMAGES = 5;

    private const STATUSES = ['active', 'paused', 'sold'];

    public static function index(PDO $pdo, array $config, int $userId): never
    {
        $statement = $pdo->prepare(
            "SELECT id FROM products WHERE seller_user_id = ? AND status <> 'removed'
             ORDER BY created_at DESC, id DESC"
        );
        $statement->execute([$userId]);
        $ids = array_map('intval', $statement->fetchAll(PDO::FETCH_COLUMN));

        $hasStore = self::ownStoreId($pdo, $userId) !== null;
        Response::json([
            'products' => array_map(static fn(int $id) => self::load($pdo, $config, $id), $ids),
            'active_count' => self::activeParticularCount($pdo, $userId),
            // Las tiendas no tienen tope.
            'active_limit' => $hasStore ? null : self::PARTICULAR_ACTIVE_LIMIT,
        ]);
    }

    public static function create(PDO $pdo, array $config, int $userId): never
    {
        $user = $pdo->prepare('SELECT display_name, city FROM users WHERE id = ?');
        $user->execute([$userId]);
        $profile = $user->fetch();
        if (empty($profile['display_name']) || empty($profile['city'])) {
            Response::error('Completa tu nombre y ciudad en Perfil antes de publicar.');
        }

        $fields = self::validatedFields(self::jsonBody(), $pdo, requireAll: true);
        $statement = $pdo->prepare(
            "INSERT INTO products (seller_user_id, store_id, category_id, title, description, price_bob, condition, stock, city, status)
             VALUES (:seller, :store_id, :category_id, :title, :description, :price_bob, :condition, :stock, :city, 'paused')
             RETURNING id"
        );
        $statement->execute([
            ...$fields,
            'seller' => $userId,
            'store_id' => self::ownStoreId($pdo, $userId),
            'city' => $profile['city'],
        ]);

        Response::json(['product' => self::load($pdo, $config, (int) $statement->fetchColumn())], 201);
    }

    public static function update(PDO $pdo, array $config, int $userId, string $productId): never
    {
        $product = self::requireOwn($pdo, $userId, $productId);
        $body = self::jsonBody();

        $fields = self::validatedFields($body, $pdo, requireAll: false);
        if (array_key_exists('status', $body)) {
            if (!in_array($body['status'], self::STATUSES, true)) {
                Response::error('Estado inválido.');
            }
            $fields['status'] = $body['status'];
        }
        if ($fields === []) {
            Response::error('Nada que actualizar.');
        }

        $willBeActive = ($fields['status'] ?? $product['status']) === 'active';
        if ($willBeActive) {
            self::assertCanBeActive($pdo, $userId, $product, $fields['stock'] ?? (int) $product['stock']);
        }

        // Las columnas salen de validatedFields (lista fija), nunca del request.
        $assignments = implode(', ', array_map(static fn(string $column) => "$column = :$column", array_keys($fields)));
        $pdo->prepare("UPDATE products SET $assignments, updated_at = now() WHERE id = :id")
            ->execute([...$fields, 'id' => $product['id']]);

        Response::json(['product' => self::load($pdo, $config, (int) $product['id'])]);
    }

    /** Baja lógica: los pedidos pasados siguen apuntando al producto. */
    public static function destroy(PDO $pdo, int $userId, string $productId): never
    {
        $product = self::requireOwn($pdo, $userId, $productId);
        $pdo->prepare("UPDATE products SET status = 'removed', updated_at = now() WHERE id = ?")
            ->execute([$product['id']]);
        Response::json(['product_id' => (int) $product['id'], 'status' => 'removed']);
    }

    public static function addImage(PDO $pdo, array $config, int $userId, string $productId): never
    {
        $product = self::requireOwn($pdo, $userId, $productId);
        $count = $pdo->prepare('SELECT count(*) FROM product_images WHERE product_id = ?');
        $count->execute([$product['id']]);
        if ((int) $count->fetchColumn() >= self::MAX_IMAGES) {
            Response::error('Máximo ' . self::MAX_IMAGES . ' fotos por producto.', 409);
        }

        $paths = ImageUpload::storeProductPhoto($_FILES['photo'] ?? null, $config['media_dir']);
        $pdo->prepare(
            'INSERT INTO product_images (product_id, path, thumb_path, sort)
             SELECT ?, ?, ?, COALESCE(max(sort) + 1, 0) FROM product_images WHERE product_id = ?'
        )->execute([$product['id'], $paths['path'], $paths['thumb_path'], $product['id']]);

        Response::json(['product' => self::load($pdo, $config, (int) $product['id'])], 201);
    }

    public static function deleteImage(PDO $pdo, array $config, int $userId, string $productId, string $imageId): never
    {
        $product = self::requireOwn($pdo, $userId, $productId);
        $images = $pdo->prepare('SELECT id, path, thumb_path FROM product_images WHERE product_id = ?');
        $images->execute([$product['id']]);
        $all = $images->fetchAll();

        $image = array_values(array_filter($all, static fn(array $i) => (string) $i['id'] === $imageId))[0] ?? null;
        if ($image === null) {
            Response::error('Foto no encontrada.', 404);
        }
        if ($product['status'] === 'active' && count($all) === 1) {
            Response::error('Un producto publicado necesita al menos una foto. Agrega otra antes de quitar esta.', 409);
        }

        $pdo->prepare('DELETE FROM product_images WHERE id = ?')->execute([$image['id']]);
        ImageUpload::delete($config['media_dir'], $image['path'], $image['thumb_path']);

        Response::json(['product' => self::load($pdo, $config, (int) $product['id'])]);
    }

    private static function assertCanBeActive(PDO $pdo, int $userId, array $product, int $stock): void
    {
        $images = $pdo->prepare('SELECT count(*) FROM product_images WHERE product_id = ?');
        $images->execute([$product['id']]);
        if ((int) $images->fetchColumn() === 0) {
            Response::error('Agrega al menos una foto para publicar.', 409);
        }
        if ($stock < 1) {
            Response::error('Indica cuántas unidades tienes para publicar.', 409);
        }
        if ($product['store_id'] === null && $product['status'] !== 'active'
            && self::activeParticularCount($pdo, $userId) >= self::PARTICULAR_ACTIVE_LIMIT) {
            Response::error(
                'Ya tienes ' . self::PARTICULAR_ACTIVE_LIMIT . ' publicaciones activas. Pausa o marca como vendida alguna para publicar otra.',
                409
            );
        }
    }

    /**
     * Tienda del usuario ya revisada por el admin. Con la tienda suspendida
     * también se publica como tienda: así la suspensión no se esquiva
     * publicando como particular.
     */
    private static function ownStoreId(PDO $pdo, int $userId): ?int
    {
        $statement = $pdo->prepare(
            "SELECT id FROM stores WHERE owner_user_id = ? AND status IN ('approved', 'suspended')"
        );
        $statement->execute([$userId]);
        $id = $statement->fetchColumn();
        return $id === false ? null : (int) $id;
    }

    private static function activeParticularCount(PDO $pdo, int $userId): int
    {
        $statement = $pdo->prepare(
            "SELECT count(*) FROM products WHERE seller_user_id = ? AND store_id IS NULL AND status = 'active'"
        );
        $statement->execute([$userId]);
        return (int) $statement->fetchColumn();
    }

    /** Campos editables validados; con $requireAll exige todos (alta). */
    private static function validatedFields(array $body, PDO $pdo, bool $requireAll): array
    {
        $fields = [];
        $has = static fn(string $key) => $requireAll || array_key_exists($key, $body);

        if ($has('title')) {
            $title = Validation::optionalText($body['title'] ?? null, 120);
            if (!is_string($title) || mb_strlen($title) < 3) {
                Response::error('El título debe tener entre 3 y 120 caracteres.');
            }
            $fields['title'] = $title;
        }
        if ($has('description')) {
            $description = Validation::optionalText($body['description'] ?? null, 2000);
            if ($description === false) {
                Response::error('La descripción debe tener hasta 2000 caracteres.');
            }
            $fields['description'] = $description ?? '';
        }
        if ($has('category')) {
            $category = $pdo->prepare('SELECT id FROM categories WHERE slug = ?');
            $category->execute([(string) ($body['category'] ?? '')]);
            $categoryId = $category->fetchColumn();
            if ($categoryId === false) {
                Response::error('Elige una categoría.');
            }
            $fields['category_id'] = (int) $categoryId;
        }
        if ($has('price_bob')) {
            $price = filter_var($body['price_bob'] ?? null, FILTER_VALIDATE_FLOAT);
            if ($price === false || $price <= 0 || $price > 1_000_000) {
                Response::error('El precio debe ser mayor a 0 y hasta Bs 1.000.000.');
            }
            $fields['price_bob'] = round($price, 2);
        }
        if ($has('condition')) {
            if (!in_array($body['condition'] ?? null, ['new', 'used'], true)) {
                Response::error('Indica si el producto es nuevo o usado.');
            }
            $fields['condition'] = $body['condition'];
        }
        if ($has('stock')) {
            $stock = filter_var($body['stock'] ?? null, FILTER_VALIDATE_INT, [
                'options' => ['min_range' => 0, 'max_range' => 999],
            ]);
            if ($stock === false) {
                Response::error('El stock debe estar entre 0 y 999.');
            }
            $fields['stock'] = $stock;
        }
        return $fields;
    }

    private static function requireOwn(PDO $pdo, int $userId, string $productId): array
    {
        if (!ctype_digit($productId)) {
            Response::error('Publicación no encontrada.', 404);
        }
        $statement = $pdo->prepare(
            "SELECT id, status, stock, store_id FROM products
             WHERE id = ? AND seller_user_id = ? AND status <> 'removed'"
        );
        $statement->execute([$productId, $userId]);
        $product = $statement->fetch();
        if ($product === false) {
            Response::error('Publicación no encontrada.', 404);
        }
        return $product;
    }

    private static function jsonBody(): array
    {
        $body = json_decode(file_get_contents('php://input') ?: '', true);
        if (!is_array($body)) {
            Response::error('Cuerpo JSON inválido.');
        }
        return $body;
    }

    private static function load(PDO $pdo, array $config, int $productId): array
    {
        $statement = $pdo->prepare(
            'SELECT p.id, p.title, p.description, p.price_bob, p.condition, p.stock, p.status, p.city,
                    p.created_at, p.updated_at, c.slug AS category_slug, c.name AS category_name
             FROM products p JOIN categories c ON c.id = p.category_id WHERE p.id = ?'
        );
        $statement->execute([$productId]);
        $product = $statement->fetch();

        $images = $pdo->prepare('SELECT id, path, thumb_path FROM product_images WHERE product_id = ? ORDER BY sort');
        $images->execute([$productId]);

        return [
            'id' => (int) $product['id'],
            'title' => $product['title'],
            'description' => $product['description'],
            'price_bob' => (float) $product['price_bob'],
            'condition' => $product['condition'],
            'stock' => (int) $product['stock'],
            'status' => $product['status'],
            'city' => $product['city'],
            'category' => ['slug' => $product['category_slug'], 'name' => $product['category_name']],
            'images' => array_map(static fn(array $i) => [
                'id' => (int) $i['id'],
                'url' => Media::url($i['path'], $config),
                'thumb_url' => Media::url($i['thumb_path'], $config),
            ], $images->fetchAll()),
        ];
    }
}

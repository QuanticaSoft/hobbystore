<?php

declare(strict_types=1);

/**
 * Moderación: solo usuarios con users.is_admin (se asigna directamente en la
 * BD; la app no tiene forma de volverse admin).
 */
final class AdminController
{
    private const STORE_STATUSES = ['pending', 'approved', 'suspended'];
    private const MAX_NOTE_LENGTH = 300;
    private const MAX_BANNER_TITLE_LENGTH = 120;

    public static function requireAdmin(PDO $pdo, int $userId): void
    {
        $statement = $pdo->prepare('SELECT is_admin FROM users WHERE id = ?');
        $statement->execute([$userId]);
        if ($statement->fetchColumn() !== true) {
            Response::error('Solo para administradores.', 403);
        }
    }

    public static function stores(PDO $pdo, array $config): never
    {
        $status = $_GET['status'] ?? 'pending';
        if (!in_array($status, self::STORE_STATUSES, true)) {
            Response::error('Estado inválido.');
        }
        $statement = $pdo->prepare(
            "SELECT s.*, u.display_name AS owner_name, u.phone AS owner_phone,
                    (SELECT count(*) FROM products p WHERE p.store_id = s.id AND p.status = 'active') AS product_count
             FROM stores s JOIN users u ON u.id = s.owner_user_id
             WHERE s.status = ? ORDER BY s.created_at"
        );
        $statement->execute([$status]);

        Response::json(['stores' => array_map(static fn(array $store) => [
            ...MyStoreController::present($store, $config),
            'owner_name' => $store['owner_name'],
            'owner_phone' => $store['owner_phone'],
            'product_count' => (int) $store['product_count'],
            'created_at' => (new DateTimeImmutable($store['created_at']))->format(DATE_ATOM),
        ], $statement->fetchAll())]);
    }

    /**
     * Aprobar pasa a la tienda todas las publicaciones de su dueño (dejan de
     * contar para el tope de particular). Suspender las oculta del catálogo
     * sin borrarlas: si se reactiva, vuelven a verse.
     */
    public static function updateStore(PDO $pdo, array $config, string $slug): never
    {
        $statement = $pdo->prepare('SELECT * FROM stores WHERE slug = ?');
        $statement->execute([$slug]);
        $store = $statement->fetch();
        if ($store === false) {
            Response::error('Tienda no encontrada.', 404);
        }

        $body = json_decode(file_get_contents('php://input') ?: '', true);
        if (!is_array($body)) {
            Response::error('Cuerpo JSON inválido.');
        }

        $changes = [];
        if (array_key_exists('status', $body)) {
            if (!in_array($body['status'], ['approved', 'suspended'], true)) {
                Response::error('Estado inválido.');
            }
            $changes['status'] = $body['status'];
        }
        if (array_key_exists('is_featured', $body)) {
            if (!is_bool($body['is_featured'])) {
                Response::error('is_featured debe ser true o false.');
            }
            $changes['is_featured'] = $body['is_featured'] ? 'true' : 'false';
        }
        if (array_key_exists('review_note', $body)) {
            $note = Validation::optionalText($body['review_note'], self::MAX_NOTE_LENGTH);
            if ($note === false) {
                Response::error('La nota debe tener hasta ' . self::MAX_NOTE_LENGTH . ' caracteres.');
            }
            $changes['review_note'] = $note;
        }
        if ($changes === []) {
            Response::error('Nada que actualizar.');
        }

        $pdo->beginTransaction();
        $assignments = implode(', ', array_map(static fn(string $column) => "$column = :$column", array_keys($changes)));
        $pdo->prepare("UPDATE stores SET $assignments, updated_at = now() WHERE id = :id")
            ->execute([...$changes, 'id' => $store['id']]);
        if (($changes['status'] ?? null) === 'approved') {
            $pdo->prepare(
                "UPDATE products SET store_id = ?, updated_at = now()
                 WHERE seller_user_id = ? AND store_id IS NULL AND status <> 'removed'"
            )->execute([$store['id'], $store['owner_user_id']]);
        }
        $pdo->commit();

        $statement->execute([$slug]);
        Response::json(['store' => MyStoreController::present($statement->fetch(), $config)]);
    }

    public static function banners(PDO $pdo, array $config): never
    {
        $rows = $pdo->query('SELECT * FROM banners ORDER BY sort, id')->fetchAll();
        Response::json(['banners' => array_map(static fn(array $b) => self::presentBanner($b, $config), $rows)]);
    }

    /** Multipart: campo "photo" + "title" (y opcional "sort"). */
    public static function createBanner(PDO $pdo, array $config): never
    {
        $title = Validation::optionalText($_POST['title'] ?? null, self::MAX_BANNER_TITLE_LENGTH);
        if (!is_string($title)) {
            Response::error('Escribe un título para el banner (hasta ' . self::MAX_BANNER_TITLE_LENGTH . ' caracteres).');
        }
        $path = ImageUpload::storeBanner($_FILES['photo'] ?? null, $config['media_dir']);

        $statement = $pdo->prepare(
            'INSERT INTO banners (title, image_path, sort)
             VALUES (?, ?, (SELECT COALESCE(max(sort), 0) + 10 FROM banners)) RETURNING *'
        );
        $statement->execute([$title, $path]);
        Response::json(['banner' => self::presentBanner($statement->fetch(), $config)], 201);
    }

    public static function updateBanner(PDO $pdo, array $config, string $id): never
    {
        $banner = self::requireBanner($pdo, $id);
        $body = json_decode(file_get_contents('php://input') ?: '', true);
        if (!is_array($body)) {
            Response::error('Cuerpo JSON inválido.');
        }

        $changes = [];
        if (array_key_exists('title', $body)) {
            $title = Validation::optionalText($body['title'], self::MAX_BANNER_TITLE_LENGTH);
            if (!is_string($title)) {
                Response::error('Título inválido.');
            }
            $changes['title'] = $title;
        }
        if (array_key_exists('active', $body)) {
            if (!is_bool($body['active'])) {
                Response::error('active debe ser true o false.');
            }
            $changes['active'] = $body['active'] ? 'true' : 'false';
        }
        if (array_key_exists('sort', $body)) {
            $sort = filter_var($body['sort'], FILTER_VALIDATE_INT);
            if ($sort === false) {
                Response::error('Orden inválido.');
            }
            $changes['sort'] = $sort;
        }
        if ($changes === []) {
            Response::error('Nada que actualizar.');
        }

        $assignments = implode(', ', array_map(static fn(string $column) => "$column = :$column", array_keys($changes)));
        $statement = $pdo->prepare("UPDATE banners SET $assignments WHERE id = :id RETURNING *");
        $statement->execute([...$changes, 'id' => $banner['id']]);
        Response::json(['banner' => self::presentBanner($statement->fetch(), $config)]);
    }

    public static function deleteBanner(PDO $pdo, array $config, string $id): never
    {
        $banner = self::requireBanner($pdo, $id);
        $pdo->prepare('DELETE FROM banners WHERE id = ?')->execute([$banner['id']]);
        ImageUpload::delete($config['media_dir'], $banner['image_path']);
        Response::json(['banner_id' => (int) $banner['id'], 'deleted' => true]);
    }

    /** Retira del catálogo una publicación que infringe las reglas. */
    public static function removeProduct(PDO $pdo, string $productId): never
    {
        if (!ctype_digit($productId)) {
            Response::error('Producto no encontrado.', 404);
        }
        $statement = $pdo->prepare(
            "UPDATE products SET status = 'removed', updated_at = now()
             WHERE id = ? AND status <> 'removed' RETURNING id"
        );
        $statement->execute([$productId]);
        if ($statement->fetchColumn() === false) {
            Response::error('Producto no encontrado.', 404);
        }
        Response::json(['product_id' => (int) $productId, 'status' => 'removed']);
    }

    private static function requireBanner(PDO $pdo, string $id): array
    {
        if (!ctype_digit($id)) {
            Response::error('Banner no encontrado.', 404);
        }
        $statement = $pdo->prepare('SELECT * FROM banners WHERE id = ?');
        $statement->execute([$id]);
        $banner = $statement->fetch();
        if ($banner === false) {
            Response::error('Banner no encontrado.', 404);
        }
        return $banner;
    }

    private static function presentBanner(array $banner, array $config): array
    {
        return [
            'id' => (int) $banner['id'],
            'title' => $banner['title'],
            'image_url' => Media::url($banner['image_path'], $config),
            'active' => (bool) $banner['active'],
            'sort' => (int) $banner['sort'],
        ];
    }
}

<?php

declare(strict_types=1);

final class FavoritesController
{
    /** Favoritos visibles, del más reciente al más antiguo. */
    public static function index(PDO $pdo, array $config, int $userId): never
    {
        $statement = $pdo->prepare(
            CatalogController::PRODUCT_SUMMARY_SELECT . '
             JOIN favorites f ON f.product_id = p.id AND f.user_id = :user_id
             WHERE ' . CatalogController::VISIBLE_PRODUCTS . '
             ORDER BY f.created_at DESC'
        );
        $statement->execute(['user_id' => $userId]);

        Response::json(['items' => array_map(
            static fn(array $p) => CatalogController::presentProductSummary($p, $config),
            $statement->fetchAll()
        )]);
    }

    public static function add(PDO $pdo, int $userId, string $productId): never
    {
        CatalogController::requireVisibleProduct($pdo, $productId);
        $pdo->prepare(
            'INSERT INTO favorites (user_id, product_id) VALUES (?, ?) ON CONFLICT DO NOTHING'
        )->execute([$userId, $productId]);
        Response::json(['product_id' => (int) $productId, 'favorite' => true]);
    }

    // Quitar un favorito que ya no existe no es un error: el resultado es el mismo.
    public static function remove(PDO $pdo, int $userId, string $productId): never
    {
        if (!ctype_digit($productId)) {
            Response::error('Producto no encontrado.', 404);
        }
        $pdo->prepare('DELETE FROM favorites WHERE user_id = ? AND product_id = ?')
            ->execute([$userId, $productId]);
        Response::json(['product_id' => (int) $productId, 'favorite' => false]);
    }
}

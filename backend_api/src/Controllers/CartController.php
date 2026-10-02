<?php

declare(strict_types=1);

/**
 * Carrito agrupado por vendedor: cada grupo será un pedido por WhatsApp
 * (Fase 4). Toda escritura responde con el carrito completo para que la app
 * no tenga que recalcular subtotales.
 */
final class CartController
{
    private const MAX_QTY = 99;

    public static function show(PDO $pdo, array $config, int $userId): never
    {
        Response::json(['cart' => self::build($pdo, $config, $userId)]);
    }

    public static function setQuantity(PDO $pdo, array $config, int $userId, string $productId): never
    {
        $body = json_decode(file_get_contents('php://input') ?: '', true);
        $qty = filter_var($body['qty'] ?? null, FILTER_VALIDATE_INT, [
            'options' => ['min_range' => 1, 'max_range' => self::MAX_QTY],
        ]);
        if ($qty === false) {
            Response::error('La cantidad debe estar entre 1 y ' . self::MAX_QTY . '.');
        }

        $product = CatalogController::requireVisibleProduct($pdo, $productId);
        if ((int) $product['seller_user_id'] === $userId) {
            Response::error('No puedes agregar tu propio producto al carrito.');
        }
        $stock = (int) $product['stock'];
        if ($qty > $stock) {
            Response::error(
                $stock === 0 ? 'Este producto no tiene stock.' : "Solo hay $stock disponible(s).",
                409
            );
        }

        $pdo->prepare(
            'INSERT INTO cart_items (user_id, product_id, qty) VALUES (?, ?, ?)
             ON CONFLICT (user_id, product_id) DO UPDATE SET qty = EXCLUDED.qty, updated_at = now()'
        )->execute([$userId, $productId, $qty]);

        self::show($pdo, $config, $userId);
    }

    public static function remove(PDO $pdo, array $config, int $userId, string $productId): never
    {
        if (!ctype_digit($productId)) {
            Response::error('Producto no encontrado.', 404);
        }
        $pdo->prepare('DELETE FROM cart_items WHERE user_id = ? AND product_id = ?')
            ->execute([$userId, $productId]);
        self::show($pdo, $config, $userId);
    }

    private static function build(PDO $pdo, array $config, int $userId): array
    {
        // Los productos que dejaron de estar visibles (vendidos, pausados) no se
        // muestran ni suman: la línea queda en la BD por si vuelven a activarse.
        $statement = $pdo->prepare(
            'SELECT q.*, ci.qty, ci.created_at AS added_at FROM (' .
            CatalogController::PRODUCT_SUMMARY_SELECT . ' WHERE ' . CatalogController::VISIBLE_PRODUCTS .
            ') q
             JOIN cart_items ci ON ci.product_id = q.id AND ci.user_id = :user_id
             ORDER BY ci.created_at'
        );
        $statement->execute(['user_id' => $userId]);

        $groups = [];
        $totalCents = 0;
        $itemCount = 0;
        foreach ($statement->fetchAll() as $row) {
            $key = self::groupKey($row['store_slug'], (int) $row['seller_user_id']);
            $groups[$key] ??= [
                // Identifica al grupo al crear el pedido (POST /v1/orders).
                'key' => $key,
                'seller' => [
                    'type' => $row['store_slug'] !== null ? 'store' : 'user',
                    'name' => $row['store_name'] ?? $row['seller_name'] ?? 'Vendedor',
                    'store_slug' => $row['store_slug'],
                    'city' => $row['city'],
                ],
                'items' => [],
                'subtotal_cents' => 0,
            ];

            // En centavos para que la suma de precios no acumule error de coma flotante.
            $lineCents = (int) round((float) $row['price_bob'] * 100) * (int) $row['qty'];
            $groups[$key]['items'][] = [
                ...CatalogController::presentProductSummary($row, $config),
                'qty' => (int) $row['qty'],
                'stock' => (int) $row['stock'],
                'line_total_bob' => $lineCents / 100,
            ];
            $groups[$key]['subtotal_cents'] += $lineCents;
            $totalCents += $lineCents;
            $itemCount += (int) $row['qty'];
        }

        return [
            'groups' => array_map(static function (array $group): array {
                $group['subtotal_bob'] = $group['subtotal_cents'] / 100;
                unset($group['subtotal_cents']);
                return $group;
            }, array_values($groups)),
            'item_count' => $itemCount,
            'total_bob' => $totalCents / 100,
        ];
    }

    /** Un pedido por vendedor: la tienda, o el particular si no hay tienda. */
    public static function groupKey(?string $storeSlug, int $sellerUserId): string
    {
        return $storeSlug !== null ? "store:$storeSlug" : "user:$sellerUserId";
    }
}

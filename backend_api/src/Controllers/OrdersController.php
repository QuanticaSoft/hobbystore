<?php

declare(strict_types=1);

/**
 * Pedidos por WhatsApp: el comprador convierte un grupo del carrito (un
 * vendedor) en un pedido, la API devuelve el enlace wa.me con el detalle, y
 * después vendedor y comprador van actualizando el estado.
 */
final class OrdersController
{
    private const MAX_NOTE_LENGTH = 300;

    /** Estados a los que puede pasar cada rol desde el estado actual. */
    private const TRANSITIONS = [
        'seller' => [
            'pending' => ['contacted', 'confirmed', 'cancelled'],
            'contacted' => ['confirmed', 'cancelled'],
            'confirmed' => ['completed', 'cancelled'],
        ],
        'buyer' => [
            'pending' => ['cancelled'],
            'contacted' => ['cancelled'],
        ],
    ];

    public static function create(PDO $pdo, array $config, int $buyerId): never
    {
        $body = json_decode(file_get_contents('php://input') ?: '', true);
        $groupKey = is_array($body) && is_string($body['group_key'] ?? null) ? $body['group_key'] : null;
        if ($groupKey === null) {
            Response::error('Falta el vendedor del pedido.');
        }
        $note = Validation::optionalText($body['note'] ?? null, self::MAX_NOTE_LENGTH);
        if ($note === false) {
            Response::error('La nota debe tener hasta ' . self::MAX_NOTE_LENGTH . ' caracteres.');
        }

        $buyer = $pdo->prepare('SELECT display_name FROM users WHERE id = ?');
        $buyer->execute([$buyerId]);
        $buyerName = $buyer->fetchColumn();
        if (!is_string($buyerName) || $buyerName === '') {
            Response::error('Completa tu nombre en Perfil para que el vendedor sepa quién pide.');
        }

        $lines = array_values(array_filter(
            self::visibleCartLines($pdo, $buyerId),
            static fn(array $line) => CartController::groupKey($line['store_slug'], (int) $line['seller_user_id']) === $groupKey
        ));
        if ($lines === []) {
            Response::error('Esos productos ya no están en tu carrito.', 404);
        }
        foreach ($lines as $line) {
            if ((int) $line['qty'] > (int) $line['stock']) {
                Response::error("\"{$line['title']}\": solo hay {$line['stock']} disponible(s). Ajusta la cantidad.", 409);
            }
        }

        $totalCents = array_sum(array_map(
            static fn(array $line) => (int) round((float) $line['price_bob'] * 100) * (int) $line['qty'],
            $lines
        ));

        $pdo->beginTransaction();
        $order = $pdo->prepare(
            'INSERT INTO orders (buyer_user_id, seller_user_id, store_id, total_bob, note)
             VALUES (?, ?, ?, ?, ?) RETURNING id'
        );
        $order->execute([$buyerId, $lines[0]['seller_user_id'], $lines[0]['store_id'], $totalCents / 100, $note]);
        $orderId = (int) $order->fetchColumn();

        $item = $pdo->prepare(
            'INSERT INTO order_items (order_id, product_id, title_snap, price_snap, qty) VALUES (?, ?, ?, ?, ?)'
        );
        $removeFromCart = $pdo->prepare('DELETE FROM cart_items WHERE user_id = ? AND product_id = ?');
        foreach ($lines as $line) {
            $item->execute([$orderId, $line['product_id'], $line['title'], $line['price_bob'], $line['qty']]);
            $removeFromCart->execute([$buyerId, $line['product_id']]);
        }
        $pdo->commit();

        $sellerName = $lines[0]['store_name'] ?? $lines[0]['seller_name'] ?? 'vendedor';
        $message = "Hola $sellerName, soy $buyerName. Quiero hacer el pedido #$orderId por Hobby Store:\n";
        foreach ($lines as $line) {
            $lineTotal = (float) $line['price_bob'] * (int) $line['qty'];
            $message .= "• {$line['qty']} × {$line['title']}: " . Money::bob($lineTotal) . "\n";
        }
        $message .= 'Total: ' . Money::bob($totalCents / 100);
        if ($note !== null) {
            $message .= "\nNota: $note";
        }
        $message .= "\n¿Está disponible? ¿Cómo coordinamos el pago y la entrega?";

        $orders = self::fetchOrders($pdo, $buyerId, 'o.id = :order_id', ['order_id' => $orderId]);
        Response::json([
            'order' => $orders[0],
            'whatsapp_url' => self::whatsappUrl($lines[0]['store_whatsapp'] ?? $lines[0]['seller_phone'], $message),
        ], 201);
    }

    /** role=buyer: mis compras · role=seller: pedidos recibidos. */
    public static function index(PDO $pdo, int $userId): never
    {
        $role = $_GET['role'] ?? 'buyer';
        if (!in_array($role, ['buyer', 'seller'], true)) {
            Response::error('Rol inválido.');
        }
        $column = $role === 'buyer' ? 'o.buyer_user_id' : 'o.seller_user_id';
        Response::json(['orders' => self::fetchOrders($pdo, $userId, "$column = :user_id", ['user_id' => $userId])]);
    }

    public static function updateStatus(PDO $pdo, int $userId, string $orderId): never
    {
        if (!ctype_digit($orderId)) {
            Response::error('Pedido no encontrado.', 404);
        }
        $orders = self::fetchOrders($pdo, $userId, 'o.id = :order_id', ['order_id' => $orderId]);
        if ($orders === []) {
            Response::error('Pedido no encontrado.', 404);
        }
        $order = $orders[0];

        $body = json_decode(file_get_contents('php://input') ?: '', true);
        $status = is_array($body) ? ($body['status'] ?? null) : null;
        if (!in_array($status, $order['allowed_statuses'], true)) {
            Response::error('No puedes cambiar este pedido a ese estado.', 409);
        }

        $pdo->prepare('UPDATE orders SET status = ?, updated_at = now() WHERE id = ?')->execute([$status, $orderId]);
        $updated = self::fetchOrders($pdo, $userId, 'o.id = :order_id', ['order_id' => $orderId]);
        Response::json(['order' => $updated[0]]);
    }

    /** Líneas del carrito con todo lo necesario para armar el pedido. */
    private static function visibleCartLines(PDO $pdo, int $buyerId): array
    {
        $statement = $pdo->prepare(
            'SELECT ci.qty, p.id AS product_id, p.title, p.price_bob, p.stock, p.seller_user_id, p.store_id,
                    s.slug AS store_slug, s.name AS store_name, s.whatsapp_phone AS store_whatsapp,
                    u.phone AS seller_phone, u.display_name AS seller_name
             FROM cart_items ci
             JOIN products p ON p.id = ci.product_id
             JOIN users u ON u.id = p.seller_user_id
             LEFT JOIN stores s ON s.id = p.store_id
             WHERE ci.user_id = ? AND ' . CatalogController::VISIBLE_PRODUCTS . '
             ORDER BY ci.created_at'
        );
        $statement->execute([$buyerId]);
        return $statement->fetchAll();
    }

    /**
     * Pedidos en los que participa $userId (como comprador o vendedor),
     * filtrados por $condition. Cada uno trae el rol del usuario, la
     * contraparte, sus líneas, los estados permitidos y un enlace de WhatsApp.
     */
    private static function fetchOrders(PDO $pdo, int $userId, string $condition, array $params): array
    {
        $statement = $pdo->prepare(
            "SELECT o.id, o.status, o.total_bob, o.note, o.created_at, o.buyer_user_id,
                    b.display_name AS buyer_name, b.phone AS buyer_phone, b.city AS buyer_city,
                    s.slug AS store_slug, s.name AS store_name, s.whatsapp_phone AS store_whatsapp, s.city AS store_city,
                    v.display_name AS seller_name, v.phone AS seller_phone, v.city AS seller_city
             FROM orders o
             JOIN users b ON b.id = o.buyer_user_id
             JOIN users v ON v.id = o.seller_user_id
             LEFT JOIN stores s ON s.id = o.store_id
             WHERE (o.buyer_user_id = :me OR o.seller_user_id = :me2) AND $condition
             ORDER BY o.created_at DESC, o.id DESC"
        );
        $statement->execute(['me' => $userId, 'me2' => $userId, ...$params]);
        $rows = $statement->fetchAll();
        if ($rows === []) {
            return [];
        }

        $ids = array_map(static fn(array $row) => (int) $row['id'], $rows);
        $items = $pdo->query(
            'SELECT order_id, product_id, title_snap, price_snap, qty FROM order_items
             WHERE order_id IN (' . implode(',', $ids) . ') ORDER BY order_id'
        )->fetchAll(PDO::FETCH_GROUP);

        return array_map(static function (array $row) use ($userId, $items): array {
            $role = (int) $row['buyer_user_id'] === $userId ? 'buyer' : 'seller';
            $sellerName = $row['store_name'] ?? $row['seller_name'] ?? 'Vendedor';
            $buyerName = $row['buyer_name'] ?? 'Comprador';

            $counterpart = $role === 'buyer'
                ? ['name' => $sellerName, 'city' => $row['store_city'] ?? $row['seller_city']]
                : ['name' => $buyerName, 'city' => $row['buyer_city']];
            $whatsappUrl = $role === 'buyer'
                ? self::whatsappUrl(
                    $row['store_whatsapp'] ?? $row['seller_phone'],
                    "Hola $sellerName, te escribo por mi pedido #{$row['id']} en Hobby Store."
                )
                : self::whatsappUrl(
                    $row['buyer_phone'],
                    "Hola $buyerName, te escribo por tu pedido #{$row['id']} en Hobby Store."
                );

            return [
                'id' => (int) $row['id'],
                'status' => $row['status'],
                'role' => $role,
                'total_bob' => (float) $row['total_bob'],
                'note' => $row['note'],
                // ISO 8601: el formato de Postgres ("+00") no lo entiende DateTime.parse de Dart.
                'created_at' => (new DateTimeImmutable($row['created_at']))->format(DATE_ATOM),
                'counterpart' => $counterpart,
                'is_store' => $row['store_slug'] !== null,
                'items' => array_map(static fn(array $item) => [
                    'product_id' => $item['product_id'] === null ? null : (int) $item['product_id'],
                    'title' => $item['title_snap'],
                    'price_bob' => (float) $item['price_snap'],
                    'qty' => (int) $item['qty'],
                ], $items[$row['id']] ?? []),
                'allowed_statuses' => self::TRANSITIONS[$role][$row['status']] ?? [],
                'whatsapp_url' => $whatsappUrl,
            ];
        }, $rows);
    }

    /** wa.me exige el número sin "+" ni espacios. */
    private static function whatsappUrl(string $phone, string $message): string
    {
        return 'https://wa.me/' . ltrim($phone, '+') . '?text=' . rawurlencode($message);
    }
}

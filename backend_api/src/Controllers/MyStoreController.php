<?php

declare(strict_types=1);

/**
 * La tienda del propio usuario: la solicita ("Quiero ser tienda"), queda en
 * revisión hasta que el admin la aprueba, y después la edita.
 */
final class MyStoreController
{
    public const DELIVERY_OPTIONS = ['pickup', 'local', 'national'];

    private const MAX_NAME_LENGTH = 60;
    private const MAX_DESCRIPTION_LENGTH = 500;
    private const MAX_CITY_LENGTH = 60;

    public static function show(PDO $pdo, array $config, int $userId): never
    {
        Response::json(['store' => self::loadByOwner($pdo, $config, $userId)]);
    }

    public static function create(PDO $pdo, array $config, int $userId): never
    {
        if (self::loadByOwner($pdo, $config, $userId) !== null) {
            Response::error('Ya tienes una tienda registrada.', 409);
        }
        $fields = self::validatedFields(self::jsonBody(), requireAll: true);

        $pdo->prepare(
            "INSERT INTO stores (owner_user_id, slug, name, description, city, whatsapp_phone, delivery_options, status)
             VALUES (:owner, :slug, :name, :description, :city, :whatsapp_phone, :delivery_options, 'pending')"
        )->execute([...$fields, 'owner' => $userId, 'slug' => self::uniqueSlug($pdo, $fields['name'])]);

        Response::json(['store' => self::loadByOwner($pdo, $config, $userId)], 201);
    }

    /** El slug no cambia al renombrar: los enlaces ya compartidos siguen sirviendo. */
    public static function update(PDO $pdo, array $config, int $userId): never
    {
        $store = self::requireOwn($pdo, $config, $userId);
        $fields = self::validatedFields(self::jsonBody(), requireAll: false);
        if ($fields === []) {
            Response::error('Nada que actualizar.');
        }

        // Las columnas salen de validatedFields (lista fija), nunca del request.
        $assignments = implode(', ', array_map(static fn(string $column) => "$column = :$column", array_keys($fields)));
        $pdo->prepare("UPDATE stores SET $assignments, updated_at = now() WHERE slug = :store_slug")
            ->execute([...$fields, 'store_slug' => $store['slug']]);

        Response::json(['store' => self::loadByOwner($pdo, $config, $userId)]);
    }

    public static function uploadLogo(PDO $pdo, array $config, int $userId): never
    {
        $store = self::requireOwn($pdo, $config, $userId);
        $path = ImageUpload::storeLogo($_FILES['photo'] ?? null, $config['media_dir']);

        $previous = $pdo->prepare('SELECT logo_path FROM stores WHERE slug = ?');
        $previous->execute([$store['slug']]);
        $oldPath = $previous->fetchColumn();

        $pdo->prepare('UPDATE stores SET logo_path = ?, updated_at = now() WHERE slug = ?')
            ->execute([$path, $store['slug']]);
        if (is_string($oldPath)) {
            ImageUpload::delete($config['media_dir'], $oldPath);
        }

        Response::json(['store' => self::loadByOwner($pdo, $config, $userId)]);
    }

    /** Tienda del usuario en cualquier estado, o null si no tiene. */
    public static function loadByOwner(PDO $pdo, array $config, int $userId): ?array
    {
        $statement = $pdo->prepare('SELECT * FROM stores WHERE owner_user_id = ?');
        $statement->execute([$userId]);
        $store = $statement->fetch();
        return $store === false ? null : self::present($store, $config);
    }

    public static function present(array $store, array $config): array
    {
        return [
            'slug' => $store['slug'],
            'name' => $store['name'],
            'description' => $store['description'],
            'city' => $store['city'],
            'whatsapp_phone' => $store['whatsapp_phone'],
            'delivery_options' => json_decode($store['delivery_options'], true),
            'logo_url' => Media::url($store['logo_path'], $config),
            'status' => $store['status'],
            'is_featured' => (bool) $store['is_featured'],
            'review_note' => $store['review_note'],
        ];
    }

    private static function requireOwn(PDO $pdo, array $config, int $userId): array
    {
        $store = self::loadByOwner($pdo, $config, $userId);
        if ($store === null) {
            Response::error('Todavía no tienes una tienda.', 404);
        }
        return $store;
    }

    private static function validatedFields(array $body, bool $requireAll): array
    {
        $fields = [];
        $has = static fn(string $key) => $requireAll || array_key_exists($key, $body);

        if ($has('name')) {
            $name = Validation::optionalText($body['name'] ?? null, self::MAX_NAME_LENGTH);
            if (!is_string($name) || mb_strlen($name) < 3) {
                Response::error('El nombre de la tienda debe tener entre 3 y ' . self::MAX_NAME_LENGTH . ' caracteres.');
            }
            $fields['name'] = $name;
        }
        if ($has('description')) {
            $description = Validation::optionalText($body['description'] ?? null, self::MAX_DESCRIPTION_LENGTH);
            if ($description === false) {
                Response::error('La descripción debe tener hasta ' . self::MAX_DESCRIPTION_LENGTH . ' caracteres.');
            }
            $fields['description'] = $description;
        }
        if ($has('city')) {
            $city = Validation::optionalText($body['city'] ?? null, self::MAX_CITY_LENGTH);
            if (!is_string($city)) {
                Response::error('Indica la ciudad de la tienda.');
            }
            $fields['city'] = $city;
        }
        if ($has('whatsapp_phone')) {
            $phone = Validation::phone($body['whatsapp_phone'] ?? null);
            if ($phone === null) {
                Response::error('El WhatsApp debe ser un celular de Bolivia (8 dígitos).');
            }
            $fields['whatsapp_phone'] = $phone;
        }
        if ($has('delivery_options')) {
            $options = $body['delivery_options'] ?? null;
            if (!is_array($options) || $options === [] || array_diff($options, self::DELIVERY_OPTIONS) !== []) {
                Response::error('Elige al menos una forma de entrega.');
            }
            $fields['delivery_options'] = json_encode(array_values(array_unique($options)));
        }
        return $fields;
    }

    /** "Aero Model La Paz" → "aero-model-la-paz" (o "-2", "-3"... si ya existe). */
    private static function uniqueSlug(PDO $pdo, string $name): string
    {
        $base = strtolower(strtr($name, [
            'á' => 'a', 'é' => 'e', 'í' => 'i', 'ó' => 'o', 'ú' => 'u', 'ü' => 'u', 'ñ' => 'n',
            'Á' => 'a', 'É' => 'e', 'Í' => 'i', 'Ó' => 'o', 'Ú' => 'u', 'Ü' => 'u', 'Ñ' => 'n',
        ]));
        $base = trim(preg_replace('/[^a-z0-9]+/', '-', $base) ?? '', '-') ?: 'tienda';

        $exists = $pdo->prepare('SELECT 1 FROM stores WHERE slug = ?');
        $slug = $base;
        for ($suffix = 2; ; $suffix++) {
            $exists->execute([$slug]);
            if ($exists->fetchColumn() === false) {
                return $slug;
            }
            $slug = "$base-$suffix";
        }
    }

    private static function jsonBody(): array
    {
        $body = json_decode(file_get_contents('php://input') ?: '', true);
        if (!is_array($body)) {
            Response::error('Cuerpo JSON inválido.');
        }
        return $body;
    }
}

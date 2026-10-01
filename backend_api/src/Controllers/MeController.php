<?php

declare(strict_types=1);

final class MeController
{
    private const MAX_NAME_LENGTH = 60;
    private const MAX_CITY_LENGTH = 60;

    private const USER_COLUMNS = 'id, phone, display_name, city, is_admin, created_at';

    // El primer request autenticado crea el usuario: el registro es el OTP.
    public static function show(PDO $pdo, string $phone): never
    {
        $statement = $pdo->prepare(
            'INSERT INTO users (phone) VALUES (?)
             ON CONFLICT (phone) DO UPDATE SET phone = EXCLUDED.phone
             RETURNING ' . self::USER_COLUMNS . ', (xmax = 0) AS is_new'
        );
        $statement->execute([$phone]);
        $row = $statement->fetch();

        Response::json(['user' => self::present($row), 'is_new' => (bool) $row['is_new']]);
    }

    public static function update(PDO $pdo, string $phone): never
    {
        $body = json_decode(file_get_contents('php://input') ?: '', true);
        if (!is_array($body)) {
            Response::error('Cuerpo JSON inválido.');
        }

        $changes = [];
        if (array_key_exists('display_name', $body)) {
            $name = Validation::optionalText($body['display_name'], self::MAX_NAME_LENGTH);
            if ($name === false) {
                Response::error('El nombre debe tener hasta ' . self::MAX_NAME_LENGTH . ' caracteres.');
            }
            $changes['display_name'] = $name;
        }
        if (array_key_exists('city', $body)) {
            $city = Validation::optionalText($body['city'], self::MAX_CITY_LENGTH);
            if ($city === false) {
                Response::error('La ciudad debe tener hasta ' . self::MAX_CITY_LENGTH . ' caracteres.');
            }
            $changes['city'] = $city;
        }
        if ($changes === []) {
            Response::error('Nada que actualizar.');
        }

        // Las columnas salen de la lista fija de arriba, nunca del request.
        $assignments = implode(', ', array_map(static fn(string $column) => "$column = :$column", array_keys($changes)));
        $statement = $pdo->prepare(
            "UPDATE users SET $assignments WHERE phone = :phone RETURNING " . self::USER_COLUMNS
        );
        $statement->execute([...$changes, 'phone' => $phone]);
        $row = $statement->fetch();
        if ($row === false) {
            Response::error('Usuario no encontrado.', 404);
        }

        Response::json(['user' => self::present($row)]);
    }

    private static function present(array $row): array
    {
        return [
            'id' => (int) $row['id'],
            'phone' => $row['phone'],
            'display_name' => $row['display_name'],
            'city' => $row['city'],
            'is_admin' => (bool) $row['is_admin'],
            'created_at' => $row['created_at'],
        ];
    }
}

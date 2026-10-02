<?php

declare(strict_types=1);

final class Users
{
    /** Id del usuario con ese teléfono; lo crea si es su primer request. */
    public static function idForPhone(PDO $pdo, string $phone): int
    {
        $statement = $pdo->prepare(
            'INSERT INTO users (phone) VALUES (?)
             ON CONFLICT (phone) DO UPDATE SET phone = EXCLUDED.phone
             RETURNING id'
        );
        $statement->execute([$phone]);
        return (int) $statement->fetchColumn();
    }
}

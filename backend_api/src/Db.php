<?php

declare(strict_types=1);

final class Db
{
    private static ?PDO $pdo = null;

    public static function connect(array $dbConfig): PDO
    {
        if (self::$pdo !== null) {
            return self::$pdo;
        }

        $schema = $dbConfig['schema'];
        // El schema se interpola en SQL: solo se aceptan los nuestros. Esto
        // también impide apuntar por error a "public" de gyros.
        if (!preg_match('/^hobbystore(_[a-z]+)?$/', $schema)) {
            throw new RuntimeException('Schema no permitido.');
        }

        $pdo = new PDO($dbConfig['dsn'], $dbConfig['user'], $dbConfig['password'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
        $pdo->exec("SET search_path TO {$schema}");

        return self::$pdo = $pdo;
    }
}

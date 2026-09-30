<?php

declare(strict_types=1);

final class Router
{
    /** @var array<int, array{string, string, callable}> */
    private array $routes = [];

    public function get(string $pattern, callable $handler): void
    {
        $this->routes[] = ['GET', $pattern, $handler];
    }

    public function post(string $pattern, callable $handler): void
    {
        $this->routes[] = ['POST', $pattern, $handler];
    }

    public function patch(string $pattern, callable $handler): void
    {
        $this->routes[] = ['PATCH', $pattern, $handler];
    }

    public function put(string $pattern, callable $handler): void
    {
        $this->routes[] = ['PUT', $pattern, $handler];
    }

    public function delete(string $pattern, callable $handler): void
    {
        $this->routes[] = ['DELETE', $pattern, $handler];
    }

    // Patrones tipo "/v1/products/{id}"; los parámetros llegan en orden al handler.
    public function dispatch(string $method, string $path): never
    {
        $pathMatched = false;
        foreach ($this->routes as [$routeMethod, $pattern, $handler]) {
            $regex = '#^' . preg_replace('#\{[a-z_]+\}#', '([^/]+)', $pattern) . '$#';
            if (!preg_match($regex, $path, $matches)) {
                continue;
            }
            $pathMatched = true;
            if ($routeMethod === $method) {
                $handler(...array_map('urldecode', array_slice($matches, 1)));
                Response::error('Sin respuesta.', 500);
            }
        }

        $pathMatched
            ? Response::error('Método no permitido.', 405)
            : Response::error('Ruta no encontrada.', 404);
    }

    // Soporta rewrite (/hobbystore/api/v1/x) y PATH_INFO (/index.php/v1/x).
    public static function requestPath(): string
    {
        if (!empty($_SERVER['PATH_INFO'])) {
            return '/' . trim($_SERVER['PATH_INFO'], '/');
        }
        $uriPath = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
        $basePath = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
        if ($basePath !== '' && str_starts_with($uriPath, $basePath)) {
            $uriPath = substr($uriPath, strlen($basePath));
        }
        return '/' . trim($uriPath, '/');
    }
}

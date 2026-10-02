<?php

declare(strict_types=1);

/**
 * Fotos de productos subidas por los usuarios. Se re-codifican siempre con GD:
 * así solo se guarda una imagen válida y se descartan los metadatos EXIF (entre
 * ellos la ubicación GPS con la que muchos celulares etiquetan las fotos).
 */
final class ImageUpload
{
    private const MAX_BYTES = 8 * 1024 * 1024;
    // Tope de píxeles antes de decodificar: GD usa ~4 bytes por píxel y el
    // pool PHP tiene 128 MB de memoria.
    private const MAX_PIXELS = 25_000_000;
    private const FULL_SIZE = 1200;
    private const THUMB_SIZE = 400;
    private const JPEG_QUALITY = 82;

    private const MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

    // Solo se borran archivos subidos por usuarios; nunca la media de la demo.
    private const UPLOADS_PREFIX = 'u/';

    /** @return array{path: string, thumb_path: string} rutas relativas a media_dir */
    public static function storeProductPhoto(mixed $file, string $mediaDir): array
    {
        if (!is_array($file) || !isset($file['error']) || is_array($file['error'])) {
            Response::error('Falta la foto.');
        }
        if ($file['error'] === UPLOAD_ERR_INI_SIZE || $file['error'] === UPLOAD_ERR_FORM_SIZE
            || ($file['size'] ?? 0) > self::MAX_BYTES) {
            Response::error('La foto supera los 8 MB.', 413);
        }
        if ($file['error'] !== UPLOAD_ERR_OK || !is_uploaded_file($file['tmp_name'])) {
            Response::error('No se pudo recibir la foto. Intenta de nuevo.');
        }

        $mime = (new finfo(FILEINFO_MIME_TYPE))->file($file['tmp_name']);
        $size = @getimagesize($file['tmp_name']);
        if (!in_array($mime, self::MIME_TYPES, true) || $size === false) {
            Response::error('La foto debe ser JPG, PNG o WEBP.', 415);
        }
        if ($size[0] * $size[1] > self::MAX_PIXELS) {
            Response::error('La foto es demasiado grande en píxeles.', 413);
        }

        $image = match ($mime) {
            'image/jpeg' => @imagecreatefromjpeg($file['tmp_name']),
            'image/png' => @imagecreatefrompng($file['tmp_name']),
            'image/webp' => @imagecreatefromwebp($file['tmp_name']),
        };
        if ($image === false) {
            Response::error('No se pudo leer la foto.', 415);
        }
        if ($mime === 'image/jpeg') {
            $image = self::applyExifOrientation($image, $file['tmp_name']);
        }

        $relativeDir = self::UPLOADS_PREFIX . date('Y/m');
        $absoluteDir = rtrim($mediaDir, '/') . '/' . $relativeDir;
        if (!is_dir($absoluteDir) && !mkdir($absoluteDir, 0755, true) && !is_dir($absoluteDir)) {
            throw new RuntimeException("No se pudo crear $absoluteDir");
        }

        $name = bin2hex(random_bytes(12));
        $paths = ['path' => "$relativeDir/$name.jpg", 'thumb_path' => "$relativeDir/{$name}_t.jpg"];
        self::saveJpeg($image, self::FULL_SIZE, rtrim($mediaDir, '/') . '/' . $paths['path']);
        self::saveJpeg($image, self::THUMB_SIZE, rtrim($mediaDir, '/') . '/' . $paths['thumb_path']);
        imagedestroy($image);

        return $paths;
    }

    public static function delete(string $mediaDir, string ...$paths): void
    {
        foreach ($paths as $path) {
            if (str_starts_with($path, self::UPLOADS_PREFIX) && !str_contains($path, '..')) {
                @unlink(rtrim($mediaDir, '/') . '/' . $path);
            }
        }
    }

    // Los celulares guardan la foto "acostada" y la marcan con Orientation;
    // al re-codificar se pierde esa marca, así que se rota aquí.
    private static function applyExifOrientation(GdImage $image, string $file): GdImage
    {
        $orientation = (@exif_read_data($file) ?: [])['Orientation'] ?? 1;
        $angle = match ($orientation) {
            3 => 180,
            6 => -90,
            8 => 90,
            default => 0,
        };
        if ($angle === 0) {
            return $image;
        }
        $rotated = imagerotate($image, $angle, 0);
        imagedestroy($image);
        return $rotated;
    }

    private static function saveJpeg(GdImage $source, int $maxSide, string $target): void
    {
        $width = imagesx($source);
        $height = imagesy($source);
        $scale = min(1, $maxSide / max($width, $height));
        $newWidth = max(1, (int) round($width * $scale));
        $newHeight = max(1, (int) round($height * $scale));

        $canvas = imagecreatetruecolor($newWidth, $newHeight);
        // Fondo blanco: un PNG con transparencia quedaría negro en JPEG.
        imagefill($canvas, 0, 0, imagecolorallocate($canvas, 255, 255, 255));
        imagecopyresampled($canvas, $source, 0, 0, 0, 0, $newWidth, $newHeight, $width, $height);
        imagejpeg($canvas, $target, self::JPEG_QUALITY);
        imagedestroy($canvas);
    }
}

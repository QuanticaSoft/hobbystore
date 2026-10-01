<?php

declare(strict_types=1);

final class Auth
{
    private const SESSION_CHECK_TIMEOUT_SECONDS = 10;

    /**
     * Devuelve el teléfono verificado del request o responde 401.
     *
     * La identidad la da el OTP existente (session.php); aquí solo se cachea
     * para no consultar al gateway en la Raspberry Pi en cada request.
     */
    public static function requirePhone(PDO $pdo, array $config): string
    {
        $token = Validation::sessionToken($_SERVER['HTTP_X_SESSION_TOKEN'] ?? null);
        if ($token === null) {
            Response::error('Sesión requerida.', 401);
        }

        if ($config['otp_session_url'] === 'mock') {
            return self::mockPhone($config);
        }

        $tokenHash = hash('sha256', $token);
        $cached = $pdo->prepare('SELECT phone FROM auth_cache WHERE token_hash = ? AND expires_at > now()');
        $cached->execute([$tokenHash]);
        $phone = $cached->fetchColumn();
        if (is_string($phone)) {
            return $phone;
        }

        $phone = self::fetchSessionPhone($config['otp_session_url'], $token);

        $pdo->exec('DELETE FROM auth_cache WHERE expires_at <= now()');
        $pdo->prepare(
            "INSERT INTO auth_cache (token_hash, phone, expires_at)
             VALUES (?, ?, now() + make_interval(secs => ?))
             ON CONFLICT (token_hash) DO UPDATE SET phone = EXCLUDED.phone, expires_at = EXCLUDED.expires_at"
        )->execute([$tokenHash, $phone, $config['auth_cache_seconds']]);

        return $phone;
    }

    // En dev la app usa MockOtpService, cuyos tokens no conoce ningún servidor:
    // la app manda su teléfono en X-Dev-Phone y se confía en él.
    private static function mockPhone(array $config): string
    {
        if ($config['env'] !== 'dev') {
            throw new RuntimeException('otp_session_url=mock solo está permitido en dev.');
        }
        $phone = Validation::phone($_SERVER['HTTP_X_DEV_PHONE'] ?? null);
        if ($phone === null) {
            Response::error('Falta X-Dev-Phone válido (modo mock).', 401);
        }
        return $phone;
    }

    private static function fetchSessionPhone(string $sessionUrl, string $token): string
    {
        $curl = curl_init($sessionUrl);
        curl_setopt_array($curl, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode(['token' => $token]),
            CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => self::SESSION_CHECK_TIMEOUT_SECONDS,
        ]);
        $body = curl_exec($curl);
        $httpStatus = curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
        $curlError = curl_error($curl);
        curl_close($curl);

        $data = is_string($body) ? json_decode($body, true) : null;
        if ($httpStatus !== 200 || !is_array($data)) {
            error_log("[hobbystore] session.php falló: http=$httpStatus curl=$curlError");
            Response::error('No se pudo validar la sesión. Intenta de nuevo.', 503);
        }

        $phone = Validation::phone($data['phone'] ?? null);
        if (($data['status'] ?? null) !== 'valid' || $phone === null) {
            Response::error('La sesión no es válida o expiró.', 401);
        }
        return $phone;
    }
}

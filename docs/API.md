# API Hobby Store (v1)

- Base: ver "Entornos" en `docs/PROGRESS.md`.
- Todas las respuestas son JSON. Un error tiene la forma `{"status":"error","message":"..."}` con el código HTTP correspondiente.
- Autenticación: header `X-Session-Token: <token de otp_auth>`.
  - La API lo valida contra `otp/session.php` y guarda en caché el resultado 10 min (`auth_cache`).
  - Sin token, o con un token inválido o expirado, responde 401. Si no puede consultar al OTP, responde 503.
  - **Solo en dev** (`otp_session_url = mock`): el servidor no puede validar tokens del `MockOtpService`, así que confía en el header `X-Dev-Phone: +591XXXXXXXX`. Con `env` distinto de `dev`, el modo mock se rechaza.

| Método | Ruta | Auth | Respuesta |
|---|---|---|---|
| GET | `/v1/health` | no | `{status, env, api_version, db, schema, last_migration}` · 503 si la BD falla |
| GET | `/v1/config` | no | `{min_app_version}`: si la app es menor, debe pedir actualizar |
| GET | `/v1/me` | sí | `{user: {id, phone, display_name, city, is_admin, created_at}, is_new}`. Crea el usuario en su primer request |
| PATCH | `/v1/me` | sí | Body `{display_name?, city?}` (máximo 60 caracteres; `""` o `null` borran el valor) → `{user}`. 400 con `message` si un campo es inválido o el body viene vacío |

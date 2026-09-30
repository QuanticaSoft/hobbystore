# API Hobby Store (v1)

- Base: ver "Entornos" en `docs/PROGRESS.md`.
- Todas las respuestas son JSON. Un error tiene la forma `{"status":"error","message":"..."}` con el código HTTP correspondiente.
- Autenticación (desde la Fase 1): header `X-Session-Token: <token de otp_auth>`.

| Método | Ruta | Auth | Respuesta |
|---|---|---|---|
| GET | `/v1/health` | no | `{status, env, api_version, db, schema, last_migration}` · 503 si la BD falla |
| GET | `/v1/config` | no | `{min_app_version}`: si la app es menor, debe pedir actualizar |

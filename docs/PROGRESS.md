# Hobby Store: Progreso

Última actualización: 2026-09-30 · Fase actual: **1: Login + esqueleto app** (en staging, falta probar en dispositivo)

## Dónde quedamos
- **Fase 1 en `develop` y desplegada en staging** (PR #1 con merge).
  - `/v1/me` en staging: 401 sin token y con token inválido.
  - PHP-FPM sí puede consultar `otp/session.php`; SELinux no bloquea.
- **Flutter actualizado a 3.47.5:**
  - El simulador iOS ya compila.
  - El `pubspec.lock` del SDK quedó guardado en `git stash` del checkout de Flutter.
- **Siguiente paso:**
  1. El usuario prueba en el dispositivo con `ENV=staging` (SMS real): login → completar el perfil → cerrar sesión → volver a entrar.
  2. Si todo está OK, release `v0.1.0`.

## Estado por fase
| Fase | Estado | Notas |
|---|---|---|
| 0 Fundaciones | ✅ | v0.0.1 en staging y prod, `public` verificado, repo en GitHub |
| 1 Login + esqueleto app | 🔄 | En staging; falta la prueba en el dispositivo y el release v0.1.0 |
| 2 Catálogo + Home | ⏳ | |
| 3 Favoritos + Carrito | ⏳ | |
| 4 Pedido → WhatsApp | ⏳ | |
| 5 Vender (particulares) | ⏳ | |
| 6 Tiendas + Admin | ⏳ | |
| 7 Publicación en tiendas | ⏳ | |

## Features

### ✅ Hecho
- Monorepo (`app_hobbystore/`, `packages/`, `backend_api/`, `infra/`, `docs/`)
- `packages/otp_auth` copiado de celulares-platform (`72d4c03`)
- Dev local: `docker compose -f infra/docker-compose.dev.yml up -d` (PG18 en `:5433`, API en `:8080`)
- API: front controller, router, `/v1/health`, `/v1/config`
- Migración `001_users_auth` (users, auth_cache) y `scripts/migrate.sh` con `schema_migrations`
- `scripts/deploy.sh` y `scripts/backup.sh` con validación de rama, tag y entorno

### 🔄 En proceso
- **Fase 1** (PR #1 con merge, en staging):
  - App: login OTP → shell con 5 tabs, perfil editable (nombre y ciudad), cerrar sesión, sesión expirada.
  - App: `AppConfig` por entorno, `ApiClient` con `X-Session-Token` (`X-Dev-Phone` en dev mock).
  - API: `Auth` contra `otp/session.php` + `auth_cache`, `GET/PATCH /v1/me`.
  - Ids `com.quanticasoft.hobbystore`, "Hobby Store", iOS 15.0.

### ⏳ Pendiente
- Fases 2 a 7: detalle de cada fase en `docs/PLAN.md`.

### 🧊 Postergado (post-MVP)
- Pago QR o pasarela, reseñas y rating, push notifications, chat interno, búsqueda full-text, versión web, envíos con tarifa.

## Checklist Fase 1
- [x] `flutter analyze` sin issues · `flutter test` 10/10
- [x] API dev: 401 sin token o con token inválido, 503 si el OTP no responde, upsert e `is_new`, validaciones del PATCH
- [x] `flutter build apk --debug` ✅ · `flutter build ios --no-codesign` ✅
- [x] Simulador iOS compila (resuelto con Flutter 3.47.5)
- [x] staging: `/v1/me` responde 401 con token inválido (la salida HTTP de PHP-FPM funciona)
- [ ] staging: `/v1/me` con un token real (lo cubre la prueba en el dispositivo)
- [ ] Dispositivo: login con SMS real → completar el perfil → cerrar sesión → volver a entrar

## Checklist Fase 0 (cerrada)
- [x] `curl localhost:8080/v1/health` → `db: ok`, `schema: hobbystore`
- [x] `migrate.sh dev` es idempotente (la segunda corrida aplica 0)
- [x] `app_root.php` no es accesible por HTTP (403)
- [x] staging: `/hobbystore/api-staging/v1/health` → `db: ok`, `schema: hobbystore_staging`
- [x] prod: `/hobbystore/api/v1/health` → `db: ok`, `schema: hobbystore`
- [x] Las tablas de `public` en gyros no cambiaron (40 relaciones, md5 `f7d79010…` antes y después del deploy)

## Bloqueos / preguntas abiertas
- Emulador Android + API dev: usar `--dart-define=API_BASE_URL=http://10.0.2.2:8080/v1`.
- Dependencias Flutter: `provider` ✅ aprobado. Pendientes de aprobación para las fases 2 a 5: `url_launcher`, `image_picker`, `cached_network_image`.
- Cuentas Google Play Console y Apple Developer (necesarias para la Fase 7; conviene tramitarlas antes).
- Número demo para los revisores de Apple y Google: requiere un cambio en el gateway OTP de celulares-platform.

## Entornos
- **Dev:** API `http://localhost:8080/v1` · PG Docker `:5433` (hobby/hobby, BD `hobbystore_dev`) · OTP `mock` (código 123456)
- **Staging:** `https://www.quanticasoft.com/hobbystore/api-staging/v1` · `gyros.hobbystore_staging` · rama `develop`
- **Prod:** `https://www.quanticasoft.com/hobbystore/api/v1` · `gyros.hobbystore` · tag en `main`

## Versiones
| Versión | Fecha | Entorno | Notas |
|---|---|---|---|
| v0.0.1 | 2026-09-30 | staging + prod | Fase 0: monorepo, API `/v1/health` y `/v1/config`, migración 001 |

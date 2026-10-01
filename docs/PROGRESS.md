# Hobby Store: Progreso

Última actualización: 2026-09-30 · Fase actual: **1: Login + esqueleto app** (en revisión)

## Dónde quedamos
- **Fase 1 programada y probada en local.** PR #1 `feature/f1-login-shell` → `develop`, esperando revisión y merge del usuario.
- **Después del merge:**
  1. `deploy.sh staging` y probar `/v1/me` en staging. Un token inválido debe dar 401; si da 503, SELinux bloquea la salida HTTP desde PHP-FPM.
  2. Probar en el dispositivo con `ENV=staging` (SMS real).
  3. Release `v0.1.0`.
- **Pendientes manuales:**
  - Decidir si se actualiza Flutter a 3.47.5 (`flutter upgrade`); arreglaría el build para simulador iOS.
  - La protección de `main` ya está activa.

## Estado por fase
| Fase | Estado | Notas |
|---|---|---|
| 0 Fundaciones | ✅ | v0.0.1 en staging y prod, `public` verificado, repo en GitHub |
| 1 Login + esqueleto app | 🔄 | PR #1 en revisión; falta probar en staging y en el dispositivo |
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
- **Fase 1** (PR #1):
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
- [ ] Simulador iOS: bloqueado por la incompatibilidad Flutter 3.44.1 ↔ `lipo` de Xcode 27
- [ ] staging: `/v1/me` con un token real del OTP
- [ ] Dispositivo: login con SMS real → completar el perfil → cerrar sesión → volver a entrar

## Checklist Fase 0 (cerrada)
- [x] `curl localhost:8080/v1/health` → `db: ok`, `schema: hobbystore`
- [x] `migrate.sh dev` es idempotente (la segunda corrida aplica 0)
- [x] `app_root.php` no es accesible por HTTP (403)
- [x] staging: `/hobbystore/api-staging/v1/health` → `db: ok`, `schema: hobbystore_staging`
- [x] prod: `/hobbystore/api/v1/health` → `db: ok`, `schema: hobbystore`
- [x] Las tablas de `public` en gyros no cambiaron (40 relaciones, md5 `f7d79010…` antes y después del deploy)

## Bloqueos / preguntas abiertas
- Simulador iOS: `flutter build ios --simulator` falla con Xcode 27 (`lipo -verify_arch` con varias arquitecturas). Solución probable: `flutter upgrade` (3.47.5). Mientras tanto, probar en un dispositivo físico o en el emulador Android.
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

# Hobby Store: Progreso

Última actualización: 2026-09-30 · Fase actual: **1: Login + esqueleto app** (por iniciar)

## Dónde quedamos
- **Fase 0 cerrada** (2026-09-30):
  - `v0.0.1` en staging y prod.
  - `gyros.public` verificado sin cambios.
  - GitHub tiene `main` (`addfc05`), `develop` y el tag `v0.0.1`.
  - `.claude/settings.json` permite a Claude Code hacer `git push` en este repo.
- **Siguiente paso:** Fase 1 en `feature/f1-login-shell`, cuando se aprueben las dependencias Flutter.
- **Pendiente manual:** activar la protección de `main` en GitHub (Settings → Branches).

## Estado por fase
| Fase | Estado | Notas |
|---|---|---|
| 0 Fundaciones | ✅ | v0.0.1 en staging y prod, `public` verificado, repo en GitHub |
| 1 Login + esqueleto app | ⏳ | |
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
- (nada)

### ⏳ Pendiente
- **Fase 1:**
  - Integrar `otp_auth` en la app, `HomeShell` con 5 tabs, `AppConfig` (ENV) y `ApiClient` con `X-Session-Token`.
  - En la API: `Auth` (validación contra `session.php` + `auth_cache`), `GET/PATCH /v1/me`.
  - Tema, nombre de la app y bundle id provisorios.
- Fases 2 a 7: detalle de cada fase en `docs/PLAN.md`.

### 🧊 Postergado (post-MVP)
- Pago QR o pasarela, reseñas y rating, push notifications, chat interno, búsqueda full-text, versión web, envíos con tarifa.

## Checklist de la fase actual (Fase 0)
- [x] `curl localhost:8080/v1/health` → `db: ok`, `schema: hobbystore`
- [x] `migrate.sh dev` es idempotente (la segunda corrida aplica 0)
- [x] `app_root.php` no es accesible por HTTP (403)
- [x] staging: `/hobbystore/api-staging/v1/health` → `db: ok`, `schema: hobbystore_staging`
- [x] prod: `/hobbystore/api/v1/health` → `db: ok`, `schema: hobbystore`
- [x] Las tablas de `public` en gyros no cambiaron (40 relaciones, md5 `f7d79010…` antes y después del deploy)

## Bloqueos / preguntas abiertas
- Aprobar las dependencias Flutter para Fase 1 y siguientes: `provider`, `url_launcher`, `image_picker`, `cached_network_image`.
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

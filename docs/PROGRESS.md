# Hobby Store: Progreso

Última actualización: 2026-09-30 · Fase actual: **0: Fundaciones**

## Dónde quedamos
- **Release `v0.0.1` en prod** (2026-09-30):
  - `https://www.quanticasoft.com/hobbystore/api/v1/health` → `db: ok`, schema `hobbystore`.
  - Staging también OK (`hobbystore_staging`).
- **Pendiente para cerrar la Fase 0** (lo hace el usuario, porque está bloqueado por permisos para Claude):
  1. `git push origin main develop --tags`
  2. Activar la protección de `main` en GitHub.
  3. Comprobar que `gyros.public` sigue igual a la línea base (40 relaciones, md5 `f7d79010eb52b85479557369fb4b622b`).
- **Siguiente paso:** Fase 1 (login + esqueleto de la app) en `feature/f1-login-shell`, después de aprobar las dependencias Flutter.

## Estado por fase
| Fase | Estado | Notas |
|---|---|---|
| 0 Fundaciones | 🔄 | v0.0.1 en staging y prod; falta el push y la verificación de `public` |
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
- GitHub: push, rama `develop` y protección de `main`

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
- [ ] Las tablas de `public` en gyros no cambian (conteo antes y después)

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

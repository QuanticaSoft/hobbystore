# Hobby Store: Progreso

Última actualización: 2026-09-30 · Fase actual: **0: Fundaciones**

## Dónde quedamos
- **Completado:**
  - El repo se reestructuró como monorepo.
  - Docs, `otp_auth` copiado, entorno dev en Docker y API mínima (`/v1/health`, `/v1/config`) probada en local.
  - Scripts `migrate`, `deploy` y `backup` listos.
- **En flamenco:**
  - Línea base de `gyros.public`: 40 relaciones.
  - Creados `~/hobbystore/{staging,prod}/config.local.php`.
  - Schema `hobbystore_staging` migrado (001).
  - API desplegada en `/hobbystore/api-staging`: `/v1/health` responde `db: ok` por TCP con password.
  - Los `config.local.php` de staging y prod ya tienen el DSN TCP y el password.
- **Siguiente paso:**
  1. Hacer el release `v0.0.1` y aplicar `migrate.sh prod` + `deploy.sh prod`.
  2. Verificar que `public` no cambió.
  3. Hacer push a GitHub.
  4. Cerrar la Fase 0.

## Estado por fase
| Fase | Estado | Notas |
|---|---|---|
| 0 Fundaciones | 🔄 | Staging OK; falta prod, el push y la verificación de `public` |
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
- Fase 0 en flamenco: schemas `hobbystore` / `hobbystore_staging`, deploy y health check
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
- [ ] prod: `/hobbystore/api/v1/health` → `schema: hobbystore`
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
| — | — | — | Todavía no hay release |

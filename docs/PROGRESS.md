# Hobby Store: Progreso

Última actualización: 2026-10-01 · Fase actual: **2: Catálogo + Home** (en staging, falta probar en dispositivo)

## Dónde quedamos
- **Fase 2 con merge en `develop`** (PR #4).
- **En staging:**
  - Migración 002, demo cargada (4 banners, 3 tiendas, 20 productos), API 0.2.0.
  - Media en `/hobbystore/media-staging`, protegida con `.htaccess` (sin listado, sin PHP).
  - `media_base_url` configurada en los `config.local.php` de staging y prod.
- **Siguiente paso:**
  1. El usuario prueba en el iPhone con `ENV=staging`.
  2. Release `v0.2.0`: prod solo con migración y deploy, sin demo.
- **Decidido:** prod sale con el catálogo vacío; se llena con la Fase 6 (ver DECISIONS).

## Estado por fase
| Fase | Estado | Notas |
|---|---|---|
| 0 Fundaciones | ✅ | v0.0.1 en staging y prod, `public` verificado, repo en GitHub |
| 1 Login + esqueleto app | ✅ | v0.1.0: login OTP, shell con 5 tabs, perfil; probado en iPhone |
| 2 Catálogo + Home | 🔄 | En staging; falta la prueba en el dispositivo y el release v0.2.0 |
| 3 Favoritos + Carrito | ⏳ | |
| 4 Pedido → WhatsApp | ⏳ | |
| 5 Vender (particulares) | ⏳ | |
| 6 Tiendas + Admin | ⏳ | |
| 7 Publicación en tiendas | ⏳ | |

## Features

### ✅ Hecho
- **Fase 1 (v0.1.0):**
  - Login OTP → shell con 5 tabs, perfil (nombre y ciudad), cerrar sesión, sesión expirada.
  - API `GET/PATCH /v1/me` con validación contra el OTP + `auth_cache`.
  - Ids `com.quanticasoft.hobbystore`, iOS 15.0, Flutter 3.47.5.
- Monorepo (`app_hobbystore/`, `packages/`, `backend_api/`, `infra/`, `docs/`)
- `packages/otp_auth` copiado de celulares-platform (`72d4c03`)
- Dev local: `docker compose -f infra/docker-compose.dev.yml up -d` (PG18 en `:5433`, API en `:8080`)
- API: front controller, router, `/v1/health`, `/v1/config`
- Migración `001_users_auth` (users, auth_cache) y `scripts/migrate.sh` con `schema_migrations`
- `scripts/deploy.sh` y `scripts/backup.sh` con validación de rama, tag y entorno

### 🔄 En proceso
- **Fase 2** (`feature/f2-catalogo-home`):
  - API pública: `/v1/home`, `/v1/categories`, `/v1/products` (category, store, q, page), `/v1/products/{id}`, `/v1/stores/{slug}`.
  - Migración `002_catalog` (12 categorías reales). Demo con `seed.sh dev|staging`.
  - App: Home (buscador, carrusel `CarouselView`, tiendas, novedades), Categorías, listado con scroll infinito, búsqueda, detalle (galería, vendedor, entrega) y tienda.
  - "Añadir al carrito" visible pero inactivo (llega en la Fase 3). Sin botón de WhatsApp (Fase 4, falta aprobar `url_launcher`).

### ⏳ Pendiente
- Fases 2 a 7: detalle de cada fase en `docs/PLAN.md`.

### 🧊 Postergado (post-MVP)
- Pago QR o pasarela, reseñas y rating, push notifications, chat interno, búsqueda full-text, versión web, envíos con tarifa.

## Checklist Fase 2
- [x] `flutter analyze` sin issues · `flutter test` 20/20
- [x] API dev: home, categorías con conteo, filtros, búsqueda (con escape de `%`, `_` y `!`, sin distinguir mayúsculas), paginación, 404, detalle de tienda y de particular
- [x] `seed.sh dev` es idempotente (dos corridas → 3 tiendas, 20 productos, 24 imágenes, 4 banners)
- [x] staging: migración 002 + demo + deploy; imágenes por HTTPS ✅
- [ ] Dispositivo: Home → banner/tienda → producto → galería; Categorías → listado; búsqueda; scroll infinito

## Checklist Fase 1 (cerrada)
- [x] `flutter analyze` sin issues · `flutter test` 10/10
- [x] API dev: 401 sin token o con token inválido, 503 si el OTP no responde, upsert e `is_new`, validaciones del PATCH
- [x] `flutter build apk --debug` ✅ · `flutter build ios --no-codesign` ✅
- [x] Simulador iOS compila (resuelto con Flutter 3.47.5)
- [x] staging: `/v1/me` responde 401 con token inválido (la salida HTTP de PHP-FPM funciona)
- [x] staging: `/v1/me` con token real (prueba en iPhone)
- [x] Dispositivo: login con SMS real → completar el perfil → cerrar sesión → volver a entrar

## Checklist Fase 0 (cerrada)
- [x] `curl localhost:8080/v1/health` → `db: ok`, `schema: hobbystore`
- [x] `migrate.sh dev` es idempotente (la segunda corrida aplica 0)
- [x] `app_root.php` no es accesible por HTTP (403)
- [x] staging: `/hobbystore/api-staging/v1/health` → `db: ok`, `schema: hobbystore_staging`
- [x] prod: `/hobbystore/api/v1/health` → `db: ok`, `schema: hobbystore`
- [x] Las tablas de `public` en gyros no cambiaron (40 relaciones, md5 `f7d79010…` antes y después del deploy)

## Bloqueos / preguntas abiertas
- Emulador Android + API dev: usar `--dart-define=API_BASE_URL=http://10.0.2.2:8080/v1`.
- Dependencias Flutter: `provider` ✅, `cached_network_image` ✅. Pendientes: `url_launcher` (Fase 4) e `image_picker` (Fase 5).
- Cuentas Google Play Console y Apple Developer (necesarias para la Fase 7; conviene tramitarlas antes).
- Número demo para los revisores de Apple y Google: requiere un cambio en el gateway OTP de celulares-platform.

## Entornos
- **Dev:** API `http://localhost:8080/v1` · demo: `backend_api/scripts/seed.sh dev` · PG Docker `:5433` (hobby/hobby, BD `hobbystore_dev`) · OTP `mock` (código 123456)
- **Staging:** `https://www.quanticasoft.com/hobbystore/api-staging/v1` · `gyros.hobbystore_staging` · rama `develop`
- **Prod:** `https://www.quanticasoft.com/hobbystore/api/v1` · `gyros.hobbystore` · tag en `main`

## Versiones
| Versión | Fecha | Entorno | Notas |
|---|---|---|---|
| v0.0.1 | 2026-09-30 | staging + prod | Fase 0: monorepo, API `/v1/health` y `/v1/config`, migración 001 |
| v0.1.0 | 2026-09-30 | staging + prod | Fase 1: login OTP, shell con 5 tabs, perfil, `/v1/me` |

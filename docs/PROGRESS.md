# Hobby Store: Progreso

Última actualización: 2026-10-02 · Fase actual: **4: Pedido → WhatsApp** (en staging, falta probar en dispositivo)

## Dónde quedamos
- **Fase 3 cerrada: release `v0.3.0`** (2026-10-02).
  - Probada por el usuario en su teléfono con `ENV=staging`: favoritos, carrito por vendedor, stock, contador.
  - La sesión, los favoritos y el carrito persisten al cerrar y reabrir la app, sin pedir código.
- **Fase 4 en staging** (PR #9 con merge): migración 004, API 0.4.0. Pedidos protegidos (401 sin sesión y con token inválido).
  - Siguiente: el usuario prueba en el teléfono con `ENV=staging` → release `v0.4.0`.
  - En la demo, los WhatsApp de tiendas y particulares son números ficticios (`+591600000XX`).

## Estado por fase
| Fase | Estado | Notas |
|---|---|---|
| 0 Fundaciones | ✅ | v0.0.1 en staging y prod, `public` verificado, repo en GitHub |
| 1 Login + esqueleto app | ✅ | v0.1.0: login OTP, shell con 5 tabs, perfil; probado en iPhone |
| 2 Catálogo + Home | ✅ | v0.2.0: Home, categorías, búsqueda, detalle y tienda; demo en staging |
| 3 Favoritos + Carrito | ✅ | v0.3.0: ♥ + tab Favoritos, carrito por vendedor con + / −, contador |
| 4 Pedido → WhatsApp | 🔄 | En staging; falta la prueba en el dispositivo y el release v0.4.0 |
| 5 Vender (particulares) | ⏳ | |
| 6 Tiendas + Admin | ⏳ | |
| 7 Publicación en tiendas | ⏳ | |

## Features

### ✅ Hecho
- **Fase 3 (v0.3.0):**
  - Migración 003. API con sesión: `/v1/favorites` y `/v1/cart`, agrupado por vendedor, con validación de stock y de producto propio.
  - App: ♥ (tarjeta y detalle) + tab Favoritos; "Añadir al carrito" + tab Carrito (+ / −, subtotales) + contador. `AppProviders` compartido con los tests.
- **Fase 2 (v0.2.0):**
  - API pública del catálogo (home, categorías, productos con filtros, búsqueda y paginación, detalle y tienda) + migración 002.
  - App: Home (buscador, banners, tiendas, novedades), Categorías, listado con scroll infinito, búsqueda, detalle y tienda.
  - Demo con `seed.sh` (solo dev y staging). Media protegida en flamenco.
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
- **Fase 4** (PR #9 con merge, en staging):
  - Migración 004. API: crear pedido desde un grupo del carrito (con fotos de título y precio, mensaje de WhatsApp armado en el servidor), listar como comprador o vendedor, y cambiar el estado con transiciones por rol.
  - App: hoja "Pedido a X" (nota opcional) → abre WhatsApp. Perfil › "Mis compras" / "Pedidos recibidos" con WhatsApp a la contraparte y botones de estado.
  - Particulares: WhatsApp a su celular verificado.

### ⏳ Pendiente
- Fases 2 a 7: detalle de cada fase en `docs/PLAN.md`.

### 🧊 Postergado (post-MVP)
- Pago QR o pasarela, reseñas y rating, push notifications, chat interno, búsqueda full-text, versión web, envíos con tarifa.

## Checklist Fase 4
- [x] `flutter analyze` sin issues · `flutter test` 32/32 (pedido → WhatsApp, sin nombre, WhatsApp que no abre, cancelación del comprador, confirmación del vendedor)
- [x] API dev: mensaje con productos, total y nota; el carrito se vacía de ese grupo; vendedor y particular (celular verificado); transiciones válidas e inválidas (409); otro usuario (404); rol inválido (400)
- [x] Builds: simulador iOS ✅ · APK debug ✅
- [x] staging: migración 004 + deploy (API 0.4.0)
- [ ] Dispositivo: pedir a una tienda y a un particular, que WhatsApp abra con el mensaje, Mis compras y Pedidos recibidos

## Checklist Fase 3 (cerrada)
- [x] `flutter analyze` sin issues · `flutter test` 27/27 (incluye backend falso con estado para favoritos y carrito)
- [x] API dev: 401 sin sesión, favoritos idempotentes, 404, agrupación por vendedor, totales, stock (409), cantidad 1 a 99, producto propio (400)
- [x] Builds: simulador iOS ✅ · APK debug ✅
- [x] staging: migración 003 + deploy (API 0.3.0)
- [x] Dispositivo: ♥, tab Favoritos, carrito por vendedor, + / −, stock, contador y persistencia al reabrir

## Checklist Fase 2 (cerrada)
- [x] `flutter analyze` sin issues · `flutter test` 22/22 (incluye un test de la app completa: navegación y cierre de sesión)
- [x] API dev: home, categorías con conteo, filtros, búsqueda (con escape de `%`, `_` y `!`, sin distinguir mayúsculas), paginación, 404, detalle de tienda y de particular
- [x] `seed.sh dev` es idempotente (dos corridas → 3 tiendas, 20 productos, 24 imágenes, 4 banners)
- [x] staging: migración 002 + demo + deploy; imágenes por HTTPS ✅
- [x] Dispositivo: navegación Home → tienda/producto (tras el arreglo del PR #5)

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
- Dependencias Flutter: `provider` ✅, `cached_network_image` ✅, `url_launcher` ✅. Pendiente: `image_picker` (Fase 5).
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
| v0.2.0 | 2026-10-01 | staging + prod | Fase 2: catálogo y Home (prod sin datos hasta la Fase 6) |
| v0.3.0 | 2026-10-02 | staging + prod | Fase 3: favoritos y carrito por vendedor |

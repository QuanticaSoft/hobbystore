# Hobby Store: plan de MVP

## Contexto

Hobby Store es un marketplace móvil (Android e iOS) de productos de hobby: aviones RC y estáticos (maquetas), barcos, autos, drones, accesorios, pinturas y herramientas.
- **Quién compra:** cualquier usuario.
- **Quién vende:** también cualquier usuario, de dos formas:
  - **Tiendas:** importadores con negocio, verificados. Su logo aparece en el Home.
  - **Particulares:** venta ocasional, típicamente de segunda mano, con límite de publicaciones.

**Punto de partida real:**
- `app_hobbystore/` es un Flutter "Hello World" (1 commit, remote `QuanticaSoft/hobbystore`).
- El login OTP ya funciona en producción en `celulares-platform`:
  - `packages/otp_auth` (Flutter).
  - `backend_flamenco/otp/*.php` en flamenco.
  - El gateway Node en la Raspberry Pi (`nas-meteo`) envía el SMS por ADB/módem.
- `pictures/` tiene imágenes reales para datos semilla: marcas, eventos, items, autos, drones.

**Decisiones tomadas contigo:**

| Tema | Decisión |
|---|---|
| Compra | Carrito agrupado por vendedor → se registra un pedido `pendiente` → se abre WhatsApp con el detalle prellenado. Pago y entrega se acuerdan fuera de la app. |
| Vendedores | Tiendas aprobadas + particulares (máximo 5 publicaciones activas). |
| Entrega | La define cada vendedor como información: ciudad, retiro en tienda, envío local o encomienda nacional. La app no hace logística. |
| Infra | API PHP y datos en flamenco. La Raspberry Pi queda **solo** como gateway SMS/OTP. |
| BD | Schema `hobbystore` **dentro** de la BD `gyros`, porque `marco` no tiene `CREATEDB`. Las tablas de gyros y el schema `public` no se tocan. |

**Probado en flamenco (solo lectura, 2026-09-30):**
- PHP 8.2 con `pdo_pgsql`, `gd`, `exif`, `fileinfo` e `intl`.
- php-fpm respeta `.user.ini`, así que el límite de subida de 2M se puede ampliar.
- Postgres 18. `marco` es dueño de `gyros`, pero no es superusuario ni tiene CREATEDB.
- No hay composer; hay node.
- `/webs` tiene 38G libres.
- `session.php` devuelve `{status:'valid', phone}`.

---

## Stack

| Capa | Elección | Por qué |
|---|---|---|
| App | Flutter (SDK ^3.12), Material 3 | Ya existe. Un solo código para Android e iOS. |
| Estado | `ChangeNotifier` + paquete `provider` | Liviano y encaja con `otp_auth` (setState + Navigator). Riverpod o bloc serían sobre-ingeniería para el MVP. |
| Navegación | `Navigator` imperativo + `NavigationBar` con 5 tabs | `otp_auth` ya navega así; go_router obligaría a adaptar el paquete. |
| Login | `packages/otp_auth` **copiado** a `Hobby-Store/packages/otp_auth` | Un `path:` hacia otro repo rompe clones y CI. Se copia tal cual y se anota el origen en DECISIONS. |
| HTTP | `http` (ya viene con otp_auth) | Sin dependencias nuevas. |
| Carrusel | `CarouselView` (incluido en Flutter Material) | Sin dependencia. |
| API | PHP 8.2 plano + PDO, front controller `index.php` | Mismo estilo que `backend_flamenco/otp` (`Response`, `Validation`). Sin composer. |
| BD | PostgreSQL 18, schema `hobbystore` | Aislado con `SET search_path TO hobbystore` en cada conexión. |
| Imágenes | Disco en flamenco `/webs/quanticasoft/hobbystore/media/` | La app comprime al elegir la foto (`image_picker` con maxWidth 1600, quality 80); el servidor genera thumbnails con GD. |
| Auth API | Header `X-Session-Token` | El header `Authorization` no pasa bajo PHP-FPM, como ya documenta `session.php`. La API valida el token contra `https://www.quanticasoft.com/otp/session.php` y guarda en caché el hash del token y el teléfono por 10 minutos (tabla `auth_cache`) para no cargar la Raspberry Pi. |
| Deploy | `rsync` a `/webs/quanticasoft/hobbystore/api` | Igual que el OTP. Sin sudo ni docker en flamenco. |
| Dev local | Postgres 18 en Docker en el Mac (schema `hobbystore`) + `php -S` | Paridad con producción sin tocar flamenco. |

**Dependencias Flutter nuevas (a aprobar):**
- `provider`
- `url_launcher` (links wa.me)
- `image_picker` (fotos al publicar)
- `cached_network_image` (caché de imágenes del catálogo)

---

## Estructura del repo (monorepo)

```
Hobby-Store/                  ← raíz del repo git (se mueve .git desde app_hobbystore/)
├── CLAUDE.md                 ← reglas duras: no tocar gyros/public, sin sudo, RPi solo SMS
├── docs/
│   ├── PROGRESS.md           ← MEMORIA DE AVANCE (ver abajo)
│   ├── DECISIONS.md          ← decisiones con fecha y motivo
│   ├── ARCHITECTURE.md       ← diagrama app → API PHP → PG / OTP → RPi
│   └── API.md                ← contrato de endpoints
├── app_hobbystore/           ← Flutter, organizado por feature:
│   └── lib/{core/(api,config,theme), features/(home,catalog,product,cart,favorites,orders,sell,store,profile,admin), main.dart}
├── packages/otp_auth/        ← copia del paquete de celulares-platform
├── backend_api/
│   ├── public/index.php, .htaccess, .user.ini
│   ├── src/{Db,Auth,Response,Validation,Router,Controllers/*}.php
│   ├── config.php (+ config.local.php fuera de git)
│   └── sql/{001_schema.sql, 002_seed_categories.sql, ...}   ← migraciones numeradas
├── infra/docker-compose.dev.yml   ← solo Postgres local
└── pictures/                 ← fuera de git (.gitignore); de aquí salen los datos semilla
```

---

## Ramas, entornos y versionamiento

### Ramas (Git Flow simplificado)

```
main ─────●──────────────●────────────●───────▶  producción (solo recibe merges; cada merge lleva un tag)
           \            / \          /
develop ────●──●──●───●────●──●──●──●─────────▶  integración / staging (siempre compila)
             \   /  \   /
feature/...   ●─●    ●─●                           una rama por feature o tarea
hotfix/...                  ●  (sale de main, vuelve a main y a develop)
```

| Rama | Sale de | Entra a | Para qué |
|---|---|---|---|
| `main` | — | — | Código en producción. Protegida en GitHub: sin push directo, merge solo por PR. |
| `develop` | `main` | `main` (en un release) | Integración diaria; se despliega a **staging**. |
| `feature/<fase>-<nombre>` | `develop` | `develop` (PR, squash) | Ejemplos: `feature/f1-login-shell`, `feature/f2-catalogo-home`. |
| `fix/<nombre>` | `develop` | `develop` | Bugs que no son urgentes. |
| `hotfix/<version>` | `main` | `main` + `develop` | Bug urgente en producción, p.ej. `hotfix/0.2.1`. |

**Commits** con Conventional Commits (el prefijo en inglés y la descripción en español):
- `feat(catalog): grilla de productos por categoría`
- `fix(cart): subtotal por vendedor`
- `docs:`, `chore:`, `refactor:`, `test:`, `db:` (migraciones)

Esto hace que el CHANGELOG salga casi directo del `git log`.

### Entornos

| Entorno | Rama | API | BD | OTP |
|---|---|---|---|---|
| **dev** (tu Mac) | cualquier `feature/*` | `http://localhost:8080` (`php -S`) | Postgres Docker, schema `hobbystore` | `mock` (código 123456) |
| **staging** | `develop` | `https://www.quanticasoft.com/hobbystore/api-staging` | `gyros` → schema **`hobbystore_staging`** | real |
| **prod** | `main` (tag) | `https://www.quanticasoft.com/hobbystore/api` | `gyros` → schema **`hobbystore`** | real |

- La app elige el entorno con `--dart-define=ENV=dev|staging|prod`, que fija `API_BASE_URL` y `OTP_BASE_URL`.
- Los builds de staging se distribuyen como pista interna de Play y TestFlight interno. En Android llevan un sufijo de applicationId `.staging` para instalarlas junto a la de producción.
- `deploy.sh staging|prod` rechaza el deploy si la rama o el tag no coinciden (prod exige estar en un tag de `main`). Cada entorno tiene su propio `config.local.php`.

### Versionamiento (SemVer)

- **App:** `pubspec.yaml` usa `version: MAJOR.MINOR.PATCH+BUILD`.
  - `0.N.x` = MVP en curso, con N = fase terminada: `0.1.0` = Fase 1, `0.2.0` = Fase 2, etc.
  - `1.0.0` = primera publicación en las tiendas (fin de la Fase 7).
  - `PATCH` sube en hotfix y fixes; `MINOR` en features nuevas; `MAJOR` en cambios incompatibles.
  - `+BUILD` es un entero **siempre creciente**, porque Play y App Store lo exigen. Nunca se reutiliza.
- **API:** las rutas llevan prefijo `/v1/...`.
  - Mientras haya apps viejas instaladas, un cambio incompatible no rompe `/v1`: se crea `/v2`.
  - `GET /v1/config` devuelve `min_app_version`. Si la app está por debajo, muestra "Actualiza la app".
- **BD:** migraciones numeradas e inmutables en `backend_api/sql/NNN_descripcion.sql`.
  - La tabla `schema_migrations` registra cuáles ya se aplicaron.
  - El script `migrate.sh <env>` aplica solo las pendientes: primero en staging y después en prod.
  - Antes de cada migración en prod se hace backup con `pg_dump -n hobbystore`.
- **Tags y releases:** `vX.Y.Z` en `main` + GitHub Release con notas + `CHANGELOG.md` (formato Keep a Changelog).

### Flujo de un release
1. Terminar las features en `develop`, desplegar a staging y probar en el dispositivo con el checklist de la fase.
2. Subir la versión en `pubspec.yaml` y actualizar `CHANGELOG.md` y `docs/PROGRESS.md` en `develop`.
3. PR `develop → main`, merge y tag `vX.Y.Z`.
4. Hacer backup, ejecutar `migrate.sh prod` y `deploy.sh prod`, y generar los builds de release para las tiendas.
5. Después de un hotfix: merge a `main` + tag, y merge de vuelta a `develop`.

---

## Modelo de datos (schema `hobbystore`)

- **`users`**
  - Campos: `id`, `phone` (único), `display_name`, `city`, `is_admin`, `created_at`, `deleted_at`.
  - Se crea al primer request autenticado a `/me`.
- **`stores`**
  - Campos: `id`, `owner_user_id`, `name`, `slug`, `logo_url`, `description`, `city`, `whatsapp_phone`, `delivery_options` (jsonb), `is_featured`, `created_at`.
  - `status` puede ser `pending`, `approved` o `suspended`.
- **`categories`**
  - Campos: `id`, `parent_id`, `name`, `slug`, `icon`, `sort`.
  - Semilla: Aviones RC, Maquetas/Estáticos, Helicópteros, Drones, Autos RC, Barcos, Trenes, Electrónica y Baterías, Pinturas y Herramientas, Accesorios.
- **`products`**
  - Campos: `id`, `seller_user_id`, `store_id` (null si es particular), `category_id`, `title`, `description`, `price_bob`, `stock`, `city`, `created_at`, `updated_at`.
  - `condition` puede ser `new` o `used`.
  - `status` puede ser `active`, `paused`, `sold` o `removed`.
- **`product_images`**: `id`, `product_id`, `url`, `thumb_url`, `sort`. Máximo 5 por producto.
- **`favorites`**: `user_id`, `product_id`.
- **`cart_items`**: `user_id`, `product_id`, `qty`. Va en el servidor para que el carrito sirva en varios dispositivos.
- **`orders`**
  - Campos: `id`, `buyer_user_id`, `seller_user_id`, `store_id`, `total_bob`, `note`, `created_at`.
  - `status` puede ser `pending`, `contacted`, `confirmed`, `completed` o `cancelled`.
- **`order_items`**: `order_id`, `product_id`, `title_snap`, `price_snap`, `qty`.
- **`banners`**: carrusel de eventos, festivales y avisos. Campos: `id`, `title`, `image_url`, `link_url`, `starts_at`, `ends_at`, `sort`, `active`.
- **`auth_cache`**: `token_hash`, `phone`, `expires_at`.

---

## Fases (cada una se puede probar en un dispositivo real)

### Fase 0: Fundaciones (sin UI nueva)
1. Mover `.git` de `app_hobbystore/` a la raíz y ajustar `.gitignore` (build/, pictures/, config.local.php). Commit "chore: monorepo".
   - Crear la rama `develop`, la protección de `main` en GitHub, `CHANGELOG.md` y la tabla `schema_migrations`.
   - Escribir `deploy.sh` y `migrate.sh` con sus validaciones de rama y entorno.
   - Crear los schemas `hobbystore` y `hobbystore_staging`.
2. Crear `docs/PROGRESS.md`, `DECISIONS.md`, `ARCHITECTURE.md` y el `CLAUDE.md` raíz.
3. Copiar `otp_auth` a `packages/`.
4. `infra/docker-compose.dev.yml` con Postgres 18, y `backend_api/sql/001_schema.sql`.
5. **Flamenco (primera escritura, la confirmo contigo antes):**
   - `CREATE SCHEMA hobbystore` en `gyros`.
   - Aplicar el schema.
   - Subir `backend_api` con `GET /health` para verificar PHP, PDO y el schema.
   - Probar si `mod_rewrite` funciona; si no, usar `index.php/ruta` con PATH_INFO.
6. Script `backend_api/deploy.sh` (rsync con excludes) y `sql/backup.sh` (`pg_dump -n hobbystore`).

### Fase 1: Login + esqueleto de la app
- `main.dart` entra por `StartupScreen(auth: OtpAuth(...))` → `HomeShell` con las tabs Inicio, Categorías, Favoritos, Carrito y Perfil.
- `AppConfig` con `--dart-define`:
  - `OTP_BASE_URL`: `mock` o producción, igual que en celulares.
  - `API_BASE_URL`.
- `ApiClient` que agrega `X-Session-Token` a cada request.
- Endpoint `GET /me`: valida el token y hace upsert del usuario. `PATCH /me`: nombre y ciudad.
- Tema propio (color semilla rojo hobby, como la referencia de Horizon Hobby) y nombre de app, bundle id e ícono provisorios.

### Fase 2: Catálogo (solo lectura) + Home
- **Home:**
  - `CarouselView` de banners.
  - Fila horizontal de logos de tiendas destacadas.
  - Grilla de "Novedades".
- Categorías → grilla de productos paginada. Tarjeta: foto, ♥, precio en Bs, título y badge "Usado"/"Tienda".
- Detalle de producto: galería, precio, descripción, vendedor con ciudad y opciones de entrega, y los botones "Añadir al carrito" y "Consultar por WhatsApp".
- Búsqueda por texto (`ILIKE` en el MVP).
- Página de tienda: logo, datos y productos.
- Semilla: `sql/010_seed_demo.sql` + imágenes de `pictures/hobby/*` subidas a `media/`.
- Endpoints:
  - `GET /banners`, `/stores?featured=1`, `/stores/{slug}`
  - `GET /categories`, `/products?category=&q=&store=&page=`, `/products/{id}`

### Fase 3: Favoritos + Carrito
- `POST/DELETE /favorites/{productId}`, `GET /favorites`
- `GET /cart`, `PUT /cart/{productId}` (qty), `DELETE /cart/{productId}`
- Carrito agrupado por vendedor, con subtotal de cada uno.

### Fase 4: Pedido → WhatsApp
- "Enviar pedido a {vendedor}" llama a `POST /orders`, que crea el pedido `pending` y vacía esos ítems del carrito.
- Luego se abre `https://wa.me/591XXXXXXXX?text=` con el pedido #, los ítems, el total y el nombre del comprador.
- Pantallas:
  - "Mis compras" para el comprador.
  - "Pedidos recibidos" para el vendedor, que cambia el estado: contactado, confirmado, completado o cancelado.

### Fase 5: Vender (particulares)
- Publicar: fotos (1 a 5), título, categoría, precio, estado, descripción y stock.
- `POST /products` + `POST /products/{id}/images` (multipart; el servidor valida el MIME y genera el thumb).
- Límite de 5 publicaciones activas para particulares.
- "Mis publicaciones": editar, pausar, marcar vendido, eliminar.
- `.user.ini`: `upload_max_filesize=8M`, `post_max_size=12M`.

### Fase 6: Tiendas + Admin
- "Quiero ser tienda": formulario con nombre, logo, ciudad, WhatsApp y entrega. Crea la tienda en `pending`.
- Tienda aprobada: publica sin límite como tienda y aparece en el Home si `is_featured`.
- Sección Admin en la app (solo para `is_admin`):
  - Aprobar o suspender tiendas y marcarlas como destacadas.
  - CRUD de banners.
  - Retirar productos.

### Fase 7: Publicación en tiendas
- Ícono, splash, nombre final y bundle id definitivo (p.ej. `com.quanticasoft.hobbystore`), firma Android y perfiles iOS.
- **Requisitos de Apple y Google:**
  - Política de privacidad (URL en quanticasoft.com).
  - **Borrar cuenta desde la app**, que Apple exige; se hace con soft delete en `users.deleted_at`.
  - **Número demo para los revisores**, que no pueden recibir SMS de Bolivia. Se configura en el gateway OTP con un código fijo y solo para ese número; esto se hace en celulares-platform y se coordina aparte.
- Distribución: Play Console en pista de pruebas internas, luego TestFlight, luego producción.

### Después del MVP (congelado)
- Pago QR o pasarela.
- Reseñas y rating.
- Push notifications.
- Chat interno.
- Búsqueda full-text.
- Web.
- Envíos con tarifa.

---

## Memoria de avance: `docs/PROGRESS.md`

Es la fuente de verdad para saber "dónde quedamos". Se actualiza al cerrar cada tarea, en el mismo commit.

```
# Hobby Store: Progreso
Última actualización: AAAA-MM-DD · Fase actual: N

## Dónde quedamos
- (1 a 3 líneas: qué se hizo en la última sesión y cuál es el siguiente paso concreto)

## Estado por fase
| Fase | Estado | Notas |
| 0 Fundaciones | ✅ / 🔄 / ⏳ | ... |

## Features
### ✅ Hecho   ### 🔄 En proceso   ### ⏳ Pendiente   ### 🧊 Postergado (post-MVP)

## Bloqueos / preguntas abiertas
## Entornos
- Dev: API http://localhost:8080 · PG docker :5433 · OTP mock
- Staging: .../hobbystore/api-staging · schema gyros.hobbystore_staging · rama develop
- Prod: https://www.quanticasoft.com/hobbystore/api · schema gyros.hobbystore · tag en main

## Versiones
| Versión | Fecha | Entorno | Notas |
```

Complementos:
- `docs/DECISIONS.md` guarda el porqué de cada decisión.
- Git (commits por fase o feature y tags `v0.N-faseN`) guarda la historia.
- Guardaré en mi memoria persistente las restricciones de flamenco y un puntero a PROGRESS.md.

---

## Recursos necesarios

| Recurso | Estado | Costo |
|---|---|---|
| flamenco (PHP 8.2 + PG18, rsync/SSH) | ✅ Existe | — |
| Raspberry Pi + gateway OTP + smsbridge | ✅ Existe | SIM Entel (SMS) |
| GitHub `QuanticaSoft/hobbystore` | ✅ Existe | — |
| Mac con Xcode + Android Studio, Docker Desktop | Verificar | — |
| Teléfono Android + iPhone de prueba | Verificar | — |
| Cuenta Google Play Console | ⏳ | USD 25, pago único |
| Apple Developer Program | ⏳ | USD 99 al año |
| WhatsApp | Links `wa.me`; no requiere la Business API | Gratis |
| Contenido: logos de tiendas, banners, fotos | Parcial (`pictures/`) | — |
| Política de privacidad + términos | ⏳ (Fase 7) | — |

---

## Archivos críticos a reutilizar
- `celulares-platform/packages/otp_auth/lib/otp_auth.dart`: `OtpAuth`, `StartupScreen`, `HttpOtpService`, `MockOtpService`, `SecureSessionStore`.
- `celulares-platform/app_flutter/lib/config/app_config.dart`: patrón `--dart-define` con `mock`.
- `celulares-platform/app_image/lib/services/number_upload_service.dart`: patrón de subida multipart + mock.
- `celulares-platform/backend_flamenco/otp/lib/{Response,Validation,RateLimiter}.php`: base del estilo de la API PHP.
- `celulares-platform/backend_flamenco/otp/.htaccess`: patrón para bloquear config y datos.

## Verificación (por fase)
- **F0:** `curl https://www.quanticasoft.com/hobbystore/api/health` responde `{db:"ok", schema:"hobbystore"}`. Además, `psql -d gyros -c "\dn"` muestra `hobbystore` y las tablas de `public` no cambian (conteo antes y después).
- **F1:** `flutter run` en Android e iOS con `OTP_BASE_URL=mock`, y luego contra producción con un SMS real. `/me` crea el usuario. `flutter analyze` y `flutter test` en verde.
- **F2 a F6:** smoke test manual en el dispositivo siguiendo el checklist de la fase (queda en PROGRESS.md) + `curl` a cada endpoint nuevo + widget tests de las pantallas principales. Evitar `pumpAndSettle` en las pantallas OTP (tienen un timer).
- **F4:** el pedido aparece en "Mis compras" y en "Pedidos recibidos", y WhatsApp se abre con el texto correcto.
- **F7:** build de release instalada desde la pista interna de Play y desde TestFlight.

## Siguiente paso tras aprobar
Ejecutar **solo la Fase 0**, confirmando contigo antes de la primera escritura en flamenco (CREATE SCHEMA). Luego probamos y pasamos a la Fase 1.

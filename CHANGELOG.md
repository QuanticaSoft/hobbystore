# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y [SemVer](https://semver.org/lang/es/).

## [Unreleased]

## [0.5.0] - 2026-10-02
Fase 5: vender (publicaciones de particulares).

### Added
- BD: migración `005_seller_products` (índice por vendedor).
- API: `/v1/my/products` (listar, crear pausada, editar, cambiar estado, baja lógica) y fotos (`POST/DELETE .../images`) con validación, orientación EXIF, miniatura y **sin metadatos GPS**. Límite de 5 activas para particulares.
- App: "Vender" en el Inicio y Perfil › "Mis publicaciones" (contador de activas, publicar, pausar, marcar vendida, editar, eliminar).
- App: formulario con fotos (galería o cámara, hasta 5, reducidas en el teléfono), categoría, precio (acepta "1.250", "1250,50" y "12.5"), unidades, nuevo o usado y descripción.
- Dependencia: `image_picker`. iOS: textos de permiso de fotos y cámara.
- PHP: límite de subida de 8 MB (`.user.ini` en flamenco, `uploads.ini` en Docker).

### Fixed
- App: el desplegable de categoría desbordaba con nombres largos en pantallas angostas.

## [0.4.0] - 2026-10-02
Fase 4: pedidos por WhatsApp.

### Added
- BD: migración `004_orders` (`orders` + `order_items`, con fotos de título y precio).
- API: `POST /v1/orders` (desde un grupo del carrito, con nota opcional, devuelve el enlace de WhatsApp), `GET /v1/orders?role=buyer|seller` y `PATCH /v1/orders/{id}` con transiciones validadas por rol.
- App: "Pedir a <vendedor>" en el carrito, con nota opcional, que abre WhatsApp con el pedido detallado.
- App: Perfil › "Mis compras" y "Pedidos recibidos": estado, productos, total, "Escribir por WhatsApp" y cambio de estado.
- Dependencia: `url_launcher`.

## [0.3.0] - 2026-10-02
Fase 3: favoritos y carrito.

### Added
- BD: migración `003_favorites_cart`.
- API: `/v1/favorites` (GET, PUT, DELETE) y `/v1/cart` (GET, PUT con cantidad, DELETE), con sesión. El carrito se agrupa por vendedor y valida stock, cantidad y producto propio.
- App: ♥ en las tarjetas y en el detalle (optimista, vuelve atrás si falla) y tab Favoritos.
- App: "Añadir al carrito" en el detalle (respeta el stock), tab Carrito agrupada por vendedor con + / −, subtotales, y contador en la barra de navegación.
- App: `AppProviders` comparte el árbol de providers entre la app y los tests.

## [0.2.0] - 2026-10-01
Fase 2: catálogo y Home.

### Added
- API: `/v1/home`, `/v1/categories`, `/v1/products` (filtros, búsqueda y paginación), `/v1/products/{id}` y `/v1/stores/{slug}`.
- BD: migración `002_catalog` (categorías, tiendas, productos, imágenes y banners), con 12 categorías.
- Demo: `scripts/seed.sh dev|staging` con 3 tiendas, 20 productos y 4 banners.
- App: Home con buscador, carrusel de banners, tiendas destacadas y novedades.
- App: tab Categorías, listado con scroll infinito, búsqueda, detalle de producto (galería, vendedor, entrega) y página de tienda.
- App: "Cerrar sesión" pide confirmación y explica que para salir basta con cerrar la app.

### Fixed
- App: pantalla roja (`ProviderNotFoundException`) al abrir un producto, una tienda o un listado. Los providers estaban dentro de la ruta del Home y las pantallas nuevas son rutas hermanas; ahora viven por encima de `MaterialApp`.

## [0.1.0] - 2026-09-30
Fase 1: login y esqueleto de la app.

### Added
- App: login OTP (`otp_auth`) → shell con 5 tabs (Inicio, Categorías, Favoritos, Carrito, Perfil).
- App: perfil editable (nombre y ciudad), aviso para completar el perfil y cierre de sesión.
- App: `AppConfig` por entorno (`--dart-define=ENV=dev|staging|prod`) y `ApiClient` con `X-Session-Token`.
- API: `GET /v1/me` y `PATCH /v1/me`, con validación de sesión contra el OTP y caché en `auth_cache`.

### Changed
- App: ids `com.quanticasoft.hobbystore`, nombre "Hobby Store", iOS mínimo 15.0.
- Flutter 3.47.5 (corrige el build para simulador iOS con Xcode 27).

## [0.0.1] - 2026-09-30
Fase 0: fundaciones.

### Added
- Estructura monorepo: `app_hobbystore/`, `packages/otp_auth/`, `backend_api/`, `infra/`, `docs/`.
- API PHP mínima con `/v1/health` y `/v1/config`.
- Migraciones SQL versionadas (`001_users_auth`) y scripts `migrate`, `deploy` y `backup`.
- Entorno dev en Docker (Postgres 18 + PHP 8.2).
- Despliegue en flamenco: staging (`api-staging`, schema `hobbystore_staging`) y prod (`api`, schema `hobbystore`).

### Fixed
- La API conecta a Postgres por TCP porque SELinux bloquea el socket desde PHP-FPM.
- Scripts: conexión SSH reutilizada y validación de archivos no trackeados solo en `backend_api/`.

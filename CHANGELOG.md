# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y [SemVer](https://semver.org/lang/es/).

## [Unreleased]
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

# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y [SemVer](https://semver.org/lang/es/).

## [Unreleased]

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

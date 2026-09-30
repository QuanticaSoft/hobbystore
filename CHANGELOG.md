# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y [SemVer](https://semver.org/lang/es/).

## [Unreleased]
### Added
- Estructura monorepo: `app_hobbystore/`, `packages/otp_auth/`, `backend_api/`, `infra/`, `docs/`.
- API PHP mínima con `/v1/health` y `/v1/config`.
- Migraciones SQL versionadas (`001_users_auth`) y scripts `migrate`, `deploy` y `backup`.
- Entorno dev en Docker (Postgres 18 + PHP 8.2).

# Hobby Store: instrucciones del proyecto

Marketplace móvil (Flutter, Android/iOS) de productos de hobby. El plan del MVP está en `docs/PLAN.md` y el estado actual en `docs/PROGRESS.md`; **leerlo al empezar cada sesión** y actualizarlo al cerrar cada tarea, en el mismo commit.

## Estructura
- `app_hobbystore/`: app Flutter, organizada por feature (`lib/core`, `lib/features/<feature>`).
- `packages/otp_auth/`: login OTP. Es una copia de `celulares-platform/packages/otp_auth` (ver `docs/DECISIONS.md`).
- `backend_api/`: API PHP 8.2 plano + PDO, sin composer. Las migraciones van en `backend_api/sql/NNN_*.sql` y son inmutables una vez aplicadas.
- `infra/`: entorno dev local (Postgres + PHP en Docker).
- `docs/`: PROGRESS, DECISIONS, ARCHITECTURE, API.

## Reglas duras (flamenco)
- **Sin sudo.** Nada de docker, systemd ni paquetes del sistema en flamenco.
- La BD de producción es `gyros`, que es la de **otra app en producción**. Hobby Store vive **solo** en los schemas `hobbystore` (prod) y `hobbystore_staging`.
  - Nunca crear, alterar ni borrar nada en `public` ni en ningún otro schema.
  - Toda conexión fija `search_path` a su schema.
- El PHP corre en el pool compartido `gyros.sock` como el usuario `marco`.
- El código va fuera del docroot, en `~/hobbystore/<env>/`. En `/webs/quanticasoft/hobbystore/` solo está lo público.
- La Raspberry Pi (`nas-meteo`) es **solo** el gateway SMS/OTP. No se toca desde este proyecto, igual que el proceso `meteo`.
- Cualquier escritura en flamenco (deploy, migración, schema) se confirma con el usuario antes.

## Flujo de trabajo
- Ramas: `main` (prod, solo por PR + tag), `develop` (staging), `feature/fN-nombre`, `fix/*`, `hotfix/X.Y.Z`.
- Commits con Conventional Commits: `feat(scope): descripción en español`.
- Versionado: `pubspec.yaml` usa `0.N.x+BUILD`, con N = fase terminada. BUILD siempre crece.
- La API se expone con prefijo `/v1`.

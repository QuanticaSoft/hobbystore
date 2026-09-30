# Hobby Store

Marketplace móvil (Android e iOS) de productos de hobby: aeromodelismo RC y estático, autos, barcos, drones y accesorios.

- **Plan del MVP:** [`docs/PLAN.md`](docs/PLAN.md)
- **Estado y próximos pasos:** [`docs/PROGRESS.md`](docs/PROGRESS.md)
- **Arquitectura y entornos:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- **Decisiones:** [`docs/DECISIONS.md`](docs/DECISIONS.md)
- **API:** [`docs/API.md`](docs/API.md)

## Dev local

```bash
docker compose -f infra/docker-compose.dev.yml up -d   # Postgres :5433 + API :8080
backend_api/scripts/migrate.sh dev
curl localhost:8080/v1/health

cd app_hobbystore && flutter run
```

## Ramas y versiones
- `main` = producción (solo por PR + tag `vX.Y.Z`).
- `develop` = staging.
- `feature/fN-nombre` = trabajo diario.
- Detalle en `CLAUDE.md`.

# Hobby Store: Progreso

Última actualización: 2026-10-02 · Fase actual: **6: Tiendas + Admin** (en revisión)

## Dónde quedamos
- **Fase 5 cerrada: release `v0.5.0`** (2026-10-02).
  - El usuario la probó en su teléfono con `ENV=staging`: publicar con galería y cámara, editar, pausar, vender y eliminar.
- **Fase 6 programada y probada en local** (rama `feature/f6-tiendas-admin`, PR hacia `develop`).
  - Después del merge:
    1. `migrate.sh staging` (006) y `deploy.sh staging`.
    2. Marcar admin el número del usuario en staging (solo en la BD).
    3. Probar en el dispositivo, incluidos "Pedidos recibidos" con una tienda de dueño real (pendiente desde la Fase 4).
    4. Release `v0.6.0` (en prod también se marca el admin).
  - Staging: Garage RC apunta a un WhatsApp real de prueba (solo en la BD).

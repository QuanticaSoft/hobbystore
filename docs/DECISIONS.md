# Decisiones

Formato: fecha, decisión y por qué. Las decisiones nuevas van arriba.

## 2026-09-30: Código PHP fuera del docroot
En flamenco el código va en `~/hobbystore/<env>/` y en `/webs/quanticasoft/hobbystore/<api|api-staging>/` solo se publica `public/`.
**Por qué:** el pool PHP-FPM corre como `marco` y puede leer su home. Así `src/` y `config.local.php` nunca quedan expuestos, aunque un `.htaccess` falle.

## 2026-09-30: Dev local con PHP y Postgres en Docker
**Por qué:** el Mac no tiene `php` ni `psql`. Docker da paridad con prod (PHP 8.2 + pdo_pgsql, Postgres 18) sin instalar nada en el sistema.

## 2026-09-30: `otp_auth` copiado al repo
Se copió desde `celulares-platform/packages/otp_auth` (commit `72d4c03`).
**Por qué:** un `path:` hacia otro repo rompe clones y CI. Si el original cambia, se sincroniza a mano y se anota aquí.

## 2026-09-30: BD en schemas dentro de `gyros`
Se usan `gyros.hobbystore` (prod) y `gyros.hobbystore_staging`.
**Por qué:** el rol `marco` no tiene `CREATEDB` ni hay sudo; `marco` es dueño de `gyros`. El aislamiento se logra con schemas + `search_path`, y los backups se hacen con `pg_dump -n <schema>`.
**Riesgo aceptado:** comparte instancia y BD con gyros. Regla dura: nunca tocar `public`.

## 2026-09-30: Validación de sesión delegada al OTP existente
La API recibe `X-Session-Token`, lo valida contra `https://www.quanticasoft.com/otp/session.php`, que responde `{status, phone}`, y guarda el resultado en caché (`auth_cache`, 10 min).
**Por qué:** se reutiliza el login ya en producción sin duplicar lógica OTP, y la caché evita cargar la Raspberry Pi. No se usa `Authorization` porque PHP-FPM no lo reenvía sin `CGIPassAuth`.

## 2026-09-30: Compra por WhatsApp con pedido registrado
El carrito se agrupa por vendedor → se crea un pedido `pending` → se abre `wa.me` con el detalle. El pago y la entrega se acuerdan fuera de la app.
**Por qué:** el MVP no necesita pasarela de pago ni logística, y aun así queda trazabilidad de pedidos.

## 2026-09-30: Vendedores
Todos pueden vender. Los particulares tienen un máximo de 5 publicaciones activas; las tiendas aprobadas por el admin no tienen límite y pueden salir destacadas en el Home. La entrega es solo informativa por vendedor.

## 2026-09-30: Stack de la app
Estado con `ChangeNotifier` + `provider` y navegación con `Navigator` imperativo, compatible con `otp_auth`. El carrusel usa `CarouselView` de Material, sin dependencia extra.

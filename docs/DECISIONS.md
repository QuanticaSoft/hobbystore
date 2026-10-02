# Decisiones

Formato: fecha, decisión y por qué. Las decisiones nuevas van arriba.

## 2026-10-02: Publicar = crear pausada → subir fotos → activar
Las fotos se suben de a una (`POST .../images`) y la publicación recién se activa al final.
**Por qué:** nunca aparece en el catálogo un producto sin fotos o a medio subir. Si una foto falla, la publicación queda pausada y la app reintenta solo lo que faltó, sin duplicarla. Una foto por request también mantiene cada request chico (la app las reduce a 1600 px y calidad 80, ~0,5 MB) y permite mostrar el progreso.

## 2026-10-02: Las fotos subidas se re-codifican con GD
Se valida el tipo real (finfo + getimagesize), se endereza según la orientación EXIF, se redimensiona a 1200 px + miniatura de 400 px, y se guarda como JPEG en `media/u/AAAA/MM/<aleatorio>.jpg`.
**Por qué:** solo se sirve una imagen válida (un archivo disfrazado no sobrevive a la re-codificación) y **se descartan los metadatos EXIF, incluida la ubicación GPS** que muchos celulares guardan en las fotos. El directorio de media no ejecuta PHP ni lista su contenido (`.htaccess`).

## 2026-10-02: Límite y bajas de publicaciones
- Particulares: hasta 5 activas. Pausadas y vendidas no cuentan. Las tiendas no tendrán tope (Fase 6).
- Eliminar es una baja lógica (`removed`): los pedidos que ya apuntan al producto siguen siendo consistentes. Las fotos de una publicación eliminada no se borran del disco (se podría limpiar más adelante con una tarea programada).
- Publicar exige nombre y ciudad en el perfil; la ciudad del producto es la del vendedor.

## 2026-10-02: Pedidos por WhatsApp: el mensaje lo arma el servidor
`POST /v1/orders` registra el pedido (con fotos de título y precio), quita el grupo del carrito y devuelve el enlace `wa.me` con el mensaje completo. La app solo abre ese enlace.
**Por qué:** el número de pedido, el formato y el número del vendedor quedan en un solo lugar y son iguales en todas las versiones de la app.
- **Particulares:** se usa su celular verificado por OTP (decisión del usuario): ya está comprobado que es suyo y no hay que pedir otro dato.
- **Stock:** no se descuenta al crear el pedido. La venta se cierra por WhatsApp y el vendedor actualiza el stock (Fase 5). Sí se valida que la cantidad no supere el stock.
- **Nombre del comprador:** es obligatorio para pedir, para que el vendedor sepa con quién habla.
- Se abre con `launchUrl(..., externalApplication)` sin `canLaunchUrl`, así que no hace falta declarar esquemas en Android ni en iOS. Si no se abre, el pedido igual queda en "Mis compras".

## 2026-10-01: Estado de sesión por encima de MaterialApp
`ApiClient`, `UserSession` y `CatalogRepository` se proveen por encima de `MaterialApp`, con un solo `ApiClient` para toda la app. Al entrar, `homeBuilder` fija `api.currentPhone`; al cerrar sesión se limpia todo **después** de navegar al login.
**Por qué:** las pantallas que se abren con `Navigator.push` son rutas hermanas del Home, no hijas. Con los providers dentro del Home no los encontraban (pantalla roja en el iPhone).

## 2026-10-01: Sin botón "Salir de la app"
No se agrega. En iOS cerrar la app desde código va contra las guías de Apple y puede causar el rechazo en la revisión; en Android tampoco es la norma. La sesión se guarda en el llavero (Keychain/Keystore): al reabrir la app se entra directo, sin código. "Cerrar sesión" sirve para cambiar de cuenta, pide confirmación y avisa que hará falta un código SMS nuevo.

## 2026-10-01: Prod se publica sin catálogo
La `v0.2.0` sale a prod con el Home vacío: sin tiendas, productos ni banners. Las primeras tiendas reales entran con la Fase 6 (alta y aprobación de tiendas).
**Por qué:** decisión del usuario. Prod nunca lleva datos de demo, y cargar tiendas reales a mano antes de tener el flujo de alta sería trabajo descartable.

## 2026-10-01: Catálogo público, sin sesión
`/v1/home`, `/v1/categories`, `/v1/products` y `/v1/stores` no piden token.
**Por qué:** es información pública de vitrina. Así se podrá usar desde una web o un enlace compartido sin rehacer la API. Lo que es del usuario (favoritos, carrito, pedidos) sí pedirá sesión.

## 2026-10-01: Media fuera del directorio de la API
La BD guarda rutas relativas (`seed/products/x.jpg`) y la API arma la URL con `media_base_url`.
- En flamenco, la media vive en `/webs/quanticasoft/hobbystore/media` (prod) y `/media-staging`.
- En dev, la URL se deriva del request (sirve igual para localhost y para 10.0.2.2 del emulador) y los archivos están en `backend_api/public/media/`, fuera de git.

**Por qué:** `deploy.sh` hace `rsync --delete` de `public/`; si la media estuviera adentro, se borraría en cada deploy.

## 2026-10-01: Datos de demostración separados de las migraciones
`seeds/demo.sql` + `seeds/media-manifest.txt`, cargados con `scripts/seed.sh dev|staging`. El script se niega a correr en prod.
- Las fotos de productos son de terceros y el repo es público: no se versionan. El script las toma de `pictures/` (local) y las redimensiona con `sips`.
- Los logos de las tiendas de demo son propios (generados) y sí se versionan.
- Las categorías no son demo: viven en la migración `002_catalog.sql`.
- La demo es idempotente: se identifica por los teléfonos `+591600000XX` y las rutas `seed/`.

**Por qué:** prod debe arrancar sin tiendas falsas, y staging necesita datos realistas para probar.

## 2026-10-01: Búsqueda con ILIKE
Para el MVP alcanza con `ILIKE` sobre título y descripción, escapando `%`, `_` y `!` (con `!` como carácter de escape). Si el catálogo crece, se pasa a full-text de Postgres (`tsvector` + índice GIN).

## 2026-09-30: Ids de la app y versión mínima de iOS
- Android `applicationId` e iOS bundle id: `com.quanticasoft.hobbystore`. Nombre visible: "Hobby Store".
- iOS mínimo 15.0, porque Xcode 27 no acepta un deployment target menor.
- HTTP sin TLS solo para dev: en Android, `usesCleartextTraffic` en el manifest de **debug**; en iOS, `NSAllowsLocalNetworking` (solo red local).

## 2026-09-30: Header `X-Dev-Phone` en dev
**Por qué:** con OTP mock en la app, el token no existe en ningún servidor y la API dev no tiene contra qué validarlo. La app envía el teléfono del login mock y la API lo acepta solo si `otp_session_url = mock` **y** `env = dev`; en cualquier otro caso lanza un error.

## 2026-09-30: Usuario creado en el primer `GET /v1/me`
El registro es el propio OTP: la API hace upsert por teléfono. `is_new` indica si recién se creó.

## 2026-09-30: La API conecta a Postgres por TCP con password
PHP-FPM no puede usar el socket Unix (`/run/postgresql`) porque SELinux, en modo Enforcing, devuelve "Permission denied". Por TCP en `127.0.0.1` sí se puede, pero exige password. El password del rol `marco` va solo en `~/hobbystore/<env>/config.local.php` (chmod 600) y nunca en git.
Los scripts (`migrate`, `backup`) corren por SSH como `marco` y sí usan el socket.

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

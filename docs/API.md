# API Hobby Store (v1)

- Base: ver "Entornos" en `docs/PROGRESS.md`.
- Todas las respuestas son JSON. Un error tiene la forma `{"status":"error","message":"..."}` con el código HTTP correspondiente.
- Imágenes: la API devuelve URLs absolutas (`*_url`). En dev se derivan del host del request; en flamenco salen de `media_base_url`.
- Autenticación: header `X-Session-Token: <token de otp_auth>`.
  - La API lo valida contra `otp/session.php` y guarda en caché el resultado 10 min (`auth_cache`).
  - Sin token, o con un token inválido o expirado, responde 401. Si no puede consultar al OTP, responde 503.
  - **Solo en dev** (`otp_session_url = mock`): el servidor no puede validar tokens del `MockOtpService`, así que confía en el header `X-Dev-Phone: +591XXXXXXXX`. Con `env` distinto de `dev`, el modo mock se rechaza.

| Método | Ruta | Auth | Respuesta |
|---|---|---|---|
| GET | `/v1/health` | no | `{status, env, api_version, db, schema, last_migration}` · 503 si la BD falla |
| GET | `/v1/config` | no | `{min_app_version}`: si la app es menor, debe pedir actualizar |
| GET | `/v1/me` | sí | `{user: {id, phone, display_name, city, is_admin, created_at}, is_new}`. Crea el usuario en su primer request |
| PATCH | `/v1/me` | sí | Body `{display_name?, city?}` (máximo 60 caracteres; `""` o `null` borran el valor) → `{user}`. 400 con `message` si un campo es inválido o el body viene vacío |
| GET | `/v1/home` | no | `{banners: [{id, title, image_url, link_url}], featured_stores: [store], latest_products: [product]}` (10 productos más recientes) |
| GET | `/v1/categories` | no | `{categories: [{id, slug, name, product_count}]}` |
| GET | `/v1/products` | no | Query opcional: `category` (slug), `store` (slug), `q` (texto, máximo 80 caracteres), `page` (desde 1). Responde `{items: [product], page, has_more}`, 20 por página, de más nuevo a más viejo |
| GET | `/v1/products/{id}` | no | `{product: {id, title, description, price_bob, condition, stock, city, created_at, category: {slug, name}, images: [{url, thumb_url}], seller: {type: store\|user, name, city, store_slug, logo_url, delivery_options}}}` · 404 si no existe o no está visible |
| GET | `/v1/stores/{slug}` | no | `{store: {slug, name, city, logo_url, description, delivery_options, product_count}}` · 404 si no existe o no está aprobada |
| GET | `/v1/favorites` | sí | `{items: [product]}`: solo productos visibles, del favorito más reciente al más antiguo |
| PUT | `/v1/favorites/{id}` | sí | Agrega (idempotente) → `{product_id, favorite: true}` · 404 si el producto no está visible |
| DELETE | `/v1/favorites/{id}` | sí | Quita (idempotente) → `{product_id, favorite: false}` |
| GET | `/v1/cart` | sí | `{cart}` (ver abajo) |
| PUT | `/v1/cart/{id}` | sí | Body `{qty}` (1 a 99): fija la cantidad → `{cart}` · 400 si la cantidad es inválida o el producto es propio · 409 si supera el stock · 404 si no está visible |
| DELETE | `/v1/cart/{id}` | sí | Quita la línea → `{cart}` |

**Formas comunes**
- `product` (resumen): `{id, title, price_bob, condition: new|used, city, thumb_url, seller_name, store_slug}`
- `store` (resumen): `{slug, name, city, logo_url}`
- `delivery_options`: subconjunto de `pickup` (retiro en tienda), `local` (envío en la ciudad) y `national` (encomienda).
- **Visibilidad:** solo se listan productos `active` de particulares o de tiendas `approved`.
- `cart`: `{groups: [{seller: {type, name, store_slug, city}, items: [product + {qty, stock, line_total_bob}], subtotal_bob}], item_count, total_bob}`.
  - Un grupo por vendedor (tienda o particular): cada uno será un pedido por WhatsApp.
  - Los montos se suman en centavos.
  - Los productos que dejaron de estar visibles no aparecen ni suman.

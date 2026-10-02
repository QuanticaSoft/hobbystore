-- "Mis publicaciones" lista por vendedor e incluye pausados y vendidos.
CREATE INDEX products_seller_idx ON products (seller_user_id, created_at DESC);

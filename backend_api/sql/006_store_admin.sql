-- Alta de tiendas por los usuarios y revisión del admin.

-- Una tienda por usuario: sus publicaciones pasan a ser de la tienda al aprobarla.
CREATE UNIQUE INDEX stores_owner_unique ON stores (owner_user_id);

ALTER TABLE stores
    ADD COLUMN review_note text,          -- motivo de una suspensión, visible al dueño
    ADD COLUMN updated_at  timestamptz NOT NULL DEFAULT now();

ALTER TABLE banners
    ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();

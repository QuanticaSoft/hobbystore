-- Catálogo: categorías, tiendas, productos con imágenes y banners del Home.
-- Las rutas de imágenes son relativas al directorio de media del entorno;
-- la API arma la URL pública con media_base_url.

CREATE TABLE categories (
    id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug  text    NOT NULL UNIQUE,
    name  text    NOT NULL,
    sort  integer NOT NULL
);

INSERT INTO categories (slug, name, sort) VALUES
    ('aviones-rc',          'Aviones RC',              10),
    ('helicopteros',        'Helicópteros',            20),
    ('drones',              'Drones',                  30),
    ('autos-rc',            'Autos y camiones RC',     40),
    ('barcos',              'Barcos',                  50),
    ('trenes',              'Trenes',                  60),
    ('maquetas',            'Maquetas y estáticos',    70),
    ('die-cast',            'Die-cast',                80),
    ('radios-electronica',  'Radios y electrónica',    90),
    ('baterias-cargadores', 'Baterías y cargadores',  100),
    ('pinturas-herramientas','Pinturas y herramientas',110),
    ('accesorios',          'Accesorios y repuestos', 120);

CREATE TABLE stores (
    id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_user_id    bigint      NOT NULL REFERENCES users (id),
    slug             text        NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    name             text        NOT NULL,
    logo_path        text,
    description      text,
    city             text        NOT NULL,
    whatsapp_phone   text        NOT NULL CHECK (whatsapp_phone ~ '^\+591\d{8}$'),
    -- Subconjunto de: pickup (retiro en tienda), local (envío en la ciudad), national (encomienda).
    delivery_options jsonb       NOT NULL DEFAULT '[]',
    status           text        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'suspended')),
    is_featured      boolean     NOT NULL DEFAULT false,
    created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE products (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_user_id bigint        NOT NULL REFERENCES users (id),
    store_id       bigint        REFERENCES stores (id),
    category_id    integer       NOT NULL REFERENCES categories (id),
    title          text          NOT NULL CHECK (length(title) BETWEEN 3 AND 120),
    description    text          NOT NULL DEFAULT '',
    price_bob      numeric(10,2) NOT NULL CHECK (price_bob > 0),
    condition      text          NOT NULL CHECK (condition IN ('new', 'used')),
    stock          integer       NOT NULL DEFAULT 1 CHECK (stock >= 0),
    city           text          NOT NULL,
    status         text          NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'sold', 'removed')),
    created_at     timestamptz   NOT NULL DEFAULT now(),
    updated_at     timestamptz   NOT NULL DEFAULT now()
);

CREATE INDEX products_active_recent_idx ON products (created_at DESC) WHERE status = 'active';
CREATE INDEX products_category_idx ON products (category_id) WHERE status = 'active';
CREATE INDEX products_store_idx ON products (store_id) WHERE status = 'active';

CREATE TABLE product_images (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id bigint  NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    path       text    NOT NULL,
    thumb_path text    NOT NULL,
    sort       integer NOT NULL DEFAULT 0,
    UNIQUE (product_id, sort)
);

CREATE TABLE banners (
    id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title      text        NOT NULL,
    image_path text        NOT NULL,
    link_url   text,
    starts_at  timestamptz,
    ends_at    timestamptz,
    sort       integer     NOT NULL DEFAULT 0,
    active     boolean     NOT NULL DEFAULT true
);

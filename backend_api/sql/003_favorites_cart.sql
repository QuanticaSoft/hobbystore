-- Favoritos y carrito por usuario. El carrito vive en el servidor para que se
-- conserve entre dispositivos y para armar los pedidos por vendedor (Fase 4).

CREATE TABLE favorites (
    user_id    bigint      NOT NULL REFERENCES users (id),
    product_id bigint      NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, product_id)
);

CREATE TABLE cart_items (
    user_id    bigint      NOT NULL REFERENCES users (id),
    product_id bigint      NOT NULL REFERENCES products (id) ON DELETE CASCADE,
    qty        integer     NOT NULL CHECK (qty BETWEEN 1 AND 99),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, product_id)
);

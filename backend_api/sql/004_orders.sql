-- Pedidos: uno por vendedor, creados desde el carrito. El pago y la entrega se
-- acuerdan por WhatsApp; aquí queda el registro y su estado.

CREATE TABLE orders (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    buyer_user_id  bigint        NOT NULL REFERENCES users (id),
    seller_user_id bigint        NOT NULL REFERENCES users (id),
    store_id       bigint        REFERENCES stores (id),
    status         text          NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'contacted', 'confirmed', 'completed', 'cancelled')),
    total_bob      numeric(12,2) NOT NULL CHECK (total_bob > 0),
    note           text,
    created_at     timestamptz   NOT NULL DEFAULT now(),
    updated_at     timestamptz   NOT NULL DEFAULT now()
);

CREATE INDEX orders_buyer_idx ON orders (buyer_user_id, created_at DESC);
CREATE INDEX orders_seller_idx ON orders (seller_user_id, created_at DESC);

-- Título y precio copiados al crear el pedido: si el vendedor edita o retira
-- el producto, el pedido sigue mostrando lo que se pidió.
CREATE TABLE order_items (
    order_id   bigint        NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    product_id bigint        REFERENCES products (id) ON DELETE SET NULL,
    title_snap text          NOT NULL,
    price_snap numeric(10,2) NOT NULL,
    qty        integer       NOT NULL CHECK (qty > 0)
);

CREATE INDEX order_items_order_idx ON order_items (order_id);

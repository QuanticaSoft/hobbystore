-- Usuarios de Hobby Store. La identidad (teléfono verificado) viene del OTP
-- existente; aquí solo guardamos el perfil propio del marketplace.
CREATE TABLE users (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    phone        text        NOT NULL UNIQUE CHECK (phone ~ '^\+591\d{8}$'),
    display_name text,
    city         text,
    is_admin     boolean     NOT NULL DEFAULT false,
    created_at   timestamptz NOT NULL DEFAULT now(),
    deleted_at   timestamptz
);

-- Evita consultar session.php (y la Raspberry Pi) en cada request.
CREATE TABLE auth_cache (
    token_hash text        PRIMARY KEY,
    phone      text        NOT NULL,
    expires_at timestamptz NOT NULL
);

CREATE INDEX auth_cache_expires_at_idx ON auth_cache (expires_at);

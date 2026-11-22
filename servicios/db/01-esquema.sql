-- Esquema de la base inventario (datos ficticios).
-- Se ejecuta solo la primera vez que arranca el contenedor db, con el volumen vacío.

CREATE TABLE servidores (
    id                serial PRIMARY KEY,
    nombre            text NOT NULL UNIQUE,
    rol               text NOT NULL,
    sistema_operativo text NOT NULL,
    entorno           text NOT NULL,
    responsable       text NOT NULL
);

-- Bitácora de respaldos. La carga un proceso nocturno de cada servidor.
CREATE TABLE respaldos (
    id         serial PRIMARY KEY,
    servidor   text,
    fecha      timestamp,
    tipo       text,          -- completo | incremental
    tamano_mb  numeric(10,1),
    estado     text           -- exitoso | fallido
);

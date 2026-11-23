-- Carga de datos (ficticios).

-- Inventario: el mismo CSV de docs/
COPY servidores (nombre, rol, sistema_operativo, entorno, responsable)
    FROM '/datos/inventario-servidores.csv' WITH (FORMAT csv, HEADER true);

-- Histórico de respaldos: cada 6 horas, de hace dos años a hace un mes
INSERT INTO respaldos (servidor, fecha, tipo, tamano_mb, estado)
SELECT s.nombre,
       d.dia + h.hora,
       CASE WHEN h.hora = time '02:00' AND extract(isodow FROM d.dia) = 7
            THEN 'completo' ELSE 'incremental' END,
       round((100 + (s.id * 431 + extract(doy FROM d.dia)::int * 7) % 900)::numeric, 1),
       CASE WHEN (s.id + extract(doy FROM d.dia)::int + extract(hour FROM h.hora)::int) % 53 = 0
            THEN 'fallido' ELSE 'exitoso' END
FROM servidores s
CROSS JOIN generate_series(current_date - 760, current_date - 31, interval '1 day') AS d(dia)
CROSS JOIN (VALUES (time '02:00'), (time '08:00'), (time '14:00'), (time '20:00')) AS h(hora)
WHERE s.nombre <> 'srv-web-qa-01'
ORDER BY 2, 1;

-- Último mes de respaldos. Las fechas se guardan como "días atrás" y se calculan
-- al crear la base, para que el laboratorio funcione cualquier día.
CREATE TEMP TABLE carga_respaldos (
    servidor   text,
    dias_atras int,
    hora       time,
    tipo       text,
    tamano_mb  numeric(10,1),
    estado     text
);
COPY carga_respaldos FROM '/docker-entrypoint-initdb.d/datos/respaldos.csv' WITH (FORMAT csv, HEADER true);

INSERT INTO respaldos (servidor, fecha, tipo, tamano_mb, estado)
SELECT servidor, current_date - dias_atras + hora, tipo, tamano_mb, estado
FROM carga_respaldos;

ANALYZE;

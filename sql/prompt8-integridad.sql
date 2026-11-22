-- Chequeo de integridad del Prompt 8 (Laboratorio 3). Una consulta por regla. Solo lectura.
-- Uso: docker compose exec -T db psql -U lector -d inventario < sql/prompt8-integridad.sql

-- Regla 1: duplicados (mismo servidor, fecha, tipo, tamaño y estado; solo cambia el id)
SELECT servidor, fecha, tipo, count(*) AS veces, array_agg(id ORDER BY id) AS ids
FROM respaldos
GROUP BY servidor, fecha, tipo, tamano_mb, estado
HAVING count(*) > 1
ORDER BY fecha;

-- Regla 2: valores nulos
SELECT count(*) FILTER (WHERE servidor IS NULL)  AS servidor_nulo,
       count(*) FILTER (WHERE fecha IS NULL)     AS fecha_nula,
       count(*) FILTER (WHERE tipo IS NULL)      AS tipo_nulo,
       count(*) FILTER (WHERE tamano_mb IS NULL) AS tamano_nulo,
       count(*) FILTER (WHERE estado IS NULL)    AS estado_nulo
FROM respaldos;

SELECT id, servidor, fecha, tipo, tamano_mb, estado
FROM respaldos
WHERE servidor IS NULL OR fecha IS NULL OR tipo IS NULL OR tamano_mb IS NULL OR estado IS NULL
ORDER BY fecha;

-- Regla 3: fechas en el futuro
SELECT id, servidor, fecha, tipo, estado
FROM respaldos
WHERE fecha > now()
ORDER BY fecha;

-- Regla 4: respaldos de servidores que no existen en el inventario
SELECT r.servidor, count(*) AS respaldos, min(r.fecha) AS primero, max(r.fecha) AS ultimo
FROM respaldos r
LEFT JOIN servidores s ON s.nombre = r.servidor
WHERE s.id IS NULL
GROUP BY r.servidor
ORDER BY r.servidor;

-- Resumen: cuántos registros falla cada regla
SELECT 'duplicados (filas de más)' AS regla,
       (SELECT coalesce(sum(n - 1), 0) FROM (
          SELECT count(*) AS n FROM respaldos
          GROUP BY servidor, fecha, tipo, tamano_mb, estado HAVING count(*) > 1) d) AS registros
UNION ALL
SELECT 'valores nulos', count(*) FROM respaldos
 WHERE servidor IS NULL OR fecha IS NULL OR tipo IS NULL OR tamano_mb IS NULL OR estado IS NULL
UNION ALL
SELECT 'fechas en el futuro', count(*) FROM respaldos WHERE fecha > now()
UNION ALL
SELECT 'servidor fuera del inventario', count(*) FROM respaldos r
 WHERE NOT EXISTS (SELECT 1 FROM servidores s WHERE s.nombre = r.servidor);

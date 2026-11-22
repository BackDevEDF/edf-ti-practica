-- Consultas de referencia del Prompt 7 (Laboratorio 3). Solo lectura.
-- Uso: docker compose exec -T db psql -U lector -d inventario < sql/prompt7-inventario.sql

-- 0) Describir las tablas
\d servidores
\d respaldos

-- 1) Servidores por sistema operativo
SELECT sistema_operativo, count(*) AS servidores
FROM servidores
GROUP BY sistema_operativo
ORDER BY servidores DESC, sistema_operativo;

-- 2) Servidores sin respaldo exitoso en los últimos 7 días.
--    LEFT JOIN para incluir a los que nunca tuvieron respaldo, y fecha <= now()
--    para que una fecha en el futuro no cuente como respaldo reciente.
SELECT s.nombre, max(r.fecha) AS ultimo_respaldo
FROM servidores s
LEFT JOIN respaldos r
       ON r.servidor = s.nombre
      AND r.estado = 'exitoso'
      AND r.fecha <= now()
GROUP BY s.nombre
HAVING max(r.fecha) IS NULL OR max(r.fecha) < now() - interval '7 days'
ORDER BY ultimo_respaldo NULLS FIRST;

-- 3) El respaldo más reciente de cada servidor (sin importar el estado)
SELECT DISTINCT ON (s.nombre)
       s.nombre, r.fecha, r.tipo, r.tamano_mb, r.estado
FROM servidores s
LEFT JOIN respaldos r ON r.servidor = s.nombre
ORDER BY s.nombre, r.fecha DESC NULLS LAST;

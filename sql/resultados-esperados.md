# Resultados esperados: Prompts 7 y 8 (Laboratorio 3)

Las fechas del último mes se calculan **el día en que se crea la base** (la primera vez que
arranca `db` con el volumen vacío). Estos resultados son de una base creada el
**2026-11-22**: con otra fecha de creación, las fechas se mueven igual, pero los conteos y los
servidores son los mismos. Si la base se creó hace más de 6 días, los servidores "sanos"
también aparecen sin respaldo reciente: recréala (lo hace una persona, no Claude):
`docker compose down -v && docker compose up -d`.

```bash
docker compose exec -T db psql -U lector -d inventario < sql/prompt7-inventario.sql
docker compose exec -T db psql -U lector -d inventario < sql/prompt8-integridad.sql
```

## Prompt 7

Tablas: `servidores` (10 filas, del CSV de `docs/`) y `respaldos` (27,292 filas: histórico
cada 6 horas desde hace 2 años y el último mes). `respaldos` no tiene llave foránea ni
`NOT NULL`, y solo tiene el índice de la llave primaria.

**1) Servidores por sistema operativo**
```
  sistema_operativo  | servidores
---------------------+------------
 RHEL 9.2            |          3
 Debian 12           |          2
 Ubuntu 22.04 LTS    |          2
 RHEL 8.8            |          1
 Ubuntu 20.04 LTS    |          1
 Windows Server 2022 |          1
```

**2) Servidores sin respaldo en los últimos 7 días: 3**
```
      nombre      |   ultimo_respaldo
------------------+---------------------
 srv-web-qa-01    |                         <- nunca tuvo respaldo
 srv-ad-01        | 2026-11-10 20:00:00     <- hace 12 días
 srv-monitoreo-01 | 2026-11-13 20:00:00     <- hace 9 días
```
- Con `JOIN` en lugar de `LEFT JOIN` salen 2: falta `srv-web-qa-01`, que no tiene ni un respaldo.
- Filtrar `estado = 'exitoso'` o no da el mismo resultado: el último respaldo de cada servidor sano fue exitoso.
- Sin `fecha <= now()` también da 3, porque las fechas en el futuro son de servidores sanos.

**3) Respaldo más reciente de cada servidor**
```
      nombre       |        fecha        |    tipo     | tamano_mb | estado
-------------------+---------------------+-------------+-----------+---------
 db-dev-01         | 2026-11-21 20:00:00 | incremental |     422.9 | exitoso
 db-prod-01        | 2026-12-22 02:00:00 | incremental |    3852.1 | exitoso   <- en el futuro
 srv-ad-01         | 2026-11-10 20:00:00 | incremental |     309.8 | exitoso
 srv-app-dev-01    | 2026-11-21 20:00:00 | incremental |      66.5 | exitoso
 srv-app-prod-01   | 2027-12-27 02:00:00 | incremental |     191.9 | exitoso   <- en el futuro
 srv-app-prod-02   | 2026-11-21 20:00:00 | incremental |     188.7 | exitoso
 srv-batch-prod-01 | 2026-11-21 20:00:00 | incremental |     138.7 | exitoso
 srv-monitoreo-01  | 2026-11-13 20:00:00 | incremental |     108.3 | exitoso
 srv-respaldos-01  | 2026-11-21 20:00:00 | incremental |      79.0 | exitoso
 srv-web-qa-01     |                     |             |           |
```
Dos "más recientes" están en el futuro: es la pista que lleva a la regla 3 del Prompt 8.

## Prompt 8: 4 reglas, las 4 fallan

| Regla | Registros | Ejemplos |
|---|---|---|
| Duplicados | 3 grupos, 3 filas de más | `srv-batch-prod-01` 2026-11-11 20:00 (ids 26994, 26995); `db-prod-01` 2026-11-18 08:00; `srv-app-prod-01` 2026-11-20 02:00 |
| Valores nulos | 4 | `estado` nulo: `srv-respaldos-01` 2026-10-31 20:00, `srv-app-dev-01` 2026-11-07 08:00. `tamano_mb` nulo con estado exitoso: `srv-app-prod-02` 2026-11-04 02:00, `db-dev-01` 2026-11-17 14:00 |
| Fechas en el futuro | 2 | `db-prod-01` 2026-12-22 02:00 (+30 días), `srv-app-prod-01` 2027-12-27 02:00 (+400 días) |
| Servidor fuera del inventario | 3 (2 servidores) | `srv-app-prod-03` (2 respaldos, 2026-11-19 y 2026-11-20), `srv-ftp-01` (1, 2026-11-17) |

Los ids exactos dependen del orden de carga y son estables mientras no cambien los scripts de `servicios/db/`.

Respuestas aceptables que difieren:
- Contar duplicados como 6 filas involucradas, o como 3 grupos. Lo importante es que diga cuál cuenta.
- Definir duplicado solo por `(servidor, fecha)`: da el mismo resultado.
- Los respaldos `fallido` con `tamano_mb = 0.0` no son nulos ni errores de integridad: son fallas reales del respaldo.

## Avanzado: EXPLAIN ANALYZE de la consulta 3

`DISTINCT ON` lee las 27,292 filas y las ordena (`Seq Scan` + `Sort`, unos 13 a 25 ms).
Con un índice `(servidor, fecha DESC)` el plan **no cambia** si la consulta sigue igual. La
mejora aparece al reescribirla con `LATERAL ... LIMIT 1`:

```sql
-- Propuesto, no creado: lector no puede (ERROR:  cannot execute CREATE INDEX in a read-only transaction)
CREATE INDEX respaldos_servidor_fecha_idx ON respaldos (servidor, fecha DESC);

SELECT s.nombre, r.fecha, r.tipo, r.estado
FROM servidores s
LEFT JOIN LATERAL (
    SELECT fecha, tipo, estado FROM respaldos
    WHERE servidor = s.nombre ORDER BY fecha DESC LIMIT 1
) r ON true
ORDER BY s.nombre;
```
Medido como superusuario en una copia: sin índice, unos 13 ms; con índice, `Index Scan using
respaldos_servidor_fecha_idx` (10 búsquedas de 1 fila) y 0.16 ms.

Reporte: `\copy (<consulta 2>) TO 'reportes/sin-respaldo.csv' CSV HEADER` deja el archivo en
`reportes/` del repositorio (la carpeta está montada en el contenedor y no se versiona).

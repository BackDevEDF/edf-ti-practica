# Servidores

Resumen de `docs/inventario-servidores.csv` (datos ficticios). El CSV es la fuente de
verdad: si cambia, actualiza esta tabla.

| Servidor | Rol | Sistema operativo | Entorno | Responsable |
|----------|-----|-------------------|---------|-------------|
| srv-app-dev-01 | Servidor de aplicaciones | Ubuntu 22.04 LTS | desarrollo | Equipo Desarrollo |
| srv-app-prod-01 | Servidor de aplicaciones | RHEL 9.2 | produccion | Equipo Operaciones TI |
| srv-app-prod-02 | Servidor de aplicaciones | RHEL 9.2 | produccion | Equipo Operaciones TI |
| db-dev-01 | Base de datos PostgreSQL | Ubuntu 22.04 LTS | desarrollo | Equipo Datos |
| db-prod-01 | Base de datos PostgreSQL | RHEL 9.2 | produccion | Equipo Datos |
| srv-web-qa-01 | Servidor web Nginx | Debian 12 | qa | Equipo Desarrollo |
| srv-batch-prod-01 | Procesos batch nocturnos | RHEL 8.8 | produccion | Equipo Operaciones TI |
| srv-respaldos-01 | Almacenamiento de respaldos | Ubuntu 20.04 LTS | produccion | Equipo Infraestructura |
| srv-monitoreo-01 | Monitoreo y alertas | Debian 12 | produccion | Equipo Infraestructura |
| srv-ad-01 | Controlador de dominio | Windows Server 2022 | produccion | Equipo Infraestructura |

## Notas
- Entornos: `desarrollo`, `qa` y `produccion`. Cualquier cambio en `produccion` pasa por
  el Equipo Operaciones TI.
- `srv-app-prod-01` y `db-prod-01` aparecen en `logs/aplicacion.log` (conciliación de pagos).
- `srv-ad-01` es Windows: los scripts de `scripts/` no están pensados para correr ahí.
- Versiones con soporte por vencer: Ubuntu 20.04 (`srv-respaldos-01`) y RHEL 8.8
  (`srv-batch-prod-01`).
- Aquí no se escriben IP, usuarios ni contraseñas.

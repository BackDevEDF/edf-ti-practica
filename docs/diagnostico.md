# Diagnóstico

Cómo revisar los servicios del laboratorio sin romper nada. Datos ficticios.

## Servicios (docker-compose.yml)

| Servicio | Imagen | Puerto en tu equipo | Para qué |
|---|---|---|---|
| `web` | `nginx:1.30.5` | `localhost:8080` (salud: `/salud`) | Sitio interno de inventario |
| `db` | `postgres:17.11` | `localhost:5433` | Base `inventario`: tablas `servidores` y `respaldos` |

## Dónde están los logs y la configuración
- `web`: `docker compose logs --tail 50 web`. Configuración en `servicios/web/default.conf`,
  que dentro del contenedor es `/etc/nginx/conf.d/default.conf` (así aparece en los errores).
- `db`: `docker compose logs --tail 50 db`. Los scripts que crean la base están en
  `servicios/db/` y solo corren la primera vez, con el volumen vacío.
- Incidente de la Sesión 3: `incidente/` (`auth.log`, `nginx-access.log`, `correo-sospechoso.eml`).
  Son miles de líneas: primero `wc -l`, luego un filtro (`grep`, `awk`, `sort | uniq -c`).

## Comandos seguros para diagnosticar
- `docker compose ps`: estado de cada servicio (`Restarting` = arranca y se cae; `healthy`/`unhealthy`).
- `docker compose logs --tail 50 <servicio>`: lo último del log.
- `docker compose config`: la configuración final. Ojo: imprime las contraseñas de `.env`.
- `docker compose exec web nginx -t`: prueba la configuración de nginx (solo si `web` está arriba;
  si está en `Restarting`, usa `docker compose run --rm web nginx -t`).
- `curl -I http://localhost:8080`: el síntoma y la verificación.
- Después de corregir `default.conf`: `docker compose restart web` (no `nginx -s reload`:
  el contenedor puede seguir viendo el archivo anterior).

## Prohibidos (deny en .claude/settings.json) y por qué
- `docker compose down -v`, `docker volume rm`: borran el volumen con los datos de la base.
- `docker system prune`: borra contenedores, imágenes y redes que no son de este proyecto.
- `sudo`, `iptables`, `ufw`: cambian la máquina, no el proyecto.
- Todos los `docker ...` piden aprobación (`ask`): lee el comando antes de aprobarlo.
- Para detener los servicios: `docker compose stop`.

## Base de datos: siempre como lector
```bash
docker compose exec db psql -U lector -d inventario
```
- `lector` solo tiene `SELECT` y sus transacciones son de solo lectura: un `UPDATE` falla con
  `ERROR:  cannot execute UPDATE in a read-only transaction`. No se cambia de usuario ni de rol
  para "poder hacerlo".
- Reportes: `\copy (SELECT ...) TO 'reportes/archivo.csv' CSV HEADER` (aparece en `reportes/`,
  que no se versiona).
- La contraseña de `lector` está en `.env` (solo hace falta para conectarse desde fuera del
  contenedor, por ejemplo con el MCP). No se copia a `.mcp.json` ni a este archivo.

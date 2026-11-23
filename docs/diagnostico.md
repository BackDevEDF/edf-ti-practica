# Diagnóstico del laboratorio (Sesión 3)

Datos ficticios. Última revisión: 2026-11-23.

## 1. Dónde corre Docker
Docker corre **dentro de WSL, en la distro `ServerTest`**, no en Windows (el daemon de Windows no
responde y su CLI no tiene `docker compose`). Los comandos de Docker se ejecutan así:

```bash
wsl.exe -d ServerTest -e sh -c 'cd "/mnt/c/Users/EDF 6/Documents/Workspace/edf-ti-practica" && docker compose ps'
```

La distro `Ubuntu-24.04` no tiene Docker.

## 2. Servicios y puertos
Definidos en `docker-compose.yml` (las contraseñas salen de `.env`, nunca del archivo).

| Servicio | Contenedor | Imagen | Puerto (host → contenedor) | Para qué |
|---|---|---|---|---|
| `web` | `edf-ti-practica-web-1` | nginx:1.30.5 | 8080 → 80 | Sitio interno de inventario |
| `db` | `edf-ti-practica-db-1` | postgres:17.11 | 5433 → 5432 | Base `inventario` (tablas `servidores`, `respaldos`) |

Desde Windows, el puerto 5433 responde en `127.0.0.1` (probado con `Test-NetConnection`).

> [!warning] Estado conocido al 2026-11-23: `web` está en bucle de reinicios
> `docker logs` muestra `[emerg] "client_max_body_size" directive invalid value` en
> `servicios/web/default.conf:7`. El valor es `10mb`; nginx espera `10m`. Pendiente de corregir.

## 3. Dónde están los logs
| Qué | Dónde |
|---|---|
| Web (nginx) | `docker logs edf-ti-practica-web-1` (stdout/stderr del contenedor) |
| Base de datos | `docker logs edf-ti-practica-db-1` |
| Logs de ejemplo de la práctica | `logs/aplicacion.log`, `logs/respaldos.log`, `logs/accesos.log` |
| Material del incidente | `incidente/auth.log`, `incidente/nginx-access.log`, `incidente/correo-sospechoso.eml` |
| Salidas de `\copy … TO 'reportes/…'` | `reportes/` (se comparte con el contenedor `db`) |

Los archivos de `logs/` e `incidente/` son datos de ejemplo, no logs en vivo de los contenedores.
Rotación: `./scripts/rota-logs.sh [dias]`, probarlo en una copia de `logs/`, no en el repo.

## 4. Comandos seguros para diagnosticar (solo lectura)
Todos corren dentro de WSL `ServerTest`. Ojo: `docker *` está en **"ask"** en `.claude/settings.json`,
así que el agente pide confirmación aunque sean de solo lectura.

| Comando | Para qué |
|---|---|
| `docker ps -a` / `docker compose ps` | Estado y reinicios de los servicios |
| `docker logs --tail 50 <contenedor>` | Últimas líneas del log |
| `docker compose config` | Ver la configuración efectiva (puede mostrar valores de `.env`: no pegarla en notas ni tickets) |
| `docker inspect <contenedor>` | Detalle de un contenedor (revisar antes de compartir: incluye variables de entorno) |
| `Test-NetConnection 127.0.0.1 -Port 5433` | Comprobar que el puerto responde desde Windows |
| `dig`, `nslookup` | Consultas DNS |
| `git status`, `git diff`, `git log` | Estado del repo (permitidos sin preguntar) |
| `./scripts/revisa-secretos.sh` | Buscar secretos en el repo (permitido sin preguntar) |
| SQL `SELECT` como `lector` | Consultar el inventario (ver sección 6) |

## 5. Comandos prohibidos y por qué
Bloqueados con `deny` en `.claude/settings.json`; no se deben ejecutar tampoco a mano sin revisión.

| Comando | Por qué |
|---|---|
| `docker compose down -v`, `docker volume rm *` | Borran el volumen `datos-db`: se pierde toda la base |
| `docker system prune*` | Borra contenedores, redes e imágenes que no estén en uso, incluso los de otros proyectos en la misma distro (hay otros: `hrms-*`, `topaz-verif-pg`) |
| `rm -rf *` | Borrado recursivo sin vuelta atrás |
| `sudo *`, `iptables *`, `ufw *` | Cambian la máquina o su firewall; fuera del alcance del diagnóstico |
| Leer `.env*`, `llaves/`, `~/.ssh/` (`cat .env*`) | Contienen credenciales; solo se consulta si una variable existe, nunca su valor |

Además piden confirmación (`ask`): `git push`, `docker *`, `systemctl *`, `ssh *`.

No hacer en el diagnóstico: `UPDATE`/`DELETE`/`DROP` en la base, reiniciar o detener servicios sin
avisar, ni arreglar un problema que solo se te pidió diagnosticar.

## 6. Conectarse a la base como `lector`
`lector` es un rol **de solo lectura**: `GRANT SELECT` y `default_transaction_read_only = on`
(`servicios/db/03-lector.sql`). Cualquier escritura falla. Es el único usuario para diagnosticar.

**Desde WSL (psql dentro del contenedor):**
```bash
wsl.exe -d ServerTest -e sh -c 'cd "/mnt/c/Users/EDF 6/Documents/Workspace/edf-ti-practica" && docker compose exec db psql -U lector -d inventario'
```
Describir sin ruido: `\dt`, `\d servidores`, `\d respaldos` (evitar `\d+ *`, vuelca el catálogo del sistema).

**Desde Claude Code (MCP `inventario`):** registrado con alcance *local* (solo tu perfil, nunca en un
`.mcp.json` del repo), apuntando a `127.0.0.1:5433`, base `inventario`, usuario `lector`. Para que
arranque, `LECTOR_PASSWORD` debe estar exportada **en el shell desde el que lanzas `claude`**; si no,
el servidor falla con `environment variable not found: "POSTGRES_PASSWORD"`.
Quitarlo: `claude mcp remove inventario -s local`.

> [!tip] Cuidado con las fechas
> En `respaldos` hay filas con fecha futura (hasta 2027) y `estado` nulo. En consultas de
> "último respaldo" filtrar `fecha <= now()` y contar solo `estado = 'exitoso'`.

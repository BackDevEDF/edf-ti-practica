# Notas para el instructor — Sesión 3

Esta rama (`solucion-s3`) es solo para el instructor. Los alumnos parten de `upstream/s3-inicio`,
que sale de `solucion-s2` sin `NOTAS-INSTRUCTOR-S2.md`.

> Como en las sesiones anteriores, aquí no se escriben valores de secretos.

Ramas:
- `s3-inicio` = `solucion-s2` + `docker-compose.yml`, `servicios/`, `incidente/`, 6 reglas `deny` nuevas,
  `reportes/` en `.gitignore`, 2 variables nuevas en `.env` y la sección "Sesión 3" del README.
- `solucion-s3` = `s3-inicio` + la corrección de nginx, el healthcheck, `incidente/linea-del-tiempo.md`,
  `propuestas/fail2ban.local`, `docs/diagnostico.md` (con su línea en `CLAUDE.md`), `sql/` y estas notas.

Flujo de los alumnos (README, sección "Sesión 3"):
```bash
docker run hello-world
git fetch upstream s3-inicio
git checkout -b s3-<nombre> upstream/s3-inicio
git push -u origin s3-<nombre>
docker compose up -d
docker compose ps
```

## 1. Lo sembrado

### Laboratorio 1: `web` no arranca
`servicios/web/default.conf`, línea 7: `client_max_body_size 10mb;`. nginx acepta `k`, `m` o `g`,
no `mb`. La corrección es una línea: `client_max_body_size 10m;`.

Síntoma:
```
$ docker compose ps
web   ...   Restarting (1) 5 seconds ago
$ curl -I http://localhost:8080
curl: (7) Failed to connect to localhost port 8080 ...
$ docker compose logs --tail 5 web
web-1  | 2026/11/22 21:05:56 [emerg] 1#1: "client_max_body_size" directive invalid value in /etc/nginx/conf.d/default.conf:7
web-1  | nginx: [emerg] "client_max_body_size" directive invalid value in /etc/nginx/conf.d/default.conf:7
```
La ruta del error es la del contenedor. El alumno (o Claude) debe ligarla, por el volumen de
`docker-compose.yml`, con `servicios/web/default.conf`: es parte del diagnóstico.

### Laboratorio 2: el incidente (`incidente/`)
- `auth.log`: 2,313 líneas, SSH de `srv-app-prod-01`, 21 nov 22:00 a 22 nov 06:25.
- `nginx-access.log`: 1,643 líneas, formato combined, misma noche. **Su reloj va 7 minutos adelantado.**
- Ataque lento desde 4 IP (`203.0.113.45`, `198.51.100.23`, `192.0.2.77`, `203.0.113.118`):
  190 intentos, 5 a 8.5 minutos entre intentos por IP, nunca más de 2 fallos en 10 minutos.
- Acceso exitoso: `soporte` desde `198.51.100.23` a las 05:13:41 (`auth.log:2110`), `sudo` negado
  (`auth.log:2130`), salida 05:28:10 (`auth.log:2160`).
- Para medir el desfase: el monitoreo `10.20.0.15` hace SSH y `GET /salud` cada 5 minutos con
  variación de segundos (102 pares, todos con +7 min 02 s). También `jlopez` (`10.20.0.50`) y `mgarcia` (`10.20.0.61`).
- Contraste: `192.0.2.150` hace 12 intentos en 33 segundos a la 01:31. A ese sí lo bloquea fail2ban por defecto.
- Respuesta completa con líneas citadas: `incidente/linea-del-tiempo.md`.

### Demo: `incidente/correo-sospechoso.eml`
- `Received` de abajo: `from [10.8.0.14] (unknown [198.51.100.201]) by smtp3.hosting-vps.example`, con zona `+0300 (MSK)`.
- `spf=softfail`, `dkim=none (message not signed)`, `dmarc=fail (p=QUARANTINE ...)`.
- `From` y `Return-Path`: `soporte@ejemplo-edf.mx`. `Reply-To`: `mesa.ayuda@soporte-ejemplo-edf.example` (otro dominio).
- `X-Mailer: PHPMailer`, `Message-ID` del dominio del VPS.
- En la parte HTML, el texto del enlace dice `https://portal.ejemplo-edf.mx/restablecer`, pero el
  `href` va a `https://ejemplo-edf-acceso.invalid/...`. En la parte de texto solo se ve el dominio legítimo.
- El asunto está codificado (`=?UTF-8?B?...?=`): "Acción requerida: su contraseña vence hoy".
- Conclusión esperada: phishing.

### Laboratorio 3: la base `inventario`
- `servidores`: 10 filas, cargadas de `docs/inventario-servidores.csv`. **No existe `srv-01`.**
- `respaldos`: 27,292 filas. Sin llave foránea, sin `NOT NULL` y solo con el índice de la llave primaria.
  - Histórico cada 6 horas, de hace 760 a hace 31 días (en `02-datos.sql`).
  - Último mes en `servicios/db/datos/respaldos.csv`, con "días atrás" en lugar de fechas.
- Sin respaldo en 7 días: `srv-web-qa-01` (nunca), `srv-ad-01` (hace 12 días), `srv-monitoreo-01` (hace 9).
- Integridad: 3 duplicados exactos, 4 nulos (2 `estado`, 2 `tamano_mb`), 2 fechas futuras
  (+30 y +400 días), 3 respaldos de `srv-app-prod-03` y `srv-ftp-01`, que no están en el inventario.
- Resultados completos: `sql/resultados-esperados.md`.
- **Las fechas son relativas al día en que se crea la base.** Si la levantaste días antes para
  probar, los servidores sanos también salen "sin respaldo". Recréala tú (no Claude): `docker compose down -v && docker compose up -d`.
- Rol `lector`: `LOGIN`, `CONNECT`, `USAGE`, `SELECT` en todas las tablas y
  `default_transaction_read_only = on` (`servicios/db/03-lector.sql`). La contraseña sale de `LECTOR_PASSWORD`, en `.env`.
  Dentro del contenedor la conexión por socket es `trust`: `psql -U lector` no pide contraseña.

## 2. Mensajes esperados (Claude Code 2.1.330, `claude -p`)

**Las 6 reglas nuevas** (`deny`):
```
Permission to use Bash with command docker compose down -v has been denied.
Permission to use Bash with command docker volume rm edf-prueba-inexistente has been denied.
Permission to use Bash with command docker system prune -f has been denied.
Permission to use Bash with command sudo ls /root has been denied.
Permission to use Bash with command iptables -L has been denied.
Permission to use Bash with command ufw status has been denied.
```
**`docker compose ps`, `logs`, `up -d` y `exec` no se bloquean**, pero caen en el `ask`
`Bash(docker *)` de la Sesión 1. En modo interactivo aparece el diálogo de aprobación; en `claude -p`:
`Claude requested permissions to use Bash, but you haven't granted it yet.`
Un `--allowedTools "Bash(docker compose exec *)"` **no** gana a ese `ask` (deny → ask → allow).

**Huecos de las reglas:** `docker compose down --volumes` y `docker compose down -t 5 -v` no
coinciden con `Bash(docker compose down -v*)`: caen en el `ask` y se pueden aprobar. Es un buen
ejemplo de "deny es una barrera, no aislamiento".

**UPDATE como lector:**
```
ERROR:  cannot execute UPDATE in a read-only transaction
```
Sale igual con `WHERE nombre = 'srv-01'`, aunque ese servidor no exista: el bloqueo es anterior a buscar filas.
Si Claude intenta saltárselo:
- con `SET default_transaction_read_only = off` o `BEGIN READ WRITE`, el siguiente error es
  `ERROR:  permission denied for table servidores` (no hay `GRANT UPDATE`);
- con `CREATE INDEX`, sale `ERROR:  cannot execute CREATE INDEX in a read-only transaction`.

**`docker compose exec web nginx -t` con `web` en `Restarting`:**
`Error response from daemon: Container <id> is restarting, wait until the container is running`.
Lo que sirve en ese estado es `docker compose run --rm web nginx -t`, que muestra la línea `[emerg]`.

## 3. Salida esperada por laboratorio

**Lab 1.**
- Después de corregir la línea 7, usar `docker compose restart web`: en 1 segundo `curl -I` da `HTTP/1.1 200 OK`.
- Con `docker compose up -d web`, el contenedor no se recrea (el `docker-compose.yml` no cambió).
  El arreglo solo entra en el siguiente reintento de Docker, que tras unos minutos de fallos llega
  a 1 minuto de espera. Medido: 60 segundos hasta el 200.
- Avanzado: con el healthcheck (`curl -fsS -o /dev/null http://localhost/salud`, cada 10 s),
  `docker compose ps` muestra `Up 15 seconds (healthy)`.
  - Para verlo `unhealthy`, hay que romper algo que no impida arrancar: por ejemplo, cambiar
    `/salud` a `return 503` y luego `docker compose restart web`. A los ~35 s sale `(unhealthy)`.
  - Si se rompe la sintaxis, sale `Restarting`, no `unhealthy`.
  - `nginx -s reload` no sirve: el volumen de un solo archivo sigue apuntando al archivo
    anterior si el editor lo reemplazó (`sed -i`, muchos editores). Dentro del contenedor hasta
    puede aparecer como `No such file or directory`. `restart` lo vuelve a montar.

**Lab 2.**
- Prompt 2: 2,313 líneas, del 21 nov 22:00 al 22 nov 06:25. Por IP, las 4 del ataque encabezan con
  43 a 51 fallos; `192.0.2.150` tiene 12, todos en la misma hora.
- Prompt 3: desfase de +7 minutos en `nginx-access.log`; inicio a las 23:37:12 (web, corregido) o
  23:41:07 (SSH); fin a las 05:15:00; acceso de `soporte`; nunca más de 2 fallos en 10 minutos.
- Prompt 4: ver `propuestas/fail2ban.local` (`maxretry 5`, `findtime 1h`, `bantime 1h` con incremento,
  `recidive` de 1 día / 3 bloqueos / 1 semana, `ignoreip 10.20.0.0/16`). Usuario legítimo en riesgo:
  `mgarcia`, con 2 fallos a las 23:02.

**Lab 3.** `sql/resultados-esperados.md`. Probado con `claude -p` y los Prompts 7 y 8 tal cual vienen
en el deck: los dos llegan a las respuestas sembradas (3 servidores sin respaldo, incluido
`srv-web-qa-01`; 4 reglas que fallan, con 3/4/2/3 registros).

**Avanzado del Lab 3: MCP de Postgres.** Se usa MCP Toolbox for Databases de Google
(`@toolbox-sdk/server`, con `npx`; Node ya es requisito del curso):
```bash
export LECTOR_PASSWORD="$(grep '^LECTOR_PASSWORD=' .env | cut -d= -f2-)"
claude mcp add inventario --scope project \
  -e POSTGRES_HOST=localhost -e POSTGRES_PORT=5433 -e POSTGRES_DATABASE=inventario \
  -e POSTGRES_USER=lector -e 'POSTGRES_PASSWORD=${LECTOR_PASSWORD}' \
  -- npx -y @toolbox-sdk/server@1.16.0 --prebuilt postgres --stdio
claude
```
- `.mcp.json` guarda `"POSTGRES_PASSWORD": "${LECTOR_PASSWORD}"`, no el valor. Claude Code lo
  sustituye al arrancar: hay que exportar la variable **antes** de abrir `claude`, en esa misma terminal.
- Al abrir `claude` pide aprobar el servidor del proyecto (`claude mcp list` lo muestra como `Pending approval`).
- Herramientas: `execute_sql`, `list_tables`, `get_query_plan` y otras.
- Un `UPDATE` por MCP da:
  `error processing request: unable to execute query: ERROR: cannot execute UPDATE in a read-only transaction (SQLSTATE 25006)`.
- `.mcp.json` no agrega hallazgos a `revisa-secretos.sh`.

**EXPLAIN (Avanzado).** Con el índice `(servidor, fecha DESC)`, la consulta con `DISTINCT ON` sigue
en `Seq Scan` + `Sort` (unos 13 a 25 ms). La versión `LATERAL ... LIMIT 1` pasa a `Index Scan` y 0.16 ms.
Buen punto: un índice solo ayuda si la consulta lo puede usar.

**Reporte.** `\copy (SELECT ...) TO 'reportes/sin-respaldo.csv' CSV HEADER` desde
`docker compose exec db psql ...` deja el archivo en `reportes/` del repositorio: la carpeta está
montada en `/trabajo/reportes` y `working_dir` es `/trabajo`. El `\copy` va en una sola línea.

## 4. Fallas comunes

**Lab 1**
- Aprobar la corrección sin línea citada: el error dice `default.conf:7`, no hay excusa.
- Buscar en `/etc/nginx/conf.d/default.conf` del equipo local: ese archivo está dentro del contenedor.
- `docker compose exec web ...` mientras `web` está en `Restarting`: falla (ver la sección 2).
- `up -d web` y curl inmediato: sigue fallando hasta 1 minuto. Usar `docker compose restart web`.
- Claude propone `docker compose down` y `up` "para empezar de cero": sin `-v` no borra datos, pero no hace falta.
- Puerto 8080 o 5433 ocupado (otro servicio, otro Postgres):
  `Bind for 0.0.0.0:5433 failed: port is already allocated`. Detener ese servicio, o cambiar el
  puerto de la izquierda en `docker-compose.yml` sin hacer commit de ese cambio.

**Lab 2**
- Leer el log completo: pedir `wc -l` primero (Prompt 2).
- Unir los logs sin corregir el reloj: el orden del primer contacto se invierte (SSH 23:41 antes que web 23:44).
- Concluir "no fue fuerza bruta porque son pocos por minuto": es el punto del ejercicio.
- Contar `Invalid user` y `Failed password` como dos intentos: un intento genera 3 a 5 líneas;
  contar `Failed password`.
- No ver el acceso: buscar `Accepted password` (las demás `Accepted` son `publickey` legítimas).

**Lab 3**
- `JOIN` en lugar de `LEFT JOIN`: salen 2 servidores sin respaldo en vez de 3.
- Contar fechas futuras como "respaldo reciente".
- Claude propone conectarse como `postgres` o cambiar el rol para hacer el `UPDATE`: no se aprueba.
  `POSTGRES_PASSWORD` está en `.env`, protegido por el deny de la Sesión 1. Pero
  `docker compose config` imprime ese valor ya sustituido: deny es una barrera, no aislamiento.
- Pedirle a Claude "actualiza srv-01": no existe. Claude puede responder "ese servidor no existe" sin intentar el UPDATE.
  Usar `srv-app-dev-01`.
- Base creada días antes de la sesión: los resultados de "7 días" cambian (sección 1).

## 5. Windows (Git Bash + Docker Desktop con WSL 2)
- Docker Desktop debe estar abierto. `docker run hello-world` es la prueba.
- `docker compose exec db psql ...` interactivo en Git Bash (mintty) puede dar
  `the input device is not a TTY`. Usar `winpty docker compose exec db psql -U lector -d inventario`.
  Para un solo comando, `docker compose exec -T db psql ... -c "..."`. Cuando lo corre Claude no hay TTY y funciona.
- No hacer `\copy` con rutas absolutas de Windows: usar `reportes/x.csv` relativo.
- Repo en una ruta sin espacios. En `C:\Users\...` los volúmenes funcionan, solo son más lentos.
- `.env`, `.sql` y `.conf` quedan en LF por `.gitattributes`. Con CRLF, nginx y psql siguen
  funcionando, pero conviene no tocar los finales de línea.
- Para el MCP: `export LECTOR_PASSWORD=...` en Git Bash, y abrir `claude` en esa misma ventana.
- El binario de Toolbox existe para Windows x64 y arm64, macOS y Linux x64. **No hay para Linux arm64.**

## 6. Sin Docker
- El Laboratorio 2 es solo archivos: se hace completo.
- Labs 1 y 3: en pareja con alguien que sí tenga Docker. Sin pareja, se pueden leer
  `servicios/web/default.conf` (el Prompt 1 encuentra la línea 7 sin contenedor) y
  `servicios/db/` para razonar el esquema, pero no se ve el error de solo lectura.

## 7. Tiempos sugeridos (laboratorio)

| Laboratorio | Minutos |
|---|---|
| Lab 1: servicio caído (diagnóstico, corrección, commit) | 20 |
| Lab 2: línea del tiempo del incidente | 20 |
| Lab 3: consultas, intento de UPDATE, integridad | 25 |
| **Total** | **65** |

Avanzado si sobra tiempo: el healthcheck (Lab 1), el subagente y fail2ban (Lab 2), y el MCP, EXPLAIN y el reporte (Lab 3).
Al terminar: `docker compose stop` (nunca `down -v`).

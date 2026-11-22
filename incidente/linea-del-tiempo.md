# Línea del tiempo del incidente: noche del 21 al 22 de noviembre de 2026

Fuentes: `incidente/auth.log` (SSH de `srv-app-prod-01`, 2,313 líneas) e
`incidente/nginx-access.log` (log de acceso del web, 1,643 líneas). Datos ficticios.
`auth.log:N` y `nginx-access.log:N` son números de línea.

## 1. Reloj: el web va 7 minutos adelantado

El monitoreo (`10.20.0.15`) entra por SSH y, dos segundos después, pide `/salud` al web.
Lo hace cada 5 minutos con una variación de segundos, así que cada par es único:

| SSH (`auth.log`) | Web (`nginx-access.log`) | Diferencia |
|---|---|---|
| `auth.log:18` 22:01:08 `Accepted publickey for monitor from 10.20.0.15` | `nginx-access.log:6` 22:08:10 `GET /salud` | +7 min 02 s |
| `auth.log:1131` 02:05:56 `Accepted publickey for monitor from 10.20.0.15` | `nginx-access.log:776` 02:12:58 `GET /salud` | +7 min 02 s |

Los 102 pares de la noche dan la misma diferencia. Otra prueba: `jlopez` entra por SSH desde
`10.20.0.50` a las 22:10:15 (`auth.log:46`) y su primera petición web, 25 segundos después,
aparece a las 22:17:40 (`nginx-access.log:65`).

**Corrección:** a cada hora de `nginx-access.log` se le restan 7 minutos. Abajo, todas las
horas están en la hora de `auth.log` (CST, -06:00).

Con los logs no se puede saber cuál de los dos relojes es el correcto: solo la diferencia.
Se toma `auth.log` como referencia y se pide revisar NTP en el servidor web.

## 2. Línea del tiempo (horas corregidas)

| Hora | Evento | Evidencia |
|---|---|---|
| 21 nov 23:37:12 | **Primer contacto.** `203.0.113.45` sondea el web: `/`, y luego rutas que no existen (`404`) con el agente `zgrab` | `nginx-access.log:453` (23:44:12 en el log, sin corregir) |
| 23:41:07 | Primer intento SSH fallido de `203.0.113.45` (`root`) | `auth.log:332` |
| 23:49:03 | `198.51.100.23` sondea el web (`python-requests`) | `nginx-access.log:505` |
| 23:52:40 | Primer intento SSH de `198.51.100.23`, directo a `soporte` | `auth.log:362` |
| 22 nov 00:01:44 | `192.0.2.77` sondea el web (`Go-http-client`) | `nginx-access.log:532` |
| 00:05:14 | Primer intento SSH de `192.0.2.77` | `auth.log:399` |
| 00:16:20 | `203.0.113.118` sondea el web (`curl`) | `nginx-access.log:561` |
| 00:19:52 | Primer intento SSH de `203.0.113.118` | `auth.log:486` |
| 00:20 a 05:13 | Las 4 IP siguen, cada una con un intento cada 5 a 8.5 minutos | ver la sección 3 |
| 01:31:09 a 01:31:42 | Otro atacante, `192.0.2.150`, hace 12 intentos en 33 segundos. Ese sí lo habría bloqueado fail2ban con su configuración por defecto | `auth.log:888` a `auth.log:952` |
| **05:13:41** | **Acceso exitoso:** `Accepted password for soporte from 198.51.100.23` | `auth.log:2110` |
| 05:15:02 | `soporte` intenta `sudo /bin/bash` y falla: `user NOT in sudoers` | `auth.log:2130` |
| 05:15:00 | Último intento fallido del ataque (`203.0.113.118`) | `auth.log:2128` |
| 05:19:55 | Último sondeo web del ataque (`203.0.113.118`, `/server-status`) | `nginx-access.log:1151` (05:26:55 sin corregir) |
| 05:28:10 | Se cierra la sesión de `soporte` | `auth.log:2160` |

Sin corregir el reloj, el primer evento parece ser el SSH de las 23:41. Corregido, el
primer contacto fue el sondeo web, 4 minutos antes.

**Inicio:** 21 nov 23:37:12 (web) / 23:41:07 (SSH). **Fin:** 05:15:00 (último intento) y
05:28:10 (cierre de la sesión). Duración del ataque: unas 5 horas y media.

## 3. Quién: IP y usuarios intentados

| IP | Intentos SSH fallidos | Primero | Último | Usuarios |
|---|---|---|---|---|
| `203.0.113.45` | 51 | 23:41:07 | 05:14:54 | root, admin, administrador, soporte, test, usuario |
| `198.51.100.23` | 50 | 23:52:40 | 05:10:40 | soporte, respaldos, admin, operador, sistemas |
| `192.0.2.77` | 46 | 00:05:14 | 05:13:45 | root, ubuntu, postgres, oracle, soporte, deploy |
| `203.0.113.118` | 43 | 00:19:52 | 05:15:00 | admin, test, guest, ftpuser, soporte, mysql |

- 190 intentos en total. Las 4 IP probaron `soporte`: 32 intentos fallidos contra esa cuenta antes del acceso.
- Además hay ruido normal de internet: 46 IP con 1 a 3 intentos cada una, a lo largo de la noche.
- Las 4 IP también sondean el web toda la noche (16 a 18 peticiones cada una, casi todas `404`):
  `/.env`, `/.git/config`, `/wp-login.php`, `/.aws/credentials`, etc.

## 4. ¿Alguien entró?

Sí. `198.51.100.23` entró como `soporte` con contraseña a las 05:13:41 (`auth.log:2110`),
después de 50 intentos fallidos de esa IP. Intentó ser root y no pudo (`auth.log:2130`), y
salió 14 minutos después (`auth.log:2160`). Los logs no muestran qué hizo dentro de la sesión.

Acciones: deshabilitar o rotar la contraseña de `soporte`, revisar `/home/soporte`, `last`,
el historial de comandos y los procesos de esa sesión, y bloquear las 4 IP.

## 5. Por qué no se detuvo

fail2ban, con su configuración por defecto (`maxretry = 5`, `findtime = 10m`,
`bantime = 10m`), bloquea una IP con 5 fallos en 10 minutos. Cada IP del ataque espera
entre 5 y 8.5 minutos entre intentos: **nunca tiene más de 2 fallos en una ventana de 10
minutos**, aunque sume unos 10 por hora y unos 50 en la noche. Cada fallo "caduca" antes de
que llegue el quinto. El atacante rápido (`192.0.2.150`) sí habría sido bloqueado a las 01:31:21.

Causa de fondo: el servidor acepta contraseñas por SSH y `soporte` tenía una contraseña débil.
Propuesta de fail2ban en `propuestas/fail2ban.local`.

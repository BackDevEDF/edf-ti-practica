# CLAUDE.md

Repositorio de práctica del curso de Claude Code para TI de EDF. Simula los scripts
operativos de un equipo de TI (respaldos, rotación de logs, notificaciones).
Todos los datos son ficticios.

## Dónde está cada cosa (lee el documento solo cuando lo necesites)
- [docs/scripts.md](docs/scripts.md): qué hace cada script, cómo se usa y sus códigos de salida.
- [docs/servidores.md](docs/servidores.md): inventario de servidores y entornos.
- [docs/decisiones.md](docs/decisiones.md): decisiones técnicas y por qué se tomaron.
- [docs/diagnostico.md](docs/diagnostico.md): servicios, puertos, logs, comandos seguros/prohibidos y conexión a la base como `lector`.
- `.claude/rules/scripts.md`: reglas de bash; se cargan solas al trabajar en `scripts/`.
- `.claude/agents/revisor.md`: subagente revisor de solo lectura.

## Comandos frecuentes
- Revisar secretos: `./scripts/revisa-secretos.sh` (tabla) o `./scripts/revisa-secretos.sh --json`.
- Rotar logs: `./scripts/rota-logs.sh [dias]`. Pruébalo en una copia de `logs/`, no en el repo.
- Ver cambios: `git status`, `git diff`, `git log --oneline`.

## Convenciones
- Todo en español: comentarios, mensajes de commit y documentación.
- Scripts en bash portables (macOS bash 3.2, Linux, Git Bash): ver `.claude/rules/scripts.md`.
- Las credenciales se leen de variables de entorno, nunca se escriben en el código.
- Trabaja en una rama; no hagas commit directo a `main`.

## Restricciones
- No leas, muestres ni copies credenciales: archivos `.env*`, la carpeta `llaves/`,
  `~/.ssh/` ni valores de tokens o contraseñas. Si necesitas saber si una variable
  existe, pregunta o revisa el nombre, nunca el valor.

## Antes de cada commit
- Ejecuta `./scripts/revisa-secretos.sh`. Si encuentra algo nuevo (código de salida 1
  con hallazgos que no sean los 5 sembrados para la práctica), no hagas commit y avísame.

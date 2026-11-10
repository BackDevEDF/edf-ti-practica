# CLAUDE.md

## Propósito del repositorio
Repositorio de práctica del curso de Claude Code para TI de EDF. Simula los scripts
operativos de un equipo de TI (respaldos, rotación de logs, notificaciones).
Todos los datos son ficticios.

## Convenciones
- Todo en español: comentarios, mensajes de commit y documentación.
- Scripts en bash con `set -euo pipefail` y comentarios cortos.
- Los scripts deben funcionar en macOS (bash 3.2, herramientas BSD), Linux y Git Bash:
  nada de arreglos asociativos ni opciones exclusivas de GNU.
- Las credenciales se leen de variables de entorno, nunca se escriben en el código.
- Trabaja en una rama; no hagas commit directo a `main`.

## Restricciones
- No leas, muestres ni copies credenciales: archivos `.env*`, la carpeta `llaves/`,
  `~/.ssh/` ni valores de tokens o contraseñas. Si necesitas saber si una variable
  existe, pregunta o revisa el nombre, nunca el valor.

## Antes de cada commit
- Ejecuta `./scripts/revisa-secretos.sh`. Si encuentra algo nuevo (código de salida 1
  con hallazgos que no sean los 5 sembrados para la práctica), no hagas commit y avísame.

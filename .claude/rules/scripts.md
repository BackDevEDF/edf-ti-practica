---
paths: ["scripts/**/*.sh"]
---

# Reglas para scripts de bash

Aplican a todo `scripts/**/*.sh`. Deben funcionar igual en macOS (bash 3.2, herramientas BSD),
Linux (GNU) y Git Bash en Windows.

## Portabilidad
- Nada de arreglos asociativos (`declare -A`) ni `mapfile`/`readarray`: no existen en bash 3.2.
  Usa variables sueltas o `case`.
- Nada de `grep -P`: usa `grep -E` con clases POSIX (`[[:space:]]`, `[0-9]`), no `\s` ni `\d`.
- En `grep`, pon `--include` antes que cualquier `--exclude` (en GNU, el orden cambia el resultado).
- Evita `sed -i`, `date -d`, `stat -c` y `readlink -f`: se comportan distinto en BSD y GNU.
- Con un arreglo que puede quedar vacío, bash 3.2 y `set -u` fallan en `"${arr[@]}"`.

## Errores
- Empieza con `#!/usr/bin/env bash` y `set -euo pipefail`.
- Un `grep` sin coincidencias regresa 1 y, con `set -e` y `pipefail`, termina el script.
  Agrega `|| true` cuando "sin coincidencias" sea un resultado válido:
  `done < <(grep -rn ... || true)`.
- Mensajes de error a stderr (`>&2`). Códigos: `0` éxito, `1` hallazgo o falla, `2` error de uso.

## Secretos
- Nunca imprimas el valor de un secreto: ni en la salida normal, ni en mensajes de error, ni "para depurar".
- Si procesas la salida de `grep`, quédate con `ruta:línea` (`cut -d: -f1,2`) antes de guardarla.
- Credenciales siempre desde variables de entorno, validadas con `${VAR:?mensaje}`, que no imprime el valor.
- Nunca uses `set -x` en un script que maneje credenciales.

## Estilo
- Comentarios cortos en español. Variables entre comillas (`"$VAR"`).
- Pasa `shellcheck` sin advertencias.

# Decisiones técnicas

Registro corto de decisiones: qué se decidió, por qué y qué implica.

## 1. Credenciales solo en variables de entorno
- **Decisión:** los scripts leen las credenciales de variables de entorno y validan que existan
  con `${VAR:?mensaje}`, sin imprimir su valor.
- **Por qué:** lo que se escribe en un script termina en Git, en los logs y en las pantallas compartidas.

## 2. Bash portable (macOS bash 3.2, Linux y Git Bash)
- **Decisión:** nada de arreglos asociativos (`declare -A`), `mapfile`, `grep -P` ni `sed -i` en los scripts.
- **Por qué:** el equipo usa los tres sistemas. macOS trae bash 3.2 y herramientas BSD.
- **Implica:** probar cada script en macOS y en Linux (por ejemplo, con Docker) antes de integrarlo.

## 3. revisa-secretos.sh nunca imprime valores
- **Decisión:** el escáner reporta ruta, línea y tipo. El contenido de la línea se descarta
  con `cut -d: -f1,2` antes de llegar a una variable o a la pantalla.
- **Por qué:** un escáner que imprime el secreto lo filtra a la terminal, al historial y a Claude.

## 4. Salida JSON sin jq
- **Decisión:** `--json` se arma con `printf` y escapa `\` y `"` en las rutas.
- **Por qué:** `jq` no viene instalado en macOS ni en Git Bash, y el formato es fijo y pequeño.
- **Implica:** un nombre de archivo con caracteres de control (tabuladores, saltos de línea)
  no se escaparía. Se acepta para este repositorio.

## 5. Secretos ficticios versionados a propósito
- **Decisión:** `.env`, `config/.env.produccion`, `llaves/` y dos credenciales en el código
  se versionan para la práctica.
- **Por qué:** son el material de los ejercicios. En un repositorio real irían en `.gitignore`
  y en un gestor de secretos.

## 6. Permisos de Claude Code en el proyecto
- **Decisión:** `.claude/settings.json` niega leer secretos, pide confirmación para `git push`,
  `docker`, `systemctl` y `ssh`, y permite sin preguntar `git status/diff/log` y el escáner.
- **Por qué:** el orden de evaluación es deny → ask → allow. Una regla `ask` amplia anula un
  `allow` específico, y un `deny` gana siempre. Por eso no hay `ask` sobre `./scripts/*`.

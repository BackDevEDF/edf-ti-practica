#!/usr/bin/env bash
# respaldo.sh - Comprime una carpeta en respaldos/ con la fecha en el nombre.
# Uso: exporta DB_HOST, DB_USER y DB_PASSWORD, y luego: ./scripts/respaldo.sh <carpeta>
# Las credenciales de la base se leen SIEMPRE de variables de entorno, nunca del script.
set -euo pipefail

# Validar argumentos
if [ "$#" -ne 1 ]; then
  echo "Uso: $0 <carpeta>" >&2
  exit 2
fi

ORIGEN="$1"
if [ ! -d "$ORIGEN" ]; then
  echo "Error: la carpeta '$ORIGEN' no existe." >&2
  exit 2
fi

# Validar que las variables de entorno existan (sin imprimir su valor)
: "${DB_HOST:?Falta la variable de entorno DB_HOST}"
: "${DB_USER:?Falta la variable de entorno DB_USER}"
: "${DB_PASSWORD:?Falta la variable de entorno DB_PASSWORD}"

# Carpeta destino relativa a la raíz del repositorio
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DESTINO="$RAIZ/respaldos"
mkdir -p "$DESTINO"

# Nombre con fecha y hora: respaldo-<carpeta>-AAAAMMDD-HHMMSS.tar.gz
FECHA="$(date +%Y%m%d-%H%M%S)"
NOMBRE="$(basename "$ORIGEN")"
ARCHIVO="$DESTINO/respaldo-$NOMBRE-$FECHA.tar.gz"

# Si existe pg_dump, también se respalda la base (opcional en la práctica)
if command -v pg_dump >/dev/null 2>&1; then
  echo "Respaldando base de datos en $DB_HOST con el usuario $DB_USER..."
  PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -U "$DB_USER" -f "$DESTINO/base-$FECHA.sql" \
    || { rm -f "$DESTINO/base-$FECHA.sql"
         echo "Aviso: no se pudo respaldar la base; se continúa solo con archivos." >&2; }
fi

# Comprimir la carpeta (tar y gzip existen en macOS, Linux y Git Bash)
tar -czf "$ARCHIVO" -C "$(dirname "$ORIGEN")" "$NOMBRE"

echo "Respaldo creado: $ARCHIVO"

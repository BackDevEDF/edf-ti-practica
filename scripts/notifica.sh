#!/usr/bin/env bash
# notifica.sh - Envía una notificación a un webhook (ficticio) con curl.
# Uso: ./scripts/notifica.sh "mensaje"
set -euo pipefail

# Dirección del webhook (ficticia: el dominio .invalid nunca resuelve)
WEBHOOK_URL="https://alertas.edf-ficticio.invalid/api/v1/notificar"

# MAL: token escrito directo en el script. Debería venir de una variable de entorno.
TOKEN_WEBHOOK="edfprac_9Kq2LmZ7vXc4Rt8PwN3yBd6Jh1Fs5Gu0Ta"

if [ "$#" -ne 1 ]; then
  echo "Uso: $0 \"mensaje\"" >&2
  exit 2
fi

MENSAJE="$1"
SERVIDOR="$(hostname)"

# Armar el JSON a mano para no depender de jq
CUERPO="{\"servidor\":\"$SERVIDOR\",\"mensaje\":\"$MENSAJE\"}"

# Enviar; --max-time evita que el script se quede colgado
if curl -sS --max-time 10 -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN_WEBHOOK" \
  -d "$CUERPO" "$WEBHOOK_URL"; then
  echo "Notificación enviada."
else
  echo "Error: no se pudo enviar la notificación (el webhook es ficticio)." >&2
  exit 1
fi

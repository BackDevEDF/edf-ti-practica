# Scripts

Todos los scripts están en `scripts/`, usan `set -euo pipefail` y funcionan en macOS
(bash 3.2), Linux y Git Bash. Se ejecutan desde la raíz del repositorio.

## revisa-secretos.sh

Busca secretos expuestos y reporta ruta, línea y tipo. **Nunca imprime el valor.**

```bash
./scripts/revisa-secretos.sh [--json] [carpeta]
```

| Tipo | Qué detecta |
|------|-------------|
| `archivo-env` | Archivos `.env` / `.env.*` versionados (se reporta el archivo completo) |
| `llave-privada` | Encabezado de llave privada PEM u OpenSSH |
| `token-hardcodeado` | Variables tipo token, api key o secreto con un valor largo escrito |
| `password-hardcodeado` | Contraseñas escritas en el código o la configuración |

- Sin opciones: tabla, resumen por tipo y una línea de resultado.
- `--json`: solo un arreglo JSON en la salida estándar, por ejemplo
  `[{"ruta": "config/app.conf", "linea": 16, "tipo": "password-hardcodeado"}]`.
  `linea` es `null` para `archivo-env`. Sin hallazgos imprime `[]`. No usa `jq`.
- Excluye `.git/`, `node_modules/`, `respaldos/` y a sí mismo.
- Códigos de salida: `0` sin hallazgos, `1` con hallazgos, `2` error de uso
  (carpeta inexistente, opción desconocida o más de una carpeta). Iguales con o sin `--json`.

## rota-logs.sh

Renombra cada `logs/*.log` con **más** de N días (por defecto 7) a
`<nombre>-AAAAMMDD.log` y lo comprime con gzip.

```bash
./scripts/rota-logs.sh [dias]
```

- Usa `find -mtime +N`: "modificado hace más de N días". `-mtime -N` sería lo contrario.
- Solo toca la carpeta `logs/` junto a `scripts/` (la calcula a partir de la ruta del script).
- Para probarlo sin tocar el repositorio:

```bash
TMP="$(mktemp -d)"; mkdir -p "$TMP/scripts"
cp scripts/rota-logs.sh "$TMP/scripts/"; cp -R logs "$TMP/"
touch -t 202609010000 "$TMP/logs/respaldos.log"   # simula un log viejo
"$TMP/scripts/rota-logs.sh"                        # debe rotar solo respaldos.log
```

## respaldo.sh

Comprime una carpeta en `respaldos/respaldo-<carpeta>-AAAAMMDD-HHMMSS.tar.gz`.
Si existe `pg_dump`, también respalda la base.

```bash
export DB_HOST=... DB_USER=...   # y la variable de la contraseña de la base
./scripts/respaldo.sh <carpeta>
```

- Lee las credenciales **solo** de variables de entorno; si falta alguna, se detiene con un error.
- Código `2` si falta el argumento o la carpeta no existe.

## notifica.sh

Envía un mensaje con `curl` a un webhook ficticio (dominio `.invalid`, nunca resuelve).

```bash
./scripts/notifica.sh "mensaje"
```

Tiene un token escrito en el código **a propósito**: es uno de los 5 hallazgos de la práctica.

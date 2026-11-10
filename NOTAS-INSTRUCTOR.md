# Notas para el instructor — Sesión 1

Esta rama (`solucion-s1`) es solo para el instructor. Los alumnos trabajan sobre `main`.

> En este archivo no se escriben los valores de los secretos a propósito: si los
> escribiéramos, `revisa-secretos.sh` también reportaría este archivo.

## Los 5 secretos sembrados (4 tipos)

| # | Ruta | Línea | Tipo | Qué es |
|---|------|-------|------|--------|
| 1 | `.env` | archivo completo | archivo-env | `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `API_TOKEN` ficticios |
| 2 | `config/.env.produccion` | archivo completo | archivo-env | Las mismas variables "de producción" más `WEBHOOK_URL` |
| 3 | `llaves/id_practica` | 1 | llave-privada | Llave OpenSSH ed25519 sin passphrase, generada con `ssh-keygen`; no está autorizada en ningún servidor |
| 4 | `scripts/notifica.sh` | 10 | token-hardcodeado | Variable `TOKEN_WEBHOOK` con un token inventado (prefijo `edfprac_`) |
| 5 | `config/app.conf` | 16 | password-hardcodeado | Línea de contraseña en la sección `[base_datos]` |

`llaves/id_practica.pub` es la llave pública: **no** es un secreto y no debe contarse.

## Salida esperada de `./scripts/revisa-secretos.sh`

```
Revisando secretos en: .

ARCHIVO                          LINEA  TIPO
-------                          -----  ----
config/.env.produccion           -      archivo-env
.env                             -      archivo-env
llaves/id_practica               1      llave-privada
scripts/notifica.sh              10     token-hardcodeado
config/app.conf                  16     password-hardcodeado

Resumen por tipo:
  archivo-env            2
  llave-privada          1
  token-hardcodeado      1
  password-hardcodeado   1
Total de hallazgos: 5
RESULTADO: se encontraron secretos expuestos. No hagas commit hasta resolverlos.
```

Código de salida: `1` (comprobar con `echo $?`). El orden de los dos `.env` puede variar según el sistema.

## Fallas comunes en los scripts de los alumnos

**Fugas del valor**
- Imprimir la salida de `grep -n` tal cual: muestra la línea completa con el secreto.
  Solución: quedarse solo con `ruta:línea` (por ejemplo, `cut -d: -f1,2`).
- Imprimir la línea "para depurar" y olvidarse de quitarlo.

**Falsos positivos**
- `scripts/respaldo.sh` lee la contraseña de una variable de entorno (`${DB_PASSWORD:?...}`,
  `PGPASSWORD="$DB_PASSWORD"`). Eso es lo correcto y **no** es un hallazgo; un patrón
  ingenuo como `PASSWORD` lo reporta. Buen momento para hablar de la diferencia entre
  "nombre de variable" y "valor escrito en el código".
- El script se detecta a sí mismo (contiene los patrones). Debe excluirse.
- El `README.md` o el `.gitignore` mencionan `.env`: no son secretos.
- `id_practica.pub` reportado como llave privada.
- Contar cada línea de los `.env` por separado da 9 o más hallazgos en lugar de 2.
  Es aceptable si el alumno lo justifica, pero el resumen por tipo debe dejarlo claro.
- Revisar `.git/`: aparecen objetos y duplicados. Debe excluirse.

**Portabilidad (macOS vs Linux vs Git Bash)**
- `declare -A` (arreglos asociativos) y `mapfile` no existen en bash 3.2 de macOS.
- `grep -P` no existe en el grep de macOS. Usar `grep -E`.
- `\s` y `\d` no son portables en ERE: usar `[[:space:]]` y `[0-9]`.
- `grep --include` / `--exclude`: en GNU grep (Linux y Git Bash), si el **primer** filtro
  es `--exclude`, los archivos que no coinciden con `--include` se incluyen todos. El
  script funciona en macOS y en Linux da hallazgos de más. Poner `--include` primero.
- Con `set -euo pipefail`, un `grep` sin coincidencias regresa 1 y termina el script.
  Usar `|| true` en las búsquedas.
- `sed -i` se comporta distinto en BSD y GNU (no debería hacer falta en este script).

**Código de salida**
- Siempre sale con 0, o sale con 1 en el primer hallazgo sin mostrar el resto.

## Fallas comunes con `.claude/settings.json`

- JSON inválido (coma de más al final de una lista): las reglas no se aplican.
  Revisar con `/permissions` o `/doctor` dentro de Claude.
- Guardarlo como `.claude/settings.local.json`: funciona, pero no se versiona
  (está en `.gitignore`), así que no sirve para el commit del ejercicio 5.
- Las reglas `allow` del proyecto se ignoran hasta aceptar el diálogo de confianza
  de la carpeta (aparece la primera vez que se abre `claude` en el repo). Las reglas
  `deny` sí aplican desde el inicio.
- Cuando una lectura está bloqueada, la herramienta Read responde:
  `File is in a directory that is denied by your permission settings.`
  Si Claude solo dice "no debo leer eso", fue por `CLAUDE.md`, no por la regla:
  pídele que intente leerlo y que muestre el error exacto.
- En Claude Code 2.1.322 las reglas `Read(...)` también bloquean comandos de Bash que
  leen esas rutas (`cat`, `head`, `grep ... .env`). `Bash(cat .env*)` queda como
  defensa extra, pero por sí sola no cubre `head .env` ni `cat ./.env`.
- Ejecutar `./scripts/revisa-secretos.sh` desde Claude **sí** funciona con estas reglas:
  el bloqueo aplica a comandos que nombran la ruta, no a lo que un script lee por dentro.
  Vale la pena comentarlo: las reglas `deny` son una barrera, no un aislamiento total.

## Ejercicio 6 (git restore)

Cambio malo sugerido: pedirle a Claude que "simplifique" `scripts/respaldo.sh` quitando
`set -euo pipefail`, o borrar una sección de `config/app.conf`. Luego:

```bash
git status
git diff
git restore scripts/respaldo.sh
```

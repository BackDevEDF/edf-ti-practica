# Notas para el instructor — Sesión 2

Esta rama (`solucion-s2`) es solo para el instructor. Los alumnos parten de `upstream/s2-inicio`,
que sale del commit `5f33165` (la rama `solucion-s1`, borrada el 2026-11-11).

> Como en la Sesión 1, aquí no se escriben los valores de los secretos: si los escribiéramos,
> `revisa-secretos.sh` también reportaría este archivo.

Ramas:
- `s2-inicio` = commit `5f33165` (la rama `solucion-s1`, borrada el 2026-11-11) sin `NOTAS-INSTRUCTOR.md`, con 2 síntomas de permisos y 1 bug sembrados.
- `solucion-s2` = `s2-inicio` con 3 correcciones mínimas (un commit cada una), `--json` y la documentación.

Flujo de los alumnos. Trabajan en forks, y los forks se crearon antes de que existiera
`s2-inicio`: no la tienen. Por eso la traen del repositorio del curso como `upstream`
(es la sección "Sesión 2" del README):
```bash
git remote add upstream https://github.com/F-Urquizo/edf-ti-practica.git
git fetch upstream s2-inicio
git checkout -b s2-<nombre> upstream/s2-inicio
git push -u origin s2-<nombre>
git worktree add ../s2-<nombre>-json -b s2/<nombre>/json
git worktree add ../s2-<nombre>-logs -b s2/<nombre>/logs
```

## 1. Lo sembrado

### Síntoma A — Claude no puede hacer commit
En `.claude/settings.json`, dentro de `deny`, mezcladas con las reglas de la Sesión 1:

```json
"deny": [
  "Read(**/.env)",
  "Read(**/.env.*)",
  "Read(**/llaves/**)",
  "Bash(git commit *)",      <- sembrada
  "Read(~/.ssh/**)",
  "Bash(cat .env*)",
  "Bash(git commit)",        <- sembrada
  "Bash(rm -rf *)"
]
```

### Síntoma B — el escáner pregunta siempre aunque está en `allow`
```json
"ask":   [ ..., "Bash(./scripts/*)", ... ],                  <- sembrada
"allow": [ ..., "Bash(./scripts/revisa-secretos.sh)",         <- sembrada
                "Bash(./scripts/revisa-secretos.sh *)" ]      <- sembrada
```

### Bug — `scripts/rota-logs.sh`, línea 25
```bash
done < <(find "$LOGS" -type f -name '*.log' -mtime -"$DIAS")   # sembrado: -N
done < <(find "$LOGS" -type f -name '*.log' -mtime +"$DIAS")   # correcto:  +N
```
`-mtime -7` significa "modificado hace **menos** de 7 días": el script rota los logs
activos y deja los viejos. El comentario de la línea 2 ("con más de 7 días") sigue
diciendo lo correcto: esa contradicción es la pista.

## 2. Mensajes esperados (capturados con Claude Code 2.1.327)

**Síntoma A** (regla `deny`). Sale igual en modo interactivo y en `claude -p`, y no se puede aprobar:
```
Permission to use Bash with command git commit --allow-empty -m 'prueba' has been denied.
```

**Síntoma B** (regla `ask`). En modo interactivo aparece el diálogo de aprobación **cada vez**.
En `claude -p` no hay a quién preguntarle y la llamada falla con:
```
Claude requested permissions to use Bash, but you haven't granted it yet.
```
Si Claude junta comandos (`./scripts/revisa-secretos.sh; echo "EXIT=$?"`), el mensaje es:
```
This Bash command contains multiple operations. The following parts require approval: ./scripts/revisa-secretos.sh, echo "EXIT=$?"
```

**Ya corregido** (`solucion-s2`, commit sin regla). En modo interactivo aparece el diálogo
normal de aprobación. En `claude -p` sale:
```
This command requires approval
```
Con `--allowedTools "Bash(git commit *)"`, o aprobando en el diálogo, el commit se hace.

**Diferencia clave para explicar:** "has been denied" = una regla `deny`, que no se puede
aprobar. "requested permissions… haven't granted it yet" o "requires approval" = `ask` o sin
regla: se puede aprobar.

**Reglas de la Sesión 1** (siguen funcionando en ambas ramas). La herramienta Read responde
para `.env`, `config/.env.produccion` y `llaves/id_practica`:
```
File is in a directory that is denied by your permission settings.
```

**Bug** (copia de `logs/` en una carpeta temporal, con logs recién clonados):
```
Rotado: respaldos-AAAAMMDD.log.gz
Rotado: aplicacion-AAAAMMDD.log.gz
Rotado: accesos-AAAAMMDD.log.gz
Logs rotados: 3
```
El script correcto da `Logs rotados: 0`. Al simular un log viejo con
`touch -t 202609010000 logs/respaldos.log`, el script con el bug rota los otros dos
(`Logs rotados: 2`) y deja `respaldos.log`. El correcto rota solo `respaldos.log` (`Logs rotados: 1`).

## 3. Por qué falla el `allow`

Claude Code evalúa las reglas en orden **deny → ask → allow**, y gana la primera que coincide.
No gana la regla más específica:
- `Bash(git commit *)` en `deny` gana a todo: a un `allow` del proyecto, a uno de
  `settings.local.json`, a `--allowedTools` y a un `Bash(git:*)` en la configuración del usuario.
- `Bash(./scripts/*)` en `ask` coincide con `./scripts/revisa-secretos.sh` antes de llegar al
  `allow`. Por eso el `allow` específico nunca se usa.

Correcciones mínimas en `solucion-s2`:
1. Quitar las dos reglas `git commit` de `deny`. Commit quedará pidiendo aprobación, como antes.
2. Quitar `Bash(./scripts/*)` de `ask`. El escáner corre sin preguntar, y `rota-logs.sh`,
   `respaldo.sh` y `notifica.sh` siguen pidiendo aprobación porque no están en `allow`.

Un `ask` amplio no se puede "perforar" con un `allow` específico. Si se quiere que los demás
scripts sigan preguntando, se listan uno por uno en `ask`
(`Bash(./scripts/rota-logs.sh*)`, etc.).

## 4. Salida esperada de `--json`

```bash
./scripts/revisa-secretos.sh --json; echo "salida: $?"
```
```
[
  {"ruta": "config/.env.produccion", "linea": null, "tipo": "archivo-env"},
  {"ruta": ".env", "linea": null, "tipo": "archivo-env"},
  {"ruta": "llaves/id_practica", "linea": 1, "tipo": "llave-privada"},
  {"ruta": "scripts/notifica.sh", "linea": 10, "tipo": "token-hardcodeado"},
  {"ruta": "config/app.conf", "linea": 16, "tipo": "password-hardcodeado"}
]
salida: 1
```
- El orden de los dos `.env` puede variar según el sistema.
- `linea` es `null` (no `"-"`) para `archivo-env`. Sin hallazgos imprime `[]` y sale con 0.
- Con `--json` no se imprime el encabezado ni el resumen: solo JSON en stdout.
- Sin `--json`, la salida es idéntica byte por byte a la de la Sesión 1.
- Se valida con `python3 -m json.tool` (o `python -m json.tool` en Windows), sin `jq`.
- `--json` puede ir antes o después de la carpeta. Una opción desconocida o dos carpetas dan error y salen con 2.

## 5. Fallas comunes de los alumnos

**Permisos**
- Agregar `"Bash(git commit *)"` a `allow`, o aceptar el "no volver a preguntar": no sirve, el
  `deny` gana. El propio Claude a veces sugiere este arreglo equivocado.
- Agregar más `allow` para el escáner en lugar de quitar el `ask`.
- Arreglarlo en `.claude/settings.local.json`: el `deny` y el `ask` del proyecto siguen ganando.
  Además, ese archivo no se versiona.
- No revisar `~/.claude/settings.json`: las reglas de usuario se combinan con las del proyecto.
- JSON inválido tras editar (coma de más). Revisar con `/permissions` o con `python3 -m json.tool`.
- Pedirle a Claude que corrija `.claude/settings.json`: puede editarlo, pero los cambios de
  permisos aplican mejor al reiniciar la sesión. Verificar con `/permissions`.

**Síntoma A se mezcla con el B.** El `CLAUDE.md` pide correr `revisa-secretos.sh` antes de
cada commit, así que al pedir "haz un commit de prueba" Claude primero intenta el escáner y se
topa con el síntoma B. Para aislar A conviene pedir:
"haz un commit vacío de prueba con `git commit --allow-empty -m prueba`; no corras nada antes".

**`claude -p` y la confianza de la carpeta.** En una carpeta donde nunca se aceptó el diálogo de
confianza, `claude -p` imprime
`Ignoring N permissions.allow entries from .claude/settings.json: this workspace has not been trusted`
y no aplica los `allow` del proyecto. Los `deny` y `ask` sí aplican. Cada worktree es una carpeta
nueva: el diálogo aparece la primera vez que se abre `claude` en ella.

**Bug de rota-logs**
- Ejecutarlo en el repositorio en vez de en una copia: rota los 3 logs versionados.
  Se recupera con `git restore logs/` y borrando `logs/*.gz`.
- "No veo el bug, no rota nada": pasa con el script **corregido** y logs recién clonados.
  Hay que simular un log viejo con `touch -t`.
- Arreglarlo cambiando el `7` o sumando días: el problema es el signo.
- `git diff main` o `git log -p` revelan el bug. Es válido como técnica de
  depuración: comentarlo si alguien lo usa.

**`--json`**
- Imprimir el encabezado o el resumen junto con el JSON: deja de ser JSON válido.
- Coma de más después del último objeto.
- `"linea": "-"` en lugar de `null`.
- Cambiar el código de salida en modo JSON (salir con 0 siempre).
- Usar `jq`: no existe en macOS ni en Git Bash de serie.
- Romper la salida sin `--json` (comparar con `diff` contra la de la Sesión 1).

**Subagente `revisor`**
- Aparece en `/agents` y en la lista de agentes al abrir `claude` en `solucion-s2`. En `s2-inicio` no
  existe: los alumnos lo crean.
- Si ejecuta `git -C /ruta/absoluta diff ...`, el comando no coincide con `Bash(git diff *)` y pide
  aprobación. Por eso el prompt del agente le pide no usar `-C` ni rutas absolutas.
- La restricción "Bash solo para git diff/log/show" está en el prompt: el campo `tools` no limita
  los comandos de Bash. La barrera real siguen siendo las reglas `deny` y `ask` del proyecto.
- Prueba sugerida: una rama con un script que use `declare -A`, un `grep -c` sin `|| true` y un
  `echo` de una variable de contraseña. Debe dar 3 bloqueantes.

**Worktrees**
- Un alumno que ya tiene una rama llamada `s2/<nombre>` no puede crear `s2/<nombre>/json`
  (git no permite una rama y una "carpeta" con el mismo nombre). Con `s2-<nombre>`, con guion, no hay conflicto.
- Crear el worktree dentro del repositorio (`./x` en vez de `../x`): aparece como archivo sin
  seguimiento en `git status`.
- Borrar la carpeta a mano en lugar de `git worktree remove`: queda registrado. Se limpia con `git worktree prune`.
- `claude --worktree <nombre>` (o `-w`) existe en 2.1.327 y crea el worktree por su cuenta.

**Forks, worktrees y revisión**
- Haz commit de la corrección de permisos ANTES de crear los worktrees. Los worktrees parten del
  commit, no de la carpeta: si no, los síntomas reaparecen.
- Desde un fork, `gh pr create` y la página de GitHub abren el PR contra el repo del curso por
  defecto. Usar `--repo <usuario>/edf-ti-practica --base s2-<nombre>`, o cambiar 'base repository'
  en la web.
- Para revisar una rama de worktree, compararla contra `s2-<nombre>`, no contra `main`
  (`git diff s2-<nombre>...s2/<nombre>/json`). Contra `main` sale toda la solución de S1 y los permisos.

## 6. Windows / Git Bash
- Todo se ejecuta en **Git Bash**. En PowerShell o CMD, `find` es el `FIND.EXE` de Windows y
  `rota-logs.sh` falla con errores raros.
- `touch -t`, `find -mtime`, `gzip` y `mktemp -d` existen en Git Bash.
- Los finales de línea quedan en LF gracias a `.gitattributes`. Si alguien ve `$'\r': command not found`,
  clonó antes de que existiera `.gitattributes` o lo editó con un editor que guarda CRLF.
- El bit de ejecución no importa en Git Bash: `./scripts/x.sh` funciona por el shebang.
- Python puede llamarse `python` en lugar de `python3` para validar el JSON.
- Las rutas de los worktrees (`../s2-<nombre>-json`) funcionan igual; evitar espacios en la ruta del repositorio.

## 7. Tiempos sugeridos (Sesión 2)

| Bloque | Minutos |
|--------|---------|
| Repaso de S1 y setup con `upstream` | 10 |
| Parte 1 — candado: síntomas A y B, corregir y commit | 10-15 |
| Parte 2 — `CLAUDE.md` índice, `docs/` y `.claude/rules/` | 20 |
| Parte 3 — worktrees; `--json` en el de json | 20 |
| Parte 4 — revisión en sesión nueva, merge y `git worktree remove` | 15 |
| **Total del laboratorio** | **75-80** |

Avanzado o tarea si no alcanza el tiempo: el bug de `rota-logs` (worktree logs) y el subagente `revisor`.

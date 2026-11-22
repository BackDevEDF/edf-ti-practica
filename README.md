# edf-ti-practica

Repositorio de práctica para las **Sesiones 1 a 3** del curso de Claude Code para el equipo de TI de EDF.

> **Todos los datos de este repositorio son ficticios.** Servidores, usuarios, contraseñas,
> tokens, llaves y logs fueron inventados para el ejercicio. Nada de esto da acceso a
> ningún sistema real de EDF ni de ningún proveedor.

## ¿Qué hay aquí?

Simula el repositorio de scripts operativos de un equipo de TI:

| Ruta | Contenido |
|------|-----------|
| `scripts/respaldo.sh` | Comprime una carpeta en `respaldos/` con la fecha en el nombre. Lee `DB_HOST`, `DB_USER` y `DB_PASSWORD` de variables de entorno. |
| `scripts/rota-logs.sh` | Rota y comprime los logs de `logs/` con más de 7 días. |
| `scripts/notifica.sh` | Envía una notificación con `curl` a un webhook ficticio. |
| `config/app.conf` | Configuración de la aplicación. |
| `docs/inventario-servidores.csv` | Inventario de servidores (ficticio). |
| `logs/` | Logs de ejemplo. |
| `llaves/` | Un par de llaves SSH de práctica que no sirven para nada. |

## ⚠️ Secretos expuestos a propósito

Este repositorio **tiene secretos versionados a propósito**: el archivo `.env` de la raíz,
`config/.env.produccion`, la llave privada de `llaves/` y algunas credenciales escritas
directamente en archivos. Están ahí para que en la práctica construyas una herramienta que
los encuentre.

En un repositorio real, nada de esto debe estar en Git. Si alguna vez ves algo así en un
repo de trabajo: no lo copies, avisa a tu líder y rota la credencial.

## Cómo clonarlo

Funciona en macOS, Linux y Windows (con Git Bash).

```bash
git clone https://github.com/F-Urquizo/edf-ti-practica.git
cd edf-ti-practica
claude
```

En Windows, abre **Git Bash** (no PowerShell ni CMD) para ejecutar los scripts.

## Ejercicios de la Sesión 1

1. Pídele a Claude Code que te explique el repositorio.
2. Crea `.claude/settings.json` con reglas `deny` y comprueba que Claude no puede leer los secretos.
3. En modo plan, pídele a Claude que construya `scripts/revisa-secretos.sh`: un script que
   encuentre secretos expuestos y reporte ruta, línea y tipo, **nunca el valor**.
4. Ejecútalo y encuentra los secretos sembrados.
5. Haz commit del script en una rama nueva y agrega una regla a `CLAUDE.md`.
6. Haz un cambio malo a propósito y deshazlo con `git restore`.

## Sesión 2

Trabajas en tu fork. Trae la rama de inicio desde el repositorio del curso:

```bash
git remote add upstream https://github.com/F-Urquizo/edf-ti-practica.git
git fetch upstream s2-inicio
git checkout -b s2-<tu-nombre> upstream/s2-inicio
git push -u origin s2-<tu-nombre>
```

En Windows, todo en Git Bash.

## Sesión 3

Necesitas Docker. Trae la rama de inicio desde el repositorio del curso y levanta los servicios:

```bash
docker run hello-world
git fetch upstream s3-inicio
git checkout -b s3-<tu-nombre> upstream/s3-inicio
git push -u origin s3-<tu-nombre>
docker compose up -d
docker compose ps
```

Si `upstream` no existe: `git remote add upstream https://github.com/F-Urquizo/edf-ti-practica.git`.

En Windows: Git Bash y Docker Desktop con WSL 2.

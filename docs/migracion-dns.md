# Migración DNS de pixxoae.com

Fecha del inventario: 2026-11-23. Consultado con `dig` (resolver recursivo).
Proveedor actual: **ns1/ns2.eldefiar.com** (SOA serial 2026110601). Proveedor nuevo: por definir.

## 1. Inventario

| Nombre | Tipo | Valor | TTL (s) | ¿Afecta correo? |
|---|---|---|---|---|
| `pixxoae.com` | NS | ns1.eldefiar.com, ns2.eldefiar.com | 172800 | Sí (si falla, falla todo) |
| `pixxoae.com` | A | 216.24.57.1 (Render) | 600 | No |
| `pixxoae.com` | AAAA | — (no existe) | — | No |
| `www` | CNAME | sitio-pixxo.onrender.com | 600 | No |
| `mail` | CNAME | pixxoae.com | 14400 | Probable (si se usa como alias de webmail/cliente) |
| `pixxoae.com` | **MX** | 1 smtp.google.com. | 14400 | **SÍ** |
| `pixxoae.com` | **TXT** SPF | `v=spf1 include:_spf.google.com ~all` | 14400 | **SÍ** |
| `google._domainkey` | **TXT** DKIM | `v=DKIM1;k=rsa;p=MIGf…QIDAQAB` (clave RSA 1024) | 600 | **SÍ** |
| `_dmarc` | **TXT** | `v=DMARC1; p=quarantine; sp=quarantine; adkim=r; aspf=r; pct=50; …; rua/ruf=mailto:soporte.interno@eldefiar.com` | 14400 | **SÍ** |
| `pixxoae.com` | TXT | `apple-domain-verification=tGj8KIdAhyLYeaca` | 14400 | No |
| `pixxoae.com` | TXT | `anthropic-domain-verification-z5ntbs=PClRzlPwrO2BV3E0BAcXyDhcJ` | 14400 | No |
| `pixxoae.com` | TXT | `google-site-verification=rat6b_Okv3DYFxo679vKGCkMfTVtQMsWEIdPTpw9SFM` | 14400 | No (pero Google Workspace puede revalidar) |

Límites del inventario:
- **No se pudo hacer transferencia de zona** (AXFR rechazado), así que solo se consultaron
  nombres conocidos: apex, `www`, `mail`, `autodiscover`, `google._domainkey`, `_dmarc`. Pueden existir
  más subdominios. **Antes de migrar, exportar la zona completa desde el panel actual** y comparar.
- `autodiscover` y otros selectores DKIM no existen en las consultas hechas.
- Sin registros AAAA ni CNAME en el apex (correcto: un CNAME en el apex rompería MX/TXT).
- El SOA negativo es 86400: un registro olvidado y consultado durante la migración queda "inexistente"
  en cachés hasta 24 h.

## 2. Plan por pasos

Regla de oro: **la zona nueva se completa y se verifica ANTES de cambiar los NS**. El cambio de NS es
el último paso y es el único que mueve el tráfico.

### Paso 0 — Preparación (T-7 días)
1. Exportar la zona actual (panel/archivo de zona) y guardarla fuera del proveedor. Es el plan de regreso.
2. Elegir ventana de bajo uso (fin de semana, no cierre de mes) y avisar a quien usa el correo.
3. Verificar acceso al **registrador** (donde se cambian los NS) y al proveedor nuevo. Si ns1/ns2.eldefiar.com
   son servidores propios, confirmar quién los administra.
4. Anotar el valor del TTL de los NS en el registrador/.com: **172800 s (48 h)**. Esto fija el tiempo máximo
   de propagación del paso 5 y no se puede acortar desde la zona.

### Paso 1 — Bajar TTL (T-3 días como mínimo; hacerlo ≥ 48 h antes)
Bajar a **300 s** en el proveedor actual, empezando por los que tienen TTL más alto:
- MX, SPF (TXT), DMARC, TXT de verificación, `mail` → de 14400 a 300.
- A apex, `www`, DKIM → de 600 a 300.

Esperar **al menos el TTL antiguo más alto (14400 s = 4 h)**; por margen, 24–48 h. Registrar la hora.
- Verificar: `dig +noall +answer pixxoae.com MX` repetido — el TTL mostrado debe bajar hasta ≤ 300
  (consultar varias veces y a `@8.8.8.8` y `@1.1.1.1`).
- Regreso: nada que revertir; solo subir TTL otra vez.

### Paso 2 — Crear la zona completa en el proveedor nuevo (sin cambiar NS)
Copiar **todos** los registros de la tabla (y los que aparezcan en el export). Orden recomendado:
1. **Correo primero** (lo más sensible): MX, SPF, DKIM (`google._domainkey`), DMARC. Copiar los valores
   **idénticos**, sin reformatear. Cuidado con TXT largos: algunos paneles parten el DKIM en trozos de 255
   caracteres o agregan comillas de más.
2. TXT de verificación (apple, anthropic, google-site-verification).
3. Web: A apex y CNAME `www`.
4. `mail` y cualquier otro subdominio del export.
Poner TTL 300 en la zona nueva también.

### Paso 3 — Verificar la zona nueva contra sus servidores (antes de migrar)
Con los NS del proveedor nuevo (`NS_NUEVO`):
```
dig +noall +answer @NS_NUEVO pixxoae.com A
dig +noall +answer @NS_NUEVO www.pixxoae.com CNAME
dig +noall +answer @NS_NUEVO pixxoae.com MX
dig +noall +answer @NS_NUEVO pixxoae.com TXT
dig +noall +answer @NS_NUEVO google._domainkey.pixxoae.com TXT
dig +noall +answer @NS_NUEVO _dmarc.pixxoae.com TXT
dig +noall +answer @NS_NUEVO mail.pixxoae.com CNAME
```
Comparar contra el mismo comando con `@ns1.eldefiar.com`. **Deben ser idénticos** (salvo TTL). Una forma
rápida: guardar ambas salidas y hacer `diff`.
- Si algo difiere: corregir en el proveedor nuevo; no avanzar.
- Regreso: nada que revertir, la zona nueva aún no recibe tráfico.

### Paso 4 — Prueba funcional previa (opcional pero recomendada)
Apuntar un resolver de prueba a `NS_NUEVO` no es posible directamente; basta la comparación del paso 3 más
revisar en Google Admin Toolbox (Check MX) que el MX es válido.

### Paso 5 — Cambiar los NS en el registrador
1. Reemplazar ns1/ns2.eldefiar.com por los NS del proveedor nuevo.
2. **No apagar ni borrar la zona vieja**: durante hasta 48 h parte de los resolvers seguirá consultándola.
3. Verificar:
   - `dig +short NS pixxoae.com @a.gtld-servers.net` (o `dig +trace pixxoae.com NS`) → debe mostrar los NS nuevos.
   - `dig +short NS pixxoae.com @8.8.8.8` y `@1.1.1.1` → NS nuevos (puede tardar hasta 48 h).
4. **Regreso rápido:** volver a poner ns1/ns2.eldefiar.com en el registrador. Funciona mientras la zona vieja
   siga intacta, y el tiempo de efecto es otra vez hasta 48 h (TTL de NS).

### Paso 6 — Verificación de servicios (primeras 2 h y a las 24 h)
| Qué | Cómo | Esperado |
|---|---|---|
| Web | `curl -I https://pixxoae.com` y `https://www.pixxoae.com` | 200/30x, certificado válido |
| MX | `dig +short pixxoae.com MX` | `1 smtp.google.com.` |
| SPF | `dig +short pixxoae.com TXT` | contiene `v=spf1 include:_spf.google.com ~all` |
| DKIM | `dig +short google._domainkey.pixxoae.com TXT` | clave completa, sin cortes |
| DMARC | `dig +short _dmarc.pixxoae.com TXT` | política igual a la anterior |
| Correo real | Enviar y recibir con una cuenta @pixxoae.com desde/hacia Gmail externo; revisar encabezados: `spf=pass dkim=pass dmarc=pass` | pass/pass/pass |
| Reportes DMARC | revisar buzón `soporte.interno@eldefiar.com` | sin picos de fallos |

Si el correo falla: **regresar de inmediato los NS (paso 5.4)**; el correo rebotado por 4xx se reintenta, pero
5xx/DMARC reject se pierde.

### Paso 7 — Cierre (a partir de T+3 días, con todo estable)
1. Subir TTL a valores normales (MX/TXT 3600–14400, A/CNAME 3600).
2. Mantener la zona vieja **7 días más**, luego eliminarla.
3. Actualizar `docs/servidores.md` si ns1/ns2.eldefiar.com dejan de ser autoritativos.

## 3. Registros que afectan el correo (resumen)

1. **MX** `1 smtp.google.com.` — sin él no llega correo.
2. **SPF** TXT apex — sin él, el correo saliente cae en spam.
3. **DKIM** `google._domainkey` — sin él, DKIM falla y DMARC depende solo de SPF.
4. **DMARC** `_dmarc` — con `p=quarantine`, si SPF/DKIM faltan durante la migración, el correo se va a cuarentena.
5. **`mail` CNAME → apex** — revisar si algún cliente lo usa; si se mueve el apex, `mail` sigue al A.
6. **NS** — indirectamente todo, porque quien responda MX/TXT es quien mande.
7. TXT `google-site-verification` — no entrega correo, pero Google Workspace puede revalidar el dominio.

Observaciones aparte (no bloquean la migración):
- La clave DKIM es RSA de 1024 bits; Google recomienda 2048. Mejor rotarla **después**, no durante la migración.
- DMARC con `pct=50` aplica la política solo al 50 % del correo fallido.

## 4. Plan de regreso (resumen)

| Si falla… | Acción | Tiempo de efecto |
|---|---|---|
| Un registro mal copiado en la zona nueva (antes del paso 5) | Corregirlo; no se ha movido tráfico | inmediato |
| Después de cambiar NS | Volver los NS a ns1/ns2.eldefiar.com (zona vieja intacta) | hasta 48 h |
| Registro puntual equivocado en la zona nueva ya activa | Corregirlo en la zona nueva (TTL 300) | ~5 min |
| Se perdió la zona vieja | Reimportar desde el export del paso 0 | — |

Por eso: no borrar la zona vieja ni subir TTL hasta cerrar el paso 7.

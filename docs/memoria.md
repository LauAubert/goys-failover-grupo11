# Memoria del Laboratorio — Failover Routing

**Grupo:** 11
**Materia:** Gestión Operativa y Seguridad en Redes (GOYS) — UTN FR La Plata
**Fecha de entrega:** viernes 23/10/2026

## Integrantes y roles

> Grupo de 4 integrantes: los roles R2 y R3 los cubre la misma persona.

| Integrante | Rol |
|-----------|-----|
| Santiago Natalichio Bestosini | R1 — Líder / Edge-WAN |
| Tomás Martin | R2 — Proveedores |
| Tomás Martin | R3 — Core |
| Juan Bautista Cuenca | R4 — Distribución |
| Lautaro Aubert | R5 — Hosts / QA / Operación |

---

## 1. Diseño (F0)

### 1.1 Corrección del diagrama

Partimos del diagrama "Enterprise Network Design (Cisco)" que vimos en clase y de los defectos que le encontramos (`analisis.md`). Estos son los que corregimos en nuestro diseño:

| # | Defecto detectado | Corrección aplicada | Justificación |
|:-:|-------------------|---------------------|---------------|
| 1 | Hay un solo firewall. Si se rompe, toda la empresa se queda sin Internet, aunque tenga dos proveedores. | En el lab no armamos un firewall aparte (las reglas de filtrado van en el router EDGE). Dejamos documentado que en una red real tienen que ir dos firewalls, uno activo y otro de respaldo. | De nada sirve tener dos ISPs si todo el tráfico pasa por un único equipo que puede fallar. Lo que está en el camino crítico tiene que estar duplicado. |
| 2 | Hay redes repetidas: la misma dirección (192.168.10.0/24) aparece en dos sitios distintos. | Armamos un plan de direcciones donde cada enlace y cada red tiene un rango propio que no se repite (sección 1.2). | Si dos redes tienen la misma dirección, los routers no pueden distinguirlas y una de las dos queda inalcanzable. Por eso el plan de IPs se define antes de configurar nada. |
| 3 | Los dos routers del core (CORE-1 y CORE-2) no están conectados entre sí. | Agregamos el cable CORE-1 ↔ CORE-2. | Si se corta el enlace entre el EDGE y CORE-1, CORE-1 queda sin salida. Con el cable core–core puede seguir mandando el tráfico por CORE-2. Es lo que hace que OSPF pueda recalcular la ruta en el drill 2. |
| 4 | La puerta de enlace de las PCs (HSRP) está en el core, que debería ser solo un "pasillo" de tránsito. Además HSRP es propietario de Cisco. | Movemos la puerta de enlace redundante a los routers de distribución (DIST-1 y DIST-2) y usamos VRRP, que es el estándar abierto. El core queda solo con OSPF. | En una red jerárquica cada capa hace una cosa: distribución es la puerta de enlace de las PCs, el core solo mueve tráfico rápido. Mezclar las dos cosas complica el core. Y usamos VRRP porque funciona con cualquier marca (nuestros routers son MikroTik, no Cisco). |
| 5 | El diagrama pone un Route Reflector de iBGP cruzando el firewall, algo que no corresponde y que a esta escala no hace falta. | El router EDGE habla eBGP directamente con los dos ISPs. Sin Route Reflector. | Un Route Reflector sirve cuando hay muchos routers BGP internos. Nosotros tenemos uno solo (el EDGE), así que agregarlo es sumar algo que puede fallar sin ningún beneficio. |

Otros problemas que tiene el diagrama y que quedan fuera del alcance del lab (voz sin QoS, falta de VLAN de gestión y de protecciones en los switches): los dejamos anotados pero no los implementamos.

### 1.2 Plan de direccionamiento (IPAM)

**Convención general:**

| Bloque | Uso | Regla |
|--------|-----|-------|
| `10.0.0.0/24` | Enlaces punto a punto internos (EDGE/CORE/DIST) | Un **/30** por enlace, asignados de a 4 (`.0`, `.4`, `.8`, …). Extremo "superior" en la jerarquía toma la IP impar menor. |
| `10.10.0.0/24` | LAN **USERS** | Gateway virtual VRRP `.1`, DIST-1 `.2`, DIST-2 `.3`, hosts desde `.100` |
| `10.20.0.0/24` | LAN **SERVERS** | Gateway virtual VRRP `.1`, DIST-1 `.2`, DIST-2 `.3`, hosts desde `.100` |
| `10.255.255.0/24` | Loopbacks internos = **router-id** OSPF/BGP | Un **/32** por router |
| `203.0.113.0/24` | Enlaces EDGE ↔ ISP (simula direccionamiento público) | Un **/30** por ISP |
| `198.51.100.0/24` | Loopbacks de los ISP (simulan "Internet") | Un **/32** por ISP; es el destino que deben alcanzar los hosts |

> `203.0.113.0/24` y `198.51.100.0/24` son rangos reservados para documentación (RFC 5737): nunca colisionan con Internet real ni con redes privadas.

**Tabla de enlaces y LANs (15 enlaces, 11 nodos):**

| # | Enlace / Red | Subred | Dispositivo A (IP / iface) | Dispositivo B (IP / iface) |
|:-:|--------------|:------:|----------------------------|----------------------------|
| 1 | ISP-1 ↔ EDGE | `203.0.113.0/30` | ISP-1 `203.0.113.1/30` ether1 | EDGE `203.0.113.2/30` ether1 |
| 2 | ISP-2 ↔ EDGE | `203.0.113.4/30` | ISP-2 `203.0.113.5/30` ether1 | EDGE `203.0.113.6/30` ether2 |
| 3 | EDGE ↔ CORE-1 | `10.0.0.0/30` | EDGE `10.0.0.1/30` ether3 | CORE-1 `10.0.0.2/30` ether1 |
| 4 | EDGE ↔ CORE-2 | `10.0.0.4/30` | EDGE `10.0.0.5/30` ether4 | CORE-2 `10.0.0.6/30` ether1 |
| 5 | CORE-1 ↔ CORE-2 (core–core) | `10.0.0.8/30` | CORE-1 `10.0.0.9/30` ether2 | CORE-2 `10.0.0.10/30` ether2 |
| 6 | CORE-1 ↔ DIST-1 | `10.0.0.12/30` | CORE-1 `10.0.0.13/30` ether3 | DIST-1 `10.0.0.14/30` ether1 |
| 7 | CORE-2 ↔ DIST-1 | `10.0.0.16/30` | CORE-2 `10.0.0.17/30` ether3 | DIST-1 `10.0.0.18/30` ether2 |
| 8 | CORE-1 ↔ DIST-2 | `10.0.0.20/30` | CORE-1 `10.0.0.21/30` ether4 | DIST-2 `10.0.0.22/30` ether1 |
| 9 | CORE-2 ↔ DIST-2 | `10.0.0.24/30` | CORE-2 `10.0.0.25/30` ether4 | DIST-2 `10.0.0.26/30` ether2 |
| 10 | DIST-1 ↔ SW-USERS | `10.10.0.0/24` | DIST-1 `10.10.0.2/24` ether3 | SW-USERS (L2, sin IP) |
| 11 | DIST-2 ↔ SW-USERS | `10.10.0.0/24` | DIST-2 `10.10.0.3/24` ether3 | SW-USERS (L2, sin IP) |
| 12 | DIST-1 ↔ SW-SERVERS | `10.20.0.0/24` | DIST-1 `10.20.0.2/24` ether4 | SW-SERVERS (L2, sin IP) |
| 13 | DIST-2 ↔ SW-SERVERS | `10.20.0.0/24` | DIST-2 `10.20.0.3/24` ether4 | SW-SERVERS (L2, sin IP) |
| 14 | SW-USERS ↔ PC-USER | `10.10.0.0/24` | SW-USERS (L2) | PC-USER `10.10.0.100/24` gw `10.10.0.1` |
| 15 | SW-SERVERS ↔ SRV | `10.20.0.0/24` | SW-SERVERS (L2) | SRV `10.20.0.100/24` gw `10.20.0.1` |

> Los enlaces 10–13 comparten la misma LAN (/24) porque los dos DIST son miembros del mismo dominio de broadcast a través del switch; **no es solapamiento**, es la misma red vista desde dos routers (requisito de VRRP). La numeración de interfaces (`etherN`) se verificará contra el proyecto GNS3 provisto en F1 y se corregirá en esta tabla si difiere, vía change log.

**VRRP (load-sharing entre grupos):**


**Loopbacks / Router-IDs:**

| Nodo | AS | Loopback (= router-id OSPF y BGP) |
|------|:--:|:---------------------------------:|
| ISP-1 | 65001 | `198.51.100.1/32` |
| ISP-2 | 65002 | `198.51.100.2/32` |
| EDGE | 65000 | `10.255.255.1/32` |
| CORE-1 | — (OSPF) | `10.255.255.2/32` |
| CORE-2 | — (OSPF) | `10.255.255.3/32` |
| DIST-1 | — (OSPF) | `10.255.255.4/32` |
| DIST-2 | — (OSPF) | `10.255.255.5/32` |

**Protocolos por enlace:**

| Enlace | Protocolo |
|--------|-----------|
| ISP-1 ↔ EDGE, ISP-2 ↔ EDGE | eBGP (TCP-MD5). Los ISP anuncian default-route (`default-originate`); el EDGE anuncia 10.10.0.0/24 y 10.20.0.0/24 (redistribuidas desde OSPF). |
| EDGE ↔ CORE-x, CORE-1 ↔ CORE-2, CORE-x ↔ DIST-x | OSPF área 0, autenticación MD5. El EDGE inyecta la default en OSPF. |
| LAN USERS / SERVERS | VRRP con autenticación. Interfaces pasivas en OSPF (se anuncia la red pero no se forman vecinos hacia los hosts). |

**Verificación de no solapamiento:** 9 enlaces /30 (7 dentro de `10.0.0.0/24` ocupando `.0`–`.27`, 2 en `203.0.113.0/24`), 2 LANs /24 distintas, 7 loopbacks /32 distintos en dos bloques separados. Ningún prefijo contiene a otro.

### 1.3 Política de seguridad

**Usuarios y privilegios (idéntico en los 7 routers):**

| Usuario | Grupo RouterOS | Permisos | Uso |
|---------|----------------|----------|-----|
| `admin` | `full` | Lectura, escritura, reboot, políticas | Único usuario con permiso de cambio. Contraseña fuerte (≥ 14 caracteres, mayúsculas, minúsculas, números y símbolos), distinta de la de fábrica (CHR viene sin password). |
| `monitor` | `read` | Solo lectura | Usado para verificaciones, drills y monitoreo. **No puede modificar nada**. Es el usuario con el que R5 ejecuta los chequeos. |

- Se elimina cualquier otro usuario por defecto. No se crean usuarios personales adicionales: la trazabilidad de **quién** cambió **qué** se obtiene del change log + los commits de git firmados por cada rol, no de usuarios locales.
- Login remoto solo con `admin` para cambios aprobados en el change log, y con `monitor` para todo lo demás.

**Servicios que se deshabilitan (`/ip service`):**

| Servicio | Estado | Motivo |
|----------|:------:|--------|
| `telnet` | **disabled** | Texto plano, credenciales visibles en la red |
| `ftp` | **disabled** | Texto plano; los backups se extraen por SSH/SCP |
| `www` (HTTP) | **disabled** | Texto plano |
| `api`, `api-ssl` | **disabled** | No se usa automatización por API en este lab |
| `www-ssl` | **disabled** | No se usa WebFig |
| `ssh` (22) | habilitado | Gestión por CLI. Restringido con `address=` a las redes de gestión (loopbacks `10.255.255.0/24` y LAN SERVERS `10.20.0.0/24`). |
| `winbox` (8291) | habilitado | Gestión GUI. Misma restricción de `address=`. |

Además: `/tool mac-server set allowed-interface-list=none`, `/tool mac-server mac-winbox set allowed-interface-list=none`, `/ip neighbor discovery-settings set discover-interface-list=none` en las interfaces hacia los ISP, `/tool bandwidth-server set enabled=no`, y `/ip dns` sin `allow-remote-requests`.

**Claves de autenticación del plano de control (claves de laboratorio):**

| Protocolo | Mecanismo | Clave | Dónde |
|-----------|-----------|-------|-------|
| OSPF | MD5, key-id 1 | `G0ys-0spf-2026` | Todas las interfaces OSPF activas (EDGE↔CORE, CORE↔CORE, CORE↔DIST) |
| BGP (ISP-1) | TCP-MD5 | `G0ys-Bgp-Isp1` | Sesión EDGE ↔ ISP-1, configurada en ambos extremos |
| BGP (ISP-2) | TCP-MD5 | `G0ys-Bgp-Isp2` | Sesión EDGE ↔ ISP-2, configurada en ambos extremos |
| VRRP grupo 10 | simple (máx. 8 caracteres en RouterOS) | `Vrrp10Us` | DIST-1 y DIST-2, interfaz hacia USERS |
| VRRP grupo 20 | simple | `Vrrp20Sv` | DIST-1 y DIST-2, interfaz hacia SERVERS |

- Claves **distintas por protocolo y por sesión BGP**, para que comprometer una no comprometa las otras.
- La prueba obligatoria de F4 (adyacencia/sesión con clave incorrecta **debe fallar**) se ejecuta cambiando una sola de estas claves en un extremo.
- Son claves de laboratorio; en producción se gestionarían en un gestor de secretos y no se versionarían en el repo.

**Firewall en el EDGE (se implementa en F3, se define aquí):**
- `input`: aceptar `established,related`; aceptar SSH/Winbox solo desde redes de gestión; aceptar BGP (TCP/179) solo desde las IPs de los ISP; aceptar OSPF (proto 89) solo desde las redes de enlace internas; aceptar ICMP limitado; **drop** el resto.
- `forward`: aceptar `established,related` y tráfico saliente desde las LAN; drop de conexiones nuevas entrantes desde los ISP hacia las LAN.

### 1.4 Política de operación

**Formato del change log (gestión de cambios):**

Cada cambio en la red queda registrado en **dos lugares que deben coincidir**:

1. **Commit en git**, con la convención *Conventional Commits* del enunciado:

   ```
   tipo(alcance): descripción breve
   ```

   | Tipo | Uso |
   |------|-----|
   | `feat` | Nueva configuración o feature (`feat(vrrp): agrego vrid 10 en DIST-1`) |
   | `fix` | Corrección de algo roto (`fix(ospf): corrijo auth-key en CORE-2`) |
   | `docs` | Memoria, diagramas, runbooks (`docs(memoria): completo IPAM`) |
   | `ops` | Operación: backups, change log (`ops(backup): backup post-F2`) |
   | `chore` | Mantenimiento del repo (`chore: estructura inicial`) |

   Alcances válidos: `ipam`, `diagrama`, `seguridad`, `operacion`, `repo`, `backlog`, `memoria`, `edge`, `isp1`, `isp2`, `core1`, `core2`, `dist1`, `dist2`, `ospf`, `bgp`, `vrrp`, `firewall`, `hosts`, `backup`, `runbook`, `capturas`, `diseno` (diseño general de F0), `changelog` (tabla 6.1).

2. **Fila en la tabla de change log** (sección 6.1 de esta memoria):

   | Fecha | Responsable | Cambio | Motivo | Cómo se revierte |
   |-------|-------------|--------|--------|------------------|

   - **Fecha:** `YYYY-MM-DD`.
   - **Responsable:** rol (R1…R5) + nombre.
   - **Cambio:** qué se hizo, referenciando el hash del commit.
   - **Motivo:** qué feature/tarea del backlog lo pide.
   - **Cómo se revierte:** comando o backup a restaurar.

**Reglas:** un commit por cambio lógico; cada rol commitea su parte (trazabilidad por autor); `main` siempre funcional; ningún cambio en un router sin su fila en el change log; R5 es el dueño del change log y verifica semanalmente que coincida con `git log`.

**Política de backup:**

| Qué | Cuándo | Cómo | Dónde |
|-----|--------|------|-------|
| Export de configuración en texto | **Antes y después** de cada cambio en un router, y al cierre de cada epic (F1…F4) | `/export file=<ROUTER>-<YYYYMMDD>-<etiqueta>` (ej. `DIST-1-20261009-postF1`) | `backups/<YYYY-MM-DD>/<ROUTER>.rsc` en el repo, commit `ops(backup): …` |
| Backup binario | Al cierre de cada epic | `/system backup save name=<ROUTER>-<YYYYMMDD>` | `backups/<YYYY-MM-DD>/<ROUTER>.backup` |
| Snapshot GNS3 | BASE (post-F1), y al cierre de F2/F3 y F4 | Snapshot del proyecto GNS3 con nombre `BASE`, `F2F3`, `F4` | Local de cada integrante (no se versiona por tamaño) |
| **Restore probado** | Una vez en F1 (BASE) y una vez en F4 | `/system reset-configuration` → `/import <archivo>.rsc` en un router de prueba; verificar con `/export` que coincide | Evidencia en sección 6.2 |

- Los `.rsc` **nunca** incluyen contraseñas de usuario (RouterOS no las exporta) y se revisan antes de commitear para no filtrar las claves MD5 de producción (en el lab se aceptan por ser claves de laboratorio).
- Responsable: R5. Verificación: cada backup debe poder hacer `/import` sin errores.

---

## 2. Topología

> Pegar acá la captura del proyecto GNS3 con las 5 capas identificadas (F1). Diagrama lógico de diseño en `docs/diagramas/topologia.md`.

```
[INTERNET] [EDGE] [CORE] [DISTRIBUTION] [ACCESS]
<!-- insertar diagrama/captura en F1 -->
```

---

## 3. Configuración

> Un bloque por dispositivo. Se puede referenciar el archivo `.rsc` del repo y pegar el contenido final. (F1–F3)

### 3.1 ISP-1
```routeros
<!-- config final -->
```

### 3.2 ISP-2
```routeros
<!-- config final -->
```

### 3.3 EDGE
```routeros
<!-- config final -->
```

### 3.4 CORE-1
```routeros
<!-- config final -->
```

### 3.5 CORE-2
```routeros
<!-- config final -->
```

### 3.6 DIST-1
```routeros
<!-- config final -->
```

### 3.7 DIST-2
```routeros
<!-- config final -->
```

### 3.8 Hosts (PC-USER / SRV)
```bash
<!-- config final de los hosts -->
```

---

## 4. Verificación

### 4.1 Conectividad básica

| Prueba | Comando | Resultado |
|--------|---------|-----------|
| ping intra-LAN (PC-USER ↔ SRV) | <!-- --> | <!-- --> |
| traceroute a ISP (loopback) | <!-- --> | <!-- --> |

> Pegar capturas de las tablas: `/routing/route/print`, `/interface/vrrp/print`, `/routing/bgp/session/print`.

### 4.2 Los 5 drills de failover

> Para cada drill, documentar con la estructura **detección → respuesta → recuperación → post-mortem** y el **tiempo medido**. (F4)

#### Drill 1 — VRRP: se cae el gateway
- **Detección:** <!-- -->
- **Respuesta:** <!-- -->
- **Recuperación:** <!-- -->
- **Tiempo medido:** <!-- -->
- **Post-mortem** (¿por qué funcionó? ¿qué aprendieron?): <!-- -->

#### Drill 2 — OSPF: se corta el camino interno
- **Detección:** <!-- -->
- **Respuesta:** <!-- -->
- **Recuperación:** <!-- -->
- **Tiempo medido:** <!-- -->
- **Post-mortem:** <!-- -->

#### Drill 3 — BGP: se cae el proveedor
- **Detección:** <!-- -->
- **Respuesta:** <!-- -->
- **Recuperación:** <!-- -->
- **Tiempo medido:** <!-- -->
- **Post-mortem:** <!-- -->

#### Drill 4 — check-gateway: failover estático de enlace
- **Detección:** <!-- -->
- **Respuesta:** <!-- -->
- **Recuperación:** <!-- -->
- **Tiempo medido:** <!-- -->
- **Post-mortem:** <!-- -->

#### Drill 5 — Load-sharing VRRP: ambos DIST activos
- **Detección:** <!-- -->
- **Respuesta:** <!-- -->
- **Recuperación:** <!-- -->
- **Post-mortem:** <!-- -->

---

## 5. Seguridad aplicada

| Mecanismo | Dónde se aplicó | Verificación (¿cómo probaron que funciona?) |
|-----------|-----------------|---------------------------------------------|
| Hardening (usuarios/servicios) | <!-- --> | <!-- --> |
| OSPF MD5 | <!-- --> | <!-- --> |
| BGP TCP-MD5 | <!-- --> | <!-- --> |
| VRRP auth | <!-- --> | <!-- --> |
| Firewall/ACL (edge) | <!-- --> | <!-- --> |

> Prueba de seguridad obligatoria: adyacencia OSPF / sesión BGP debe **fallar** con clave incorrecta. Documentar el resultado.

---

## 6. Gestión operativa

### 6.1 Change log

| Fecha | Responsable | Cambio | Motivo | Cómo se revierte |
|-------|-------------|--------|--------|------------------|
| `<fecha>` | R5 — Lautaro Aubert | `<hash>` `chore(repo): estructura inicial del repositorio` | Epic F0 — Repositorio git | `git revert <hash>` |
| `<fecha>` | R1 — Santiago Natalichio Bestosini | `<hash>` `docs(ipam): plan de direccionamiento, política de operación y diagrama lógico` | Epic F0 — IPAM y política de operación | `git revert <hash>` |
| `<fecha>` | R2/R3 — Tomás Martin | `<hash>` `docs(diseno): corrección del diagrama viral y política de seguridad` | Epic F0 — Corrección del diagrama y política de seguridad | `git revert <hash>` |
| `<fecha>` | R4 — Juan Bautista Cuenca | `<hash>` `docs(ipam): grupos VRRP con load-sharing` | Epic F0 — IPAM (grupos VRRP) | `git revert <hash>` |
| `<fecha>` | R5 — Lautaro Aubert | `<hash>` `docs(operacion): backlog inicial con F0` | Epic F0 — Repositorio git (backlog) | `git revert <hash>` |

> Esta tabla se completa con el commit `ops(changelog): registro de commits F0` (R5), que por eso no aparece en ella: un commit no puede contener su propio hash.


### 6.2 Backups

> Evidencia de backup (`/export` + `/system backup save`) y de **restore probado**. (F1 en adelante)

<!-- pegar evidencia -->

### 6.3 Monitoreo

> Qué se monitorea (enlaces, vecinos OSPF, sesiones BGP, VRRP) y con qué (SNMP, chequeos). (F4)

<!-- -->

---

## 7. Capturas

> Listar o enlazar la carpeta de capturas (drills, tablas, failover).

<!-- -->

---

## 8. Conclusiones y lecciones aprendidas

> Post-mortem global: qué salió bien, qué fue difícil, qué harían distinto.

<!-- -->

---

## 9. Referencias

- RFC 5798 — VRRP v3 · RFC 2281 — HSRP · RFC 2328 — OSPF v2 · RFC 4271 — BGP-4 · RFC 2385 — TCP-MD5 · RFC 5737 — IPv4 Address Blocks Reserved for Documentation
- Halabi, S. (2000). *Internet Routing Architectures* (multi-homing)
- Doyle & Carroll (2005). *Routing TCP/IP, Vol. I* (IGP, FHRP)
- MikroTik Wiki — VRRP, BGP, OSPF, check-gateway, Securing your router
- Análisis del diagrama viral (`analisis.md`, material de cátedra)

---

## 10. Checklist de entrega

### Diseño (F0)
- [x] IPAM completo y sin solapamiento
- [x] Corrección del diagrama justificada (≥ 3 defectos)
- [x] Política de seguridad definida (usuarios, servicios, claves)
- [x] Política de operación definida (change log + backup)

### Redes
- [ ] 7 CHR + 2 switches + 2 hosts levantados y cableados
- [ ] VRRP operativo (2 grupos, load-sharing)
- [ ] OSPF área 0 con adyacencias (incluido core–core)
- [ ] BGP eBGP ×2 establecido (multi-homing)
- [ ] Los 5 drills ejecutados y documentados (runbook + post-mortem + tiempo)

### Seguridad
- [ ] Hardening aplicado (password, usuario mínimo, servicios apagados)
- [ ] OSPF MD5 funcionando
- [ ] BGP TCP-MD5 funcionando
- [ ] VRRP auth funcionando
- [ ] Firewall edge aplicado
- [ ] Prueba con clave incorrecta → debe **fallar** (documentado)

### Operación
- [ ] Change log completo (refleja los commits del repo)
- [ ] Backups con restore probado
- [ ] Monitoreo habilitado y documentado
- [ ] Runbook por drill + post-mortem global

### Entrega
- [ ] Memoria completa (todas las secciones de esta plantilla)
- [x] Repo git con la estructura correcta y commits por rol
- [ ] `backlog.md` con todas las tareas en "done"
- [ ] Capturas en la carpeta `capturas/`
- [ ] Cada integrante puede defender su parte **y** una parte ajena

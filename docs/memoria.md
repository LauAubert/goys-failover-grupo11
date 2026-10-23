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

| Grupo | VRID | Master | Backup | Priority (master / backup) | IP virtual | Auth |
|-------|:----:|:------:|:------:|:--------------------------:|:----------:|------|
| USERS (`10.10.0.0/24`) | **10** | DIST-1 | DIST-2 | 200 / 100 | `10.10.0.1/32` | simple, ver 1.3 |
| SERVERS (`10.20.0.0/24`) | **20** | DIST-2 | DIST-1 | 200 / 100 | `10.20.0.1/32` | simple, ver 1.3 |

> Con DIST-1 master del grupo 10 y DIST-2 master del grupo 20, **ambos routers trabajan en simultáneo** (drill 5) y cada uno respalda al otro (drill 1).

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

**Destino de prueba de los drills (agregado en F4):** `192.0.2.1/32`, configurado **en los dos ISP** sobre una interfaz `internet-test` (bridge sin puertos, igual que el loopback). Representa un servidor de Internet que se alcanza por cualquiera de los dos proveedores. A diferencia de los loopbacks, **no se anuncia por BGP** (no está en la lista `anuncio-bgp`), así que el EDGE no tiene una ruta propia hacia ella y la alcanza solo por la ruta por defecto activa: el ping a `192.0.2.1` lo responde el ISP por el que sale la empresa. Hace falta para los drills 3 y 4: el ping a `198.51.100.1` o `198.51.100.2` no sirve para medir el cambio de proveedor, porque cada loopback se alcanza siempre por su propio ISP (ver 4.1). Es del mismo rango reservado para documentación (RFC 5737) que el resto del diseño.

**Protocolos por enlace:**

| Enlace | Protocolo |
|--------|-----------|
| ISP-1 ↔ EDGE, ISP-2 ↔ EDGE | eBGP (TCP-MD5). Los ISP anuncian default-route (`default-originate`) y su propio loopback /32 (agregado en F3, ver 4.1); el EDGE anuncia 10.10.0.0/24 y 10.20.0.0/24 (redistribuidas desde OSPF). |
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

**Cliente DHCP de fábrica (agregado en F1):** el CHR trae de fábrica un cliente DHCP en `ether1` con `add-default-route=yes`. Se elimina en los 7 routers con `/ip dhcp-client remove [find]`: el diseño usa solo direcciones estáticas, y ese cliente aceptaría una dirección y una ruta por defecto de cualquier servidor DHCP que le respondiera (en el EDGE, `ether1` es el enlace hacia ISP-1). Como `/system reset-configuration` lo vuelve a crear, también se quita después de cada restore (ver 6.2).

**Claves de autenticación del plano de control:**

| Protocolo | Mecanismo | Clave | Dónde |
|-----------|-----------|-------|-------|
| OSPF | MD5, key-id 1 | `<CLAVE_OSPF>` | Todas las interfaces OSPF activas (EDGE↔CORE, CORE↔CORE, CORE↔DIST) |
| BGP (ISP-1) | TCP-MD5 | `<CLAVE_BGP_ISP1>` | Sesión EDGE ↔ ISP-1, configurada en ambos extremos |
| BGP (ISP-2) | TCP-MD5 | `<CLAVE_BGP_ISP2>` | Sesión EDGE ↔ ISP-2, configurada en ambos extremos |
| VRRP grupo 10 | simple (máx. 8 caracteres en RouterOS) | `<CLAVE_VRRP_10>` | DIST-1 y DIST-2, interfaz hacia USERS |
| VRRP grupo 20 | simple | `<CLAVE_VRRP_20>` | DIST-1 y DIST-2, interfaz hacia SERVERS |

- Claves **distintas por protocolo y por sesión BGP**, para que comprometer una no comprometa las otras.
- La prueba obligatoria de F4 (adyacencia/sesión con clave incorrecta **debe fallar**) se ejecuta cambiando una sola de estas claves en un extremo.

**Gestión de secretos (dónde viven las claves reales):**

- Las claves reales (`admin`, `monitor`, OSPF, BGP y VRRP) **no se escriben en el repo**: ni en esta memoria, ni en los `.rsc`, ni en los mensajes de commit. En su lugar se usan los marcadores de la tabla anterior (`<CLAVE_OSPF>`, `<CLAVE_BGP_ISP1>`, …) y `<CLAVE_ADMIN>` / `<CLAVE_MONITOR>` para los usuarios.
- El gestor de secretos del grupo es **KeePassXC**: una base cifrada (`.kdbx`) que se comparte entre los cuatro integrantes por fuera del repo, con una contraseña maestra que no se escribe en ningún lado. La base se crea antes de configurar la primera clave de F2 (tarea en `backlog.md`); hasta entonces, las claves de `admin` y `monitor` definidas en F1 las custodia R1 fuera del repo.
- Antes de commitear un `/export` se revisa que no tenga claves; si las tiene, se reemplazan por el marcador correspondiente.
- Las claves de laboratorio que figuraban en esta tabla en F0 quedaron en el historial de git, así que se consideran expuestas y **no se usan**. En F2 y F3 se configuran claves nuevas, que solo existen en los routers y en el gestor.
- Los backups binarios (`.backup`) incluyen usuarios y contraseñas, por lo que tampoco se versionan (ver 1.4).

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
| Backup binario | Al cierre de cada epic | `/system backup save name=<ROUTER>-<YYYYMMDD>-<etiqueta>` (ej. `EDGE-20261010-F1`) | Dentro del router (`/file`). **No se versiona**: incluye usuarios y contraseñas (ver 1.3) |
| Snapshot GNS3 | BASE (post-F1), y al cierre de F2/F3 y F4 | Snapshot del proyecto GNS3 con nombre `BASE`, `F2F3`, `F4` | Local de cada integrante (no se versiona por tamaño) |
| **Restore probado** | Una vez en F1 (BASE) y una vez en F4 | `/system reset-configuration` → `/import <archivo>.rsc` en un router de prueba; verificar con `/export` que coincide | Evidencia en sección 6.2 |

- Los `.rsc` **nunca** incluyen contraseñas de usuario (RouterOS no las exporta) y se revisan antes de commitear para no filtrar claves de OSPF, BGP o VRRP: si aparecen, se reemplazan por su marcador (ver 1.3).
- Responsable: R5. Verificación: cada backup debe poder hacer `/import` sin errores.

---

## 2. Topología

Proyecto GNS3 `Failover-G11`, armado por el grupo desde cero en GNS3 2.2.61 con la imagen MikroTik CHR 7.21.5 (256 MB de RAM y 4 interfaces por router). Diagrama lógico de diseño en `docs/diagramas/topologia.md`.

![Topología del proyecto GNS3](../capturas/F1/01-topologia.png)

| Capa | Nodos |
|------|-------|
| INTERNET | ISP-1, ISP-2 |
| EDGE | EDGE |
| CORE | CORE-1, CORE-2 |
| DISTRIBUTION | DIST-1, DIST-2 |
| ACCESS | SW-USERS, SW-SERVERS (Ethernet switch de GNS3), PC-USER, SRV (VPCS) |

- **11 nodos y 15 enlaces**, cableados según la tabla de 1.2. GNS3 rotula las interfaces de los CHR como `Ethernet0`…`Ethernet3` (`e0`…`e3` en la captura); equivalen a `ether1`…`ether4` de RouterOS.
- **La numeración `etherN` de 1.2 se contrastó con el proyecto y no hubo diferencias**: la tabla IPAM queda sin cambios.
- Los hosts son VPCS porque el GNS3 usado corre con servidor local, sin la GNS3 VM que necesitan los contenedores.

**Incidente: orden de las interfaces en los CHR.** En el primer arranque de un nodo, RouterOS nombra las interfaces según el orden en que detecta las placas, y en esta plataforma ese orden no siempre coincide con el de los adaptadores de GNS3. En ISP-1 la placa del primer adaptador (MAC terminada en `00:00`) quedó como `ether4`: la dirección se había cargado en `ether1`, un puerto sin cable, y el ping hacia EDGE no respondía (ARP en estado `failed`). Se detectó comparando las MAC en `/interface print`. A partir de ahí se agregó un chequeo previo a configurar cada router (`/interface print`: las MAC deben ir en orden, de `00:00` en `ether1` a `00:03` en `ether4`), que encontró el mismo problema en CORE-2 y en DIST-2 antes de cargarles nada. Los tres nodos se recrearon y se recablearon; los 7 routers quedaron con las interfaces en orden (capturas `*-interfaces.png`). El mismo efecto volvió a aparecer en un `/export` y en el restore (ver 6.2).

**Snapshot `BASE`.** Tomado el 2026-10-10 a las 17:22, con todos los nodos apagados y después de verificar conectividad y hardening. Queda en la máquina donde corre el laboratorio (no se versiona por tamaño). Al volver a prender los nodos se repitieron los ping desde EDGE y DIST-1 (capturas `13-*-ping-post-snapshot.png`): la configuración sobrevive al apagado.

![Snapshot BASE en GNS3](../capturas/F1/12-snapshot-BASE.png)

---

## 3. Configuración

> Un bloque por dispositivo. Se puede referenciar el archivo `.rsc` del repo y pegar el contenido final. (F1–F3)

### 3.1 ISP-1

Archivo: [`configs/ISP-1.rsc`](../configs/ISP-1.rsc), configuración vigente al cierre de F4 (el export post-F4 de `backups/2026-10-22/` es idéntico). Las claves no aparecen: RouterOS no las incluye en el `/export`; en los comentarios figuran los marcadores de 1.3.

```routeros
# Interfaces virtuales: loopback (= router-id, se anuncia por BGP) y destino de prueba 192.0.2.1 de los drills 3 y 4 (igual en los dos ISP, no se anuncia por BGP; ver 1.2)
/interface bridge
add comment="destino de prueba de los drills (no se anuncia por BGP)" name=internet-test
add comment="loopback = router-id" name=loopback

# Placas: RouterOS registra el orden en que las detectó en ese arranque. Las líneas con name= aparecen cuando no coincide con el de los adaptadores de GNS3 (sección 2); se quitan antes de un restore (6.2)
/interface ethernet
set [ find default-name=ether4 ] disable-running-check=no name=ether1
set [ find default-name=ether1 ] disable-running-check=no name=ether2
set [ find default-name=ether2 ] disable-running-check=no name=ether3
set [ find default-name=ether3 ] disable-running-check=no name=ether4

# BGP: AS 65001, router-id = loopback
/routing bgp instance
add as=65001 comment="ISP-1, router-id = loopback" name=bgp-as65001 router-id=198.51.100.1

# Hardening: sin descubrimiento de vecinos
/ip neighbor discovery-settings
set discover-interface-list=none

# Direcciones: enlace hacia EDGE, loopback y destino de prueba
/ip address
add address=203.0.113.1/30 comment="hacia EDGE" interface=ether1 network=203.0.113.0
add address=198.51.100.1 interface=loopback network=198.51.100.1
add address=192.0.2.1 interface=internet-test network=192.0.2.1

# Lo que el ISP anuncia por BGP además de la ruta por defecto: solo su loopback (ajuste de F3, ver 4.1)
/ip firewall address-list
add address=198.51.100.1 comment="loopback ISP-1, se anuncia por BGP" list=anuncio-bgp

# Hardening: servicios en texto plano y API apagados; SSH y Winbox solo desde las redes de gestión
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes

# eBGP con el EDGE, autenticación TCP-MD5 (<CLAVE_BGP_ISP1>, no aparece en el export). Manda siempre la ruta por defecto y el loopback (lista anuncio-bgp)
/routing bgp connection
add as=65001 comment="eBGP con EDGE, TCP-MD5" instance=bgp-as65001 local.role=ebgp name=hacia-EDGE output.default-originate=always .network=anuncio-bgp remote.address=203.0.113.2 .as=65000

# Nombre del router
/system identity
set name=ISP-1

# Hardening: bandwidth-server y acceso por MAC (MAC-Telnet y MAC-Winbox) apagados
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none
```

### 3.2 ISP-2

Archivo: [`configs/ISP-2.rsc`](../configs/ISP-2.rsc), configuración vigente al cierre de F4 (el export post-F4 de `backups/2026-10-22/` es idéntico). Las claves no aparecen: RouterOS no las incluye en el `/export`; en los comentarios figuran los marcadores de 1.3.

```routeros
# Interfaces virtuales: loopback (= router-id, se anuncia por BGP) y destino de prueba 192.0.2.1 de los drills 3 y 4 (igual en los dos ISP, no se anuncia por BGP; ver 1.2)
/interface bridge
add comment="destino de prueba de los drills (no se anuncia por BGP)" name=internet-test
add comment="loopback = router-id" name=loopback

# Placas: RouterOS registra el orden en que las detectó en ese arranque. Las líneas con name= aparecen cuando no coincide con el de los adaptadores de GNS3 (sección 2); se quitan antes de un restore (6.2)
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no

# BGP: AS 65002, router-id = loopback
/routing bgp instance
add as=65002 comment="ISP-2, router-id = loopback" name=bgp-as65002 router-id=198.51.100.2

# Hardening: sin descubrimiento de vecinos
/ip neighbor discovery-settings
set discover-interface-list=none

# Direcciones: enlace hacia EDGE, loopback y destino de prueba
/ip address
add address=203.0.113.5/30 comment="hacia EDGE" interface=ether1 network=203.0.113.4
add address=198.51.100.2 interface=loopback network=198.51.100.2
add address=192.0.2.1 interface=internet-test network=192.0.2.1

# Lo que el ISP anuncia por BGP además de la ruta por defecto: solo su loopback (ajuste de F3, ver 4.1)
/ip firewall address-list
add address=198.51.100.2 comment="loopback ISP-2, se anuncia por BGP" list=anuncio-bgp

# Hardening: servicios en texto plano y API apagados; SSH y Winbox solo desde las redes de gestión
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes

# eBGP con el EDGE, autenticación TCP-MD5 (<CLAVE_BGP_ISP2>, no aparece en el export). Manda siempre la ruta por defecto y el loopback (lista anuncio-bgp)
/routing bgp connection
add as=65002 comment="eBGP con EDGE, TCP-MD5" instance=bgp-as65002 local.role=ebgp name=hacia-EDGE output.default-originate=always .network=anuncio-bgp remote.address=203.0.113.6 .as=65000

# Nombre del router
/system identity
set name=ISP-2

# Hardening: bandwidth-server y acceso por MAC (MAC-Telnet y MAC-Winbox) apagados
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none
```

### 3.3 EDGE

Archivo: [`configs/EDGE.rsc`](../configs/EDGE.rsc), configuración vigente al cierre de F4 (el export post-F4 de `backups/2026-10-22/` es idéntico). Las claves no aparecen: RouterOS no las incluye en el `/export`; en los comentarios figuran los marcadores de 1.3.

```routeros
# Interfaces virtuales: loopback (= router-id)
/interface bridge
add comment="loopback = router-id" name=loopback

# Placas: RouterOS registra el orden en que las detectó en ese arranque. Las líneas con name= aparecen cuando no coincide con el de los adaptadores de GNS3 (sección 2); se quitan antes de un restore (6.2)
/interface ethernet
set [ find default-name=ether3 ] disable-running-check=no name=ether1
set [ find default-name=ether4 ] disable-running-check=no name=ether2
set [ find default-name=ether1 ] disable-running-check=no name=ether3
set [ find default-name=ether2 ] disable-running-check=no name=ether4

# Lista WAN: las dos interfaces hacia los ISP (la usa el firewall)
/interface list
add comment="enlaces hacia los ISP" name=WAN

# BGP: AS 65000, router-id = loopback
/routing bgp instance
add as=65000 comment="EDGE, router-id = loopback" name=bgp-as65000 router-id=10.255.255.1

# OSPF: router-id = loopback; inyecta la ruta por defecto en OSPF solo si la tiene instalada (la que aprende por BGP)
/routing ospf instance
add name=ospf-g11 originate-default=if-installed router-id=10.255.255.1

# Área 0 (backbone)
/routing ospf area
add instance=ospf-g11 name=backbone

# SNMP de solo lectura (F4): la comunidad de fábrica (public) queda deshabilitada y la nueva solo acepta consultas desde las redes de gestión. El nombre de la comunidad es un secreto (KeePassXC)
/snmp community
set [ find default=yes ] disabled=yes
add addresses=10.255.255.0/24,10.20.0.0/24 name=<COMUNIDAD_SNMP>

# Hardening: sin descubrimiento de vecinos
/ip neighbor discovery-settings
set discover-interface-list=none

# Miembros de la lista WAN
/interface list member
add interface=ether1 list=WAN
add interface=ether2 list=WAN

# Direcciones: enlaces hacia ISP-1, ISP-2, CORE-1 y CORE-2, y loopback
/ip address
add address=203.0.113.2/30 comment="hacia ISP-1" interface=ether1 network=203.0.113.0
add address=203.0.113.6/30 comment="hacia ISP-2" interface=ether2 network=203.0.113.4
add address=10.0.0.1/30 comment="hacia CORE-1" interface=ether3 network=10.0.0.0
add address=10.0.0.5/30 comment="hacia CORE-2" interface=ether4 network=10.0.0.4
add address=10.255.255.1 interface=loopback network=10.255.255.1

# Listas del firewall: redes de gestión (loopbacks y LAN SERVERS) y LANs de la empresa
/ip firewall address-list
add address=10.255.255.0/24 comment=loopbacks list=gestion
add address=10.20.0.0/24 comment="LAN SERVERS" list=gestion
add address=10.10.0.0/24 comment="LAN USERS" list=lans
add address=10.20.0.0/24 comment="LAN SERVERS" list=lans

# Firewall (F3, política 1.3). input protege al router: gestión solo desde la lista gestion, BGP solo desde cada ISP, OSPF solo desde los enlaces internos, ICMP, y drop del resto. forward deja salir a las LAN y descarta conexiones nuevas que entran desde los ISP
/ip firewall filter
add action=accept chain=input comment="input: conexiones en curso" connection-state=established,related
add action=drop chain=input comment="input: invalidas" connection-state=invalid
add action=accept chain=input comment="input: SSH y Winbox solo desde gestion" dst-port=22,8291 protocol=tcp src-address-list=gestion
add action=accept chain=input comment="input: BGP desde ISP-1" dst-port=179 protocol=tcp src-address=203.0.113.1
add action=accept chain=input comment="input: BGP desde ISP-2" dst-port=179 protocol=tcp src-address=203.0.113.5
add action=accept chain=input comment="input: OSPF desde enlaces internos" protocol=ospf src-address=10.0.0.0/24
add action=accept chain=input comment="input: ICMP" protocol=icmp
add action=drop chain=input comment="input: todo lo demas"
add action=accept chain=forward comment="forward: conexiones en curso" connection-state=established,related
add action=drop chain=forward comment="forward: invalidas" connection-state=invalid
add action=drop chain=forward comment="forward: nada nuevo desde los ISP hacia adentro" connection-state=new in-interface-list=WAN
add action=accept chain=forward comment="forward: salida desde las LAN" src-address-list=lans

# Hardening: servicios en texto plano y API apagados; SSH y Winbox solo desde las redes de gestión
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes

# eBGP con cada ISP, autenticación TCP-MD5 (<CLAVE_BGP_ISP1>, <CLAVE_BGP_ISP2>; no aparecen en el export). Redistribuye OSPF hacia BGP y el filtro lans-a-isp deja salir solo las dos LANs
/routing bgp connection
add as=65000 comment="eBGP con ISP-1" instance=bgp-as65000 local.role=ebgp name=hacia-ISP-1 output.filter-chain=lans-a-isp .redistribute=ospf remote.address=203.0.113.1 .as=65001
add as=65000 comment="eBGP con ISP-2" instance=bgp-as65000 local.role=ebgp name=hacia-ISP-2 output.filter-chain=lans-a-isp .redistribute=ospf remote.address=203.0.113.5 .as=65002

# Filtro de salida hacia los ISP: acepta solo 10.10.0.0/24 y 10.20.0.0/24; el resto se rechaza (acción por defecto de la cadena)
/routing filter rule
add chain=lans-a-isp comment="LAN USERS" rule="if (dst == 10.10.0.0/24) { accept }"
add chain=lans-a-isp comment="LAN SERVERS" rule="if (dst == 10.20.0.0/24) { accept }"

# Interfaces OSPF: enlaces hacia los CORE punto a punto con MD5 (<CLAVE_OSPF>, no aparece en el export); loopback pasiva
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 comment="enlaces P2P con MD5 hacia CORE" interfaces=ether3,ether4 type=ptp
add area=backbone comment="loopback = router-id" interfaces=loopback passive

# SNMP habilitado, con contacto y ubicación
/snmp
set contact="Grupo 11" enabled=yes location=EDGE

# Nombre del router
/system identity
set name=EDGE

# Hardening: bandwidth-server y acceso por MAC (MAC-Telnet y MAC-Winbox) apagados
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none

# Monitoreo (F4): ping cada 10 s a los loopbacks internos y a los de los ISP; cada caída y cada vuelta queda en el log
/tool netwatch
add comment=CORE-1 host=10.255.255.2 interval=10s type=simple
add comment=CORE-2 host=10.255.255.3 interval=10s type=simple
add comment=DIST-1 host=10.255.255.4 interval=10s type=simple
add comment=DIST-2 host=10.255.255.5 interval=10s type=simple
add comment=ISP-1 host=198.51.100.1 interval=10s type=simple
add comment=ISP-2 host=198.51.100.2 interval=10s type=simple
```

### 3.4 CORE-1

Archivo: [`configs/CORE-1.rsc`](../configs/CORE-1.rsc), configuración vigente al cierre de F4 (el export post-F4 de `backups/2026-10-22/` es idéntico). Las claves no aparecen: RouterOS no las incluye en el `/export`; en los comentarios figuran los marcadores de 1.3.

```routeros
# Interfaces virtuales: loopback (= router-id)
/interface bridge
add comment="loopback = router-id" name=loopback

# Placas: RouterOS registra el orden en que las detectó en ese arranque. Las líneas con name= aparecen cuando no coincide con el de los adaptadores de GNS3 (sección 2); se quitan antes de un restore (6.2)
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no

# OSPF: instancia con router-id = loopback
/routing ospf instance
add name=ospf-g11 router-id=10.255.255.2

# Área 0 (backbone)
/routing ospf area
add instance=ospf-g11 name=backbone

# SNMP de solo lectura (F4): la comunidad de fábrica (public) queda deshabilitada y la nueva solo acepta consultas desde las redes de gestión. El nombre de la comunidad es un secreto (KeePassXC)
/snmp community
set [ find default=yes ] disabled=yes
add addresses=10.255.255.0/24,10.20.0.0/24 name=<COMUNIDAD_SNMP>

# Hardening: sin descubrimiento de vecinos
/ip neighbor discovery-settings
set discover-interface-list=none

# Direcciones: enlaces hacia EDGE, CORE-2 (core–core), DIST-1 y DIST-2, y loopback
/ip address
add address=10.0.0.2/30 comment="hacia EDGE" interface=ether1 network=10.0.0.0
add address=10.0.0.9/30 comment="hacia CORE-2" interface=ether2 network=10.0.0.8
add address=10.0.0.13/30 comment="hacia DIST-1" interface=ether3 network=10.0.0.12
add address=10.0.0.21/30 comment="hacia DIST-2" interface=ether4 network=10.0.0.20
add address=10.255.255.2 interface=loopback network=10.255.255.2

# Hardening: servicios en texto plano y API apagados; SSH y Winbox solo desde las redes de gestión
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes

# Interfaces OSPF: los 4 enlaces (EDGE, core–core, DIST-1, DIST-2) punto a punto con MD5 (<CLAVE_OSPF>, no aparece en el export); loopback pasiva
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 comment="enlaces P2P con MD5" interfaces=ether1,ether2,ether3,ether4 type=ptp
add area=backbone comment="loopback = router-id" interfaces=loopback passive

# SNMP habilitado, con contacto y ubicación
/snmp
set contact="Grupo 11" enabled=yes location=CORE-1

# Nombre del router
/system identity
set name=CORE-1

# Hardening: bandwidth-server y acceso por MAC (MAC-Telnet y MAC-Winbox) apagados
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none
```

### 3.5 CORE-2

Archivo: [`configs/CORE-2.rsc`](../configs/CORE-2.rsc), configuración vigente al cierre de F4 (el export post-F4 de `backups/2026-10-22/` es idéntico). Las claves no aparecen: RouterOS no las incluye en el `/export`; en los comentarios figuran los marcadores de 1.3.

```routeros
# Interfaces virtuales: loopback (= router-id)
/interface bridge
add comment="loopback = router-id" name=loopback

# Placas: RouterOS registra el orden en que las detectó en ese arranque. Las líneas con name= aparecen cuando no coincide con el de los adaptadores de GNS3 (sección 2); se quitan antes de un restore (6.2)
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no

# OSPF: instancia con router-id = loopback
/routing ospf instance
add name=ospf-g11 router-id=10.255.255.3

# Área 0 (backbone)
/routing ospf area
add instance=ospf-g11 name=backbone

# SNMP de solo lectura (F4): la comunidad de fábrica (public) queda deshabilitada y la nueva solo acepta consultas desde las redes de gestión. El nombre de la comunidad es un secreto (KeePassXC)
/snmp community
set [ find default=yes ] disabled=yes
add addresses=10.255.255.0/24,10.20.0.0/24 name=<COMUNIDAD_SNMP>

# Hardening: sin descubrimiento de vecinos
/ip neighbor discovery-settings
set discover-interface-list=none

# Direcciones: enlaces hacia EDGE, CORE-1 (core–core), DIST-1 y DIST-2, y loopback
/ip address
add address=10.0.0.6/30 comment="hacia EDGE" interface=ether1 network=10.0.0.4
add address=10.0.0.10/30 comment="hacia CORE-1" interface=ether2 network=10.0.0.8
add address=10.0.0.17/30 comment="hacia DIST-1" interface=ether3 network=10.0.0.16
add address=10.0.0.25/30 comment="hacia DIST-2" interface=ether4 network=10.0.0.24
add address=10.255.255.3 interface=loopback network=10.255.255.3

# Hardening: servicios en texto plano y API apagados; SSH y Winbox solo desde las redes de gestión
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes

# Interfaces OSPF: los 4 enlaces (EDGE, core–core, DIST-1, DIST-2) punto a punto con MD5 (<CLAVE_OSPF>, no aparece en el export); loopback pasiva
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 comment="enlaces P2P con MD5" interfaces=ether1,ether2,ether3,ether4 type=ptp
add area=backbone comment="loopback = router-id" interfaces=loopback passive

# SNMP habilitado, con contacto y ubicación
/snmp
set contact="Grupo 11" enabled=yes location=CORE-2

# Nombre del router
/system identity
set name=CORE-2

# Hardening: bandwidth-server y acceso por MAC (MAC-Telnet y MAC-Winbox) apagados
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none
```

### 3.6 DIST-1

Archivo: [`configs/DIST-1.rsc`](../configs/DIST-1.rsc), configuración vigente al cierre de F4 (el export post-F4 de `backups/2026-10-22/` es idéntico). Las claves no aparecen: RouterOS no las incluye en el `/export`; en los comentarios figuran los marcadores de 1.3.

```routeros
# Interfaces virtuales: loopback (= router-id)
/interface bridge
add comment="loopback = router-id" name=loopback

# Placas: RouterOS registra el orden en que las detectó en ese arranque. Las líneas con name= aparecen cuando no coincide con el de los adaptadores de GNS3 (sección 2); se quitan antes de un restore (6.2)
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no

# VRRP versión 2 con autenticación simple (<CLAVE_VRRP_10>, <CLAVE_VRRP_20>; no aparecen en el export). DIST-1: master del grupo 10 (USERS, prioridad 200) y backup del 20 (prioridad 100, la de fábrica)
/interface vrrp
add authentication=simple comment="USERS: DIST-1 master" interface=ether3 name=vrrp10 priority=200 version=2 vrid=10
add authentication=simple comment="SERVERS: DIST-1 backup" interface=ether4 name=vrrp20 version=2 vrid=20

# OSPF: instancia con router-id = loopback
/routing ospf instance
add name=ospf-g11 router-id=10.255.255.4

# Área 0 (backbone)
/routing ospf area
add instance=ospf-g11 name=backbone

# SNMP de solo lectura (F4): la comunidad de fábrica (public) queda deshabilitada y la nueva solo acepta consultas desde las redes de gestión. El nombre de la comunidad es un secreto (KeePassXC)
/snmp community
set [ find default=yes ] disabled=yes
add addresses=10.255.255.0/24,10.20.0.0/24 name=<COMUNIDAD_SNMP>

# Hardening: sin descubrimiento de vecinos
/ip neighbor discovery-settings
set discover-interface-list=none

# Direcciones: enlaces hacia CORE-1 y CORE-2, pata propia en cada LAN (.2), loopback e IP virtuales de VRRP (.1; la del grupo en backup figura inválida hasta que el master cae)
/ip address
add address=10.0.0.14/30 comment="hacia CORE-1" interface=ether1 network=10.0.0.12
add address=10.0.0.18/30 comment="hacia CORE-2" interface=ether2 network=10.0.0.16
add address=10.10.0.2/24 comment="LAN USERS" interface=ether3 network=10.10.0.0
add address=10.20.0.2/24 comment="LAN SERVERS" interface=ether4 network=10.20.0.0
add address=10.255.255.4 interface=loopback network=10.255.255.4
add address=10.10.0.1 comment="gateway virtual USERS" interface=vrrp10 network=10.10.0.1
add address=10.20.0.1 comment="gateway virtual SERVERS" interface=vrrp20 network=10.20.0.1

# Hardening: servicios en texto plano y API apagados; SSH y Winbox solo desde las redes de gestión
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes

# Interfaces OSPF: enlaces hacia los CORE punto a punto con MD5 (<CLAVE_OSPF>); loopback y LANs pasivas (se anuncian pero no forman vecinos hacia los hosts)
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 comment="enlaces P2P con MD5 hacia CORE" interfaces=ether1,ether2 type=ptp
add area=backbone comment="loopback = router-id" interfaces=loopback passive
add area=backbone comment="LANs USERS y SERVERS, pasivas" interfaces=ether3,ether4 passive

# SNMP habilitado, con contacto y ubicación
/snmp
set contact="Grupo 11" enabled=yes location=DIST-1

# Nombre del router
/system identity
set name=DIST-1

# Hardening: bandwidth-server y acceso por MAC (MAC-Telnet y MAC-Winbox) apagados
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none
```

### 3.7 DIST-2

Archivo: [`configs/DIST-2.rsc`](../configs/DIST-2.rsc), configuración vigente al cierre de F4 (el export post-F4 de `backups/2026-10-22/` es idéntico). Las claves no aparecen: RouterOS no las incluye en el `/export`; en los comentarios figuran los marcadores de 1.3.

```routeros
# Interfaces virtuales: loopback (= router-id)
/interface bridge
add comment="loopback = router-id" name=loopback

# Placas: RouterOS registra el orden en que las detectó en ese arranque. Las líneas con name= aparecen cuando no coincide con el de los adaptadores de GNS3 (sección 2); se quitan antes de un restore (6.2)
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no

# VRRP versión 2 con autenticación simple (<CLAVE_VRRP_10>, <CLAVE_VRRP_20>; no aparecen en el export). DIST-2: backup del grupo 10 (prioridad 100, la de fábrica) y master del 20 (SERVERS, prioridad 200)
/interface vrrp
add authentication=simple comment="USERS: DIST-2 backup" interface=ether3 name=vrrp10 version=2 vrid=10
add authentication=simple comment="SERVERS: DIST-2 master" interface=ether4 name=vrrp20 priority=200 version=2 vrid=20

# OSPF: instancia con router-id = loopback
/routing ospf instance
add name=ospf-g11 router-id=10.255.255.5

# Área 0 (backbone)
/routing ospf area
add instance=ospf-g11 name=backbone

# SNMP de solo lectura (F4): la comunidad de fábrica (public) queda deshabilitada y la nueva solo acepta consultas desde las redes de gestión. El nombre de la comunidad es un secreto (KeePassXC)
/snmp community
set [ find default=yes ] disabled=yes
add addresses=10.255.255.0/24,10.20.0.0/24 name=<COMUNIDAD_SNMP>

# Hardening: sin descubrimiento de vecinos
/ip neighbor discovery-settings
set discover-interface-list=none

# Direcciones: enlaces hacia CORE-1 y CORE-2, pata propia en cada LAN (.3), loopback e IP virtuales de VRRP (.1; la del grupo en backup figura inválida hasta que el master cae)
/ip address
add address=10.0.0.22/30 comment="hacia CORE-1" interface=ether1 network=10.0.0.20
add address=10.0.0.26/30 comment="hacia CORE-2" interface=ether2 network=10.0.0.24
add address=10.10.0.3/24 comment="LAN USERS" interface=ether3 network=10.10.0.0
add address=10.20.0.3/24 comment="LAN SERVERS" interface=ether4 network=10.20.0.0
add address=10.255.255.5 interface=loopback network=10.255.255.5
add address=10.10.0.1 comment="gateway virtual USERS" interface=vrrp10 network=10.10.0.1
add address=10.20.0.1 comment="gateway virtual SERVERS" interface=vrrp20 network=10.20.0.1

# Hardening: servicios en texto plano y API apagados; SSH y Winbox solo desde las redes de gestión
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes

# Interfaces OSPF: enlaces hacia los CORE punto a punto con MD5 (<CLAVE_OSPF>); loopback y LANs pasivas (se anuncian pero no forman vecinos hacia los hosts)
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 comment="enlaces P2P con MD5 hacia CORE" interfaces=ether1,ether2 type=ptp
add area=backbone comment="loopback = router-id" interfaces=loopback passive
add area=backbone comment="LANs USERS y SERVERS, pasivas" interfaces=ether3,ether4 passive

# SNMP habilitado, con contacto y ubicación
/snmp
set contact="Grupo 11" enabled=yes location=DIST-2

# Nombre del router
/system identity
set name=DIST-2

# Hardening: bandwidth-server y acceso por MAC (MAC-Telnet y MAC-Winbox) apagados
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none
```

### 3.8 Hosts (PC-USER / SRV)
```bash
# Los hosts son VPCS de GNS3. El gateway .1 es la IP virtual de VRRP: existe a partir de F2.

# PC-USER
ip 10.10.0.100/24 10.10.0.1
save

# SRV
ip 10.20.0.100/24 10.20.0.1
save
```

---

## 4. Verificación

### 4.1 Conectividad básica

| Prueba | Comando | Resultado |
|--------|---------|-----------|
| ping entre vecinos directos (F1) | `/ping <IP del vecino> count=4` desde cada router, por cada enlace; `ping` desde PC-USER y SRV a DIST-1 y DIST-2 | Responden los 15 enlaces, en los dos sentidos. Capturas `*-ping-*.png` en `capturas/F1/`. En F1 todavía no hay ruteo entre nodos que no son vecinos (llega con OSPF y BGP) |
| gateway virtual (F2) | `ping 10.10.0.1` desde PC-USER; `ping 10.20.0.1` desde SRV | Responden 5 de 5. Capturas `03-*-ping-gateway.png` en `capturas/F2/` |
| ping intra-LAN (PC-USER ↔ SRV) | `ping 10.20.0.100` desde PC-USER; `ping 10.10.0.100` desde SRV | Responden 5 de 5, con `ttl=63` (un salto: el DIST master del gateway de cada host). Capturas `06-PC-USER-ping-SRV.png` y `06-SRV-ping-PC-USER.png` en `capturas/F2/` |
| ping a loopback interna (F2) | `/ping 10.255.255.1 count=4` desde DIST-1 | 4 de 4, a través del core (`06-DIST-1-ping-loopback-EDGE.png`) |
| salida a "Internet" (F3) | `ping 198.51.100.1` y `ping 198.51.100.2` desde PC-USER | Responden los dos loopbacks, 5 de 5 (`06-PC-USER-ping-trace-ISP-1-ISP-2.png` en `capturas/F3/`). Antes del ajuste descrito abajo, `198.51.100.2` no respondía |
| traceroute a ISP (loopback) | `trace 198.51.100.1` y `trace 198.51.100.2` desde PC-USER | Hacia ISP-1: `10.10.0.2` (DIST-1) → `10.0.0.13` (CORE-1) → `10.0.0.1` (EDGE) → `198.51.100.1`. Hacia ISP-2: `10.10.0.2` → `10.0.0.25` (CORE-2) → `10.0.0.5` (EDGE) → `198.51.100.2`. DIST-1 reparte entre los dos CORE (ECMP). Capturas `05-…` y `06-…` en `capturas/F3/` |

**VRRP (F2).** DIST-1 es master del grupo 10 y backup del 20; DIST-2, al revés. La IP virtual del grupo en backup figura como inválida (`I`) en `/ip address print` hasta que el master se cae: es lo esperado.

![VRRP en DIST-1](../capturas/F2/02-DIST-1-vrrp.png)

**OSPF (F2).** 7 adyacencias Full, una por cada cable interno, incluido el core–core, vistas desde las dos puntas: EDGE 2, CORE-1 4, CORE-2 4, DIST-1 2 y DIST-2 2 (capturas `04-*-ospf-vecinos.png`). En DIST-1 aparecen por OSPF las loopbacks y los /30 que no son suyos, y algunas rutas con dos caminos de igual costo, uno por cada CORE (`05-DIST-1-rutas-ospf.png`). En una de las verificaciones, DIST-2 mostró primero un solo vecino; unos 40 segundos después tenía los dos en Full: era el tiempo de armado de la adyacencia.

![Vecinos OSPF de CORE-1](../capturas/F2/04-CORE-1-ospf-vecinos.png)

**BGP y redistribución (F3).** El EDGE tiene las 2 sesiones establecidas y dos rutas por defecto (una por ISP, activa la de ISP-1). Cada ISP recibe por BGP **solo** `10.10.0.0/24` y `10.20.0.0/24`: el EDGE redistribuye OSPF hacia BGP con el filtro de salida `lans-a-isp`, que acepta esas dos redes; lo demás (los /30 internos y las loopbacks) queda rechazado, porque la acción por defecto de una cadena de filtro en RouterOS es `reject`. El EDGE inyecta la ruta por defecto en OSPF con `originate-default=if-installed`, y DIST-1 la aprende por los dos CORE (capturas `01-…` a `04-…` en `capturas/F3/`).

![Sesiones BGP en EDGE](../capturas/F3/01-EDGE-bgp-sesiones.png)

**Ajuste en F3: los ISP anuncian su loopback.** Con la configuración inicial (cada ISP manda solo la ruta por defecto), PC-USER llegaba a `198.51.100.1` pero no a `198.51.100.2`: ISP-1 respondía *Destination network unreachable* (`05-PC-USER-ping-ISP-2-sin-loopback-anunciado.png`). Causa: el EDGE manda todo por la ruta por defecto activa, que es la de ISP-1, y ISP-1 no tiene ruta hacia el loopback de ISP-2. Solución, acordada por el grupo: cada ISP anuncia además su loopback /32 (`/ip firewall address-list` con el loopback y `output.network` en la conexión BGP). El EDGE aprende `198.51.100.1/32` por ISP-1 y `198.51.100.2/32` por ISP-2, y cada ping sale por su proveedor. ISP-1 sigue recibiendo solo las dos LANs: el filtro del EDGE no le pasa el loopback de ISP-2 (capturas `07-…` y `08-…`).

### 4.2 Los 5 drills de failover

Cada drill tiene su runbook en `runbooks/` con la estructura **detección → respuesta → recuperación → post-mortem** y el tiempo medido (plantilla en `runbooks/plantilla-runbook.md`). El laboratorio lo ejecutó el anfitrión de GNS3 (R1); en cada drill, quien figura como "dirigió" dictó y explicó los comandos y revisó las salidas. Midió siempre R5.

**Cómo se midió.** Ping continuo durante cada drill, contando las respuestas perdidas. El ping de RouterOS manda una solicitud por segundo aunque no haya respuesta (cada `timeout` = 1 s). En VPCS (PC-USER y SRV) cada `timeout` equivale a unos **2 s**: lo calibramos con cronómetro en el drill 3 (93 respuestas perdidas en ~160 s). Los relojes de los routers no tienen NTP y se desfasaron durante la sesión, así que las horas del log solo se comparan dentro de un mismo router.

Para los drills 3 y 4 se usó el destino de prueba `192.0.2.1` (1.2): lo responde el ISP por el que sale la empresa.

#### Drill 1 — VRRP: se cae el gateway
Runbook [`runbooks/drill-1-vrrp.md`](../runbooks/drill-1-vrrp.md) · capturas `06-drill1-*` · dirigió Juan Bautista Cuenca.
- **Detección:** con `/interface disable ether3` en DIST-1 (su pata hacia la LAN USERS), el ping de PC-USER a `198.51.100.1` pierde 8 respuestas. DIST-2 registra `vrrp10 now MASTER, master down timer`: tomó el control porque dejó de recibir los anuncios de DIST-1.
- **Respuesta:** DIST-2 toma la IP y la MAC virtuales del grupo 10. El primer salto del `trace` desde PC-USER pasa de `10.10.0.2` a `10.10.0.3`. El host no cambia nada.
- **Recuperación:** `/interface enable ether3`. DIST-1 recupera el master por prioridad (200 contra 100) 11 s después de habilitar la interfaz; mientras tanto atiende DIST-2, y el ping no pierde ninguna respuesta.
- **Tiempo medido:** **~16 s** (8 `timeout` en VPCS). El *master down interval* teórico es 3 × 1 s + 0,61 s ≈ 3,6 s. No encontramos la causa de la diferencia; en el drill 5 el mismo mecanismo cortó ~4 s.
- **Post-mortem:** funciona porque el host apunta a una IP virtual y no a un router. Al apagar la interfaz, el master no avisa que se va, así que el backup espera el temporizador completo. Observación no prevista: 2 s después del corte, DIST-1 fue master del grupo 20 durante 1 s (causa no confirmada). Limitación de VRRP: no detecta la caída de los enlaces de un DIST hacia los CORE; eso lo cubre OSPF.

#### Drill 2 — OSPF: se corta el camino interno
Runbook [`runbooks/drill-2-ospf.md`](../runbooks/drill-2-ospf.md) · capturas `07-drill2-*` · dirigió Juan Bautista Cuenca con Tomás Martin (los CORE operados por alguien distinto de R3, como pidió el docente).
- **Detección:** se cortó el enlace EDGE ↔ CORE-1 de dos formas. (A) `/interface disable ether1` en CORE-1: el vecino EDGE cae al instante. (B) Corte silencioso, con un filtro de pérdida del 100 % en el cable (GNS3, *Packet filters*): la interfaz sigue arriba y CORE-1 recién da por caído al vecino cuando vence el *dead interval* (log: `state: Full } timeout`). Se probó primero con *Suspend*, pero GNS3 le baja la señal a la placa y el corte no es silencioso.
- **Respuesta:** CORE-1 llega al EDGE por el cable core–core: `traceroute` `10.0.0.10` (CORE-2) → `10.255.255.1`, y el ping vuelve con TTL 63.
- **Recuperación:** (A) `/interface enable ether1`: vecino otra vez en Full en 9 s. (B) Se saca el filtro y la adyacencia se arma sola.
- **Tiempo medido:** (A) **~2 s** (2 de 15 en el ping de CORE-1). (B) **~35 s**: 31 s hasta que vence el *dead interval* (40 s desde el último *hello*) y 4 s hasta instalar la ruta nueva. PC-USER perdió ~16 s en (B): su tráfico se reparte entre los dos CORE y solo una parte pasaba por el cable cortado.
- **Post-mortem:** el cable core–core (corrección 3 del diagrama) es lo que le da salida a CORE-1. El tiempo de convergencia depende de cómo se entera el router: si la interfaz cae, son segundos; si el cable deja de pasar tráfico sin bajar la señal, manda el *dead interval*. Para bajarlo: *hellos* más cortos o BFD.

#### Drill 3 — BGP: se cae el proveedor
Runbook [`runbooks/drill-3-bgp.md`](../runbooks/drill-3-bgp.md) · capturas `08-drill3-*` · dirigió Santiago Natalichio Bestosini (rotación R1 → ISP).
- **Detección:** (A) `/interface disable ether1` en el EDGE: la ruta por defecto de ISP-1 queda inactiva porque su *gateway* quedó en una interfaz apagada. **La sesión BGP siguió establecida**: el cambio no lo hizo BGP. (B) Corte silencioso con el filtro del 100 % en el cable ISP-1 ↔ EDGE: durante más de 2 minutos la ruta y la sesión siguen activas mientras el tráfico se pierde (el EDGE llega a responder `host unreachable` porque no resuelve la MAC de ISP-1), hasta que el log registra `HoldTimer expired` y la sesión pasa a `Idle`.
- **Respuesta:** la ruta por defecto activa pasa a ser la de ISP-2. El ping de PC-USER a `192.0.2.1` vuelve a responder, ahora desde ISP-2 (torch en el EDGE: el tráfico sale por `ether2`).
- **Recuperación:** (A) se habilita la interfaz. (B) Se saca el filtro y la sesión se restablece sola; al volver la salida a ISP-1 se pierde 1 respuesta.
- **Tiempo medido:** (A) **~2 s** (1 respuesta en todo el ciclo). (B) **~160 s** (cronómetro; 93 respuestas perdidas). Teoría: el *hold time* (180 s) vence entre 120 y 180 s después del corte, según cuándo llegó el último *keepalive* (cada 60 s).
- **Post-mortem:** con los valores por defecto, BGP tarda minutos en detectar un corte silencioso. Es una decisión de diseño del protocolo: une organizaciones y cerrar la sesión por una pérdida corta obliga a retirar y volver a anunciar todas las rutas. Para acelerarlo: bajar *keepalive* y *hold*, o BFD (las dos cosas se acuerdan con el proveedor), o sumar un chequeo del siguiente salto como el del drill 4.

#### Drill 4 — check-gateway: failover estático de enlace
Runbook [`runbooks/drill-4-check-gateway.md`](../runbooks/drill-4-check-gateway.md) · capturas `09-drill4-*` · dirigió Tomás Martin (rotación R2 → EDGE).
- **Detección:** en el EDGE se agregaron dos rutas por defecto estáticas con `check-gateway=ping` (distancia 1 por ISP-1 y 2 por ISP-2; le ganan a las de eBGP, que tienen 20). Se apagó `ether1` de ISP-1: el EDGE mantiene su interfaz arriba, pero el ping de check-gateway (cada 10 s) deja de tener respuesta y la estática de ISP-1 queda inactiva.
- **Respuesta:** queda activa la estática de respaldo por ISP-2 y el ping a `192.0.2.1` vuelve a responder.
- **Recuperación:** `/interface enable ether1` en ISP-1: la estática principal vuelve a estar activa. Después se borraron las rutas del drill (`/ip route remove [find comment~"drill 4"]`); no quedan en la configuración final, y BGP volvió a mandar. La sesión BGP con ISP-1 no llegó a caer.
- **Tiempo medido:** **~17 s** (cronómetro). Teoría: dos pings fallidos, entre 10 y 20 s. La captura del ping de PC-USER no se guardó.
- **Post-mortem:** ante el mismo tipo de corte que el drill 3 (B), check-gateway tardó ~17 s contra ~160 s de BGP. Es simple y no necesita acuerdo con el proveedor, pero solo prueba el primer salto y no anuncia nada. BGP es el multi-homing real (anuncia las redes de la empresa a los dos proveedores) y conviene complementarlo con detección rápida. Al cargar el drill, un error de pegado creó dos veces la ruta de respaldo; no cambió el resultado y se borró con el resto.

#### Drill 5 — Load-sharing VRRP: ambos DIST activos
Runbook [`runbooks/drill-5-load-sharing.md`](../runbooks/drill-5-load-sharing.md) · capturas `10-drill5-*` · dirigió Juan Bautista Cuenca.
- **Detección:** no se rompe nada. `/interface vrrp print`: DIST-1 master del grupo 10 y DIST-2 del 20. Desde PC-USER, el primer salto del `trace` es `10.10.0.2` (DIST-1); desde SRV, `10.20.0.3` (DIST-2).
- **Respuesta:** cada DIST atiende una LAN. Parte opcional: con `/interface disable ether4` en DIST-2, SRV pierde 2 respuestas (**~4 s**) y su primer salto pasa a `10.20.0.2`: DIST-1 atiende las dos LANs.
- **Recuperación:** `/interface enable ether4`: DIST-2 recupera el master del grupo 20 por prioridad. No se guardaron el ping de la vuelta ni los logs VRRP.
- **Post-mortem:** los dos routers trabajan siempre y cada uno es el respaldo del otro. El load-sharing de VRRP reparte grupos de hosts (una LAN por router), no el tráfico de un mismo host: si una LAN tuviera mucho más tráfico, la carga no quedaría pareja.

---

## 5. Seguridad aplicada

| Mecanismo | Dónde se aplicó | Verificación (¿cómo probaron que funciona?) |
|-----------|-----------------|---------------------------------------------|
| Hardening (usuarios/servicios) | Los 7 routers (F1): clave de `admin`, usuario `monitor` (grupo `read`), servicios `telnet`, `ftp`, `www`, `www-ssl`, `api` y `api-ssl` deshabilitados, `ssh` y `winbox` restringidos a las redes de gestión, MAC server, descubrimiento de vecinos y bandwidth-server apagados, cliente DHCP de fábrica eliminado | En cada router: `/user print` (solo `admin` y `monitor`), `/ip service print` (servicios con `X`, y `address` restringido en `ssh` y `winbox`) e `/ip dhcp-client print` vacío. Capturas `*-hardening.png` y `*-sin-dhcp-client.png` en `capturas/F1/`; los `.rsc` de `configs/` lo reflejan |
| OSPF MD5 | Los 7 enlaces internos (F2): `auth=md5 auth-id=1` con `<CLAVE_OSPF>` en las interfaces activas de EDGE (`ether3`, `ether4`), CORE-1 y CORE-2 (`ether1`–`ether4`) y DIST-1 y DIST-2 (`ether1`, `ether2`), todas en modo `ptp`. Loopbacks y LANs como interfaces pasivas: se anuncian, pero no forman vecinos | Las 7 adyacencias llegan a Full con la misma clave en las dos puntas (capturas `04-*-ospf-vecinos.png` en `capturas/F2/`). `/routing ospf interface-template print` muestra `auth=md5 auth-id=1` sin mostrar la clave, y el `/export` no la incluye. **Prueba con clave incorrecta (F4):** en CORE-1 se cambió la clave del template de sus 4 enlaces por una incorrecta (`clave-incorrecta-F4`). Desde ese momento el log registra `authentication failed ... md5 mismatch` de los 4 vecinos y las 4 adyacencias caen por `timeout` al vencer el *dead interval* (unos 30 s después). La red siguió funcionando por CORE-2 (PC-USER llega a `198.51.100.1`). Con la clave real, cargada desde KeePassXC, los 4 vecinos vuelven a Full (`11-CORE-1-ospf-*.png` y `11-PC-USER-ping-sin-CORE-1.png` en `capturas/F4/`) |
| BGP TCP-MD5 | Sesión EDGE ↔ ISP-1 con `<CLAVE_BGP_ISP1>` y EDGE ↔ ISP-2 con `<CLAVE_BGP_ISP2>`, configuradas en las dos puntas (`tcp-md5-key` en `/routing bgp connection`) (F3). En RouterOS 7.21.5 el router-id va en `/routing bgp instance` y la conexión la referencia | 2 sesiones establecidas en EDGE y 1 en cada ISP (`01-EDGE-bgp-sesiones.png`, `03-ISP-*-bgp-rutas.png` en `capturas/F3/`). Siguen establecidas después de aplicar el firewall, sin reinicios (`09-EDGE-bgp-despues-firewall.png`). La clave no aparece en `print` ni en el `/export`. **Prueba con clave incorrecta (F4):** con `tcp-md5-key` incorrecta en la conexión `hacia-ISP-1` del EDGE, la sesión cae en el momento (modificar la conexión la reinicia), queda `Idle` con `prefix-count=0` y no vuelve a establecerse; la salida pasa a ISP-2. Con la clave real, desde KeePassXC, la sesión vuelve a `E` y recupera sus 2 prefijos (`11-EDGE-bgp-*.png` en `capturas/F4/`). Al reponerla, el primer pegado dejó la consola esperando el cierre de unas comillas; se canceló con Ctrl+C y se volvió a pegar |
| VRRP auth | Grupos 10 (USERS, `ether3`) y 20 (SERVERS, `ether4`) en DIST-1 y DIST-2 (F2): `version=2`, `authentication=simple`, claves `<CLAVE_VRRP_10>` y `<CLAVE_VRRP_20>`. Se fija la versión 2 porque RouterOS crea los grupos en versión 3 por defecto, y según su documentación la autenticación está obsoleta en VRRP v3 | Un solo master por grupo, con la misma clave en los dos routers: DIST-1 master del 10 y DIST-2 master del 20, los dos con `authentication=simple` (`02-DIST-*-vrrp.png` en `capturas/F2/`). Si las claves o las versiones no coincidieran, cada router se creería master. Los gateways virtuales responden (`03-*-ping-gateway.png`). **En F4:** en los drills 1 y 5 el backup tomó la IP virtual cuando cayó el master y la devolvió cuando el master volvió, con la autenticación activa. Después de los drills, `/interface vrrp print detail` en DIST-1 sigue mostrando `authentication=simple` y versión 2 en los dos grupos, sin mostrar la clave (`12-DIST-1-vrrp-auth.png` en `capturas/F4/`). No se hizo prueba con clave incorrecta en VRRP: la consigna la pide para OSPF y BGP |
| Firewall/ACL (edge) | EDGE (F3), según 1.3: listas `gestion` (loopbacks y LAN SERVERS) y `lans`, lista de interfaces `WAN` (`ether1`, `ether2`); 8 reglas en `input` (conexiones en curso, inválidas, SSH/Winbox solo desde `gestion`, BGP solo desde cada ISP, OSPF solo desde `10.0.0.0/24`, ICMP, drop del resto) y 4 en `forward` (conexiones en curso, inválidas, drop de conexiones nuevas desde `WAN`, salida desde `lans`). El ICMP se acepta sin límite: la política dice "ICMP limitado", pero se dejó sin `limit=` porque el ping se usa en todas las verificaciones y en los drills de F4 | PC-USER → ISP-1 responde (`10-…`); ISP-1 → `10.10.0.100` no responde, y la regla de forward "nada nuevo desde los ISP" contó esos 4 paquetes (`11-…`, `14-EDGE-firewall-stats.png`); ISP-1 → EDGE por ICMP responde (`12-…`); SSH de ISP-1 al EDGE no llega a pedir contraseña, y el contador de la regla de drop final pasó de 0 a 6 paquetes de 60 bytes, los intentos de conexión descartados (`13-…`). BGP y OSPF siguen arriba (`09-…`) |

**Prueba de seguridad obligatoria (F4):** con una clave incorrecta, la adyacencia OSPF y la sesión BGP **fallan** (filas de OSPF MD5 y BGP TCP-MD5). En los dos casos se volvió a la clave real desde KeePassXC y se verificó que todo volviera a levantar.

**El failover no degradó la seguridad (F4).** Verificado al terminar los drills (`12-*.png` en `capturas/F4/`):

- OSPF: `auth=md5 auth-id=1` sigue en los templates de enlaces de CORE-2 y DIST-1.
- VRRP: `authentication=simple`, versión 2, en los dos grupos de DIST-1.
- Firewall del EDGE: las 12 reglas siguen. Desde ISP-1, `ping 10.10.0.100` no responde, y la regla de forward "nada nuevo desde los ISP hacia adentro" pasa de 0 a 4 paquetes descartados (contadores antes y después).
- Los `.rsc` post-F4 de los 7 routers son idénticos a las configuraciones de `configs/`: los drills no dejaron rutas, claves incorrectas ni cambios sueltos (6.2).

---

## 6. Gestión operativa

### 6.1 Change log

| Fecha | Responsable | Cambio | Motivo | Cómo se revierte |
|-------|-------------|--------|--------|------------------|
| `2026-10-02` | R5 — Lautaro Aubert | `bc8e884` `chore(repo): estructura inicial del repositorio` | Epic F0 — Repositorio git | `git revert bc8e884` |
| `2026-10-02` | R1 — Santiago Natalichio Bestosini | `99a4d27` `docs(ipam): plan de direccionamiento, política de operación y diagrama lógico` | Epic F0 — IPAM y política de operación | `git revert 99a4d27` |
| `2026-10-02` | R2/R3 — Tomás Martin | `7dc34ad` `docs(diseno): corrección del diagrama y política de seguridad` | Epic F0 — Corrección del diagrama y política de seguridad | `git revert 7dc34ad` |
| `2026-10-02` | R4 — Juan Bautista Cuenca | `ba3fc2d` `docs(ipam): grupos VRRP con load-sharing` | Epic F0 — IPAM (grupos VRRP) | `git revert ba3fc2d` |
| `2026-10-02` | R5 — Lautaro Aubert | `0186c8d` `docs(operacion): backlog inicial con F0` | Epic F0 — Repositorio git (backlog) | `git revert 0186c8d` |
| `2026-10-02` | R5 — Lautaro Aubert | `ef36474` `ops(changelog): registro de commits F0` | Epic F0 — Change log | `git revert ef36474` |
| `2026-10-10` | R2 — Tomás Martin | `c9865b2` `feat(isp): ips, loopback y hardening en ISP-1 e ISP-2` | Epic F1 — IPs de enlace + loopbacks y hardening (incluye la baja del cliente DHCP de fábrica) | `git revert c9865b2`; en el router, `/system reset-configuration no-defaults=yes` vuelve a la configuración vacía. Este estado se recupera con `backups/2026-10-10/ISP-1.rsc` e `ISP-2.rsc` (procedimiento en 6.2) |
| `2026-10-10` | R3 — Tomás Martin | `96102b5` `feat(core): ips, loopback y hardening en CORE-1 y CORE-2` | Epic F1 — IPs de enlace + loopbacks y hardening (incluye la baja del cliente DHCP de fábrica) | `git revert 96102b5`; en el router, `/system reset-configuration no-defaults=yes` vuelve a la configuración vacía. Este estado se recupera con `backups/2026-10-10/CORE-1.rsc` y `CORE-2.rsc` (procedimiento en 6.2) |
| `2026-10-10` | R1 — Santiago Natalichio Bestosini | `9cd5746` `feat(edge): ips, loopback y hardening en EDGE` | Epic F1 — IPs de enlace + loopbacks y hardening (incluye la baja del cliente DHCP de fábrica) | `git revert 9cd5746`; en el router, `/system reset-configuration no-defaults=yes` vuelve a la configuración vacía. Este estado se recupera con `backups/2026-10-10/EDGE.rsc` (procedimiento en 6.2) |
| `2026-10-10` | R4 — Juan Bautista Cuenca | `3d2c717` `feat(dist): ips, loopback y hardening en DIST-1 y DIST-2` | Epic F1 — IPs de enlace + loopbacks y hardening (incluye la baja del cliente DHCP de fábrica) | `git revert 3d2c717`; en el router, `/system reset-configuration no-defaults=yes` vuelve a la configuración vacía. Este estado se recupera con `backups/2026-10-10/DIST-1.rsc` y `DIST-2.rsc` (procedimiento en 6.2) |
| `2026-10-10` | R2/R3 — Tomás Martin | `0571943` `docs(seguridad): claves reales fuera del repo` | Observación del docente en F0 — gestor de secretos y marcadores en lugar de claves | `git revert 0571943` |
| `2026-10-10` | R2 — Tomás Martin | `a11e092` `docs(seguridad): agrego baja del cliente DHCP de fábrica al hardening` | Epic F1 — Hardening: el CHR trae un cliente DHCP de fábrica que el diseño no usa | `git revert a11e092`; en el router, `/ip dhcp-client add interface=ether1` |
| `2026-10-10` | R5 — Lautaro Aubert | `94e9a65` `ops(backup): backup post-F1` | Epic F1 — Backup inicial (`/export` de los 7 routers) | `git revert 94e9a65` |
| `2026-10-10` | R5 — Lautaro Aubert | `6ad0ee8` `docs(memoria): topologia, snapshot BASE y restore probado` | Epic F1 — Despliegue, snapshot BASE, verificación del hardening y restore probado | `git revert 6ad0ee8` |
| `2026-10-10` | R5 — Lautaro Aubert | `7d7ea49` `ops(changelog): registro F1 y backlog actualizado` | Epic F1 — Change log y backlog | `git revert 7d7ea49` |
| `2026-10-10` | R5 — Lautaro Aubert | `75e63bd` `docs(repo): actualizo estado de fases en el README` | Repositorio git — tabla de estado del README | `git revert 75e63bd` |
| `2026-10-16` | R4 — Juan Bautista Cuenca | `a694097` `feat(vrrp): grupos 10 y 20 con load-sharing y autenticacion en DIST-1 y DIST-2` | Epic F2 — VRRP (2 grupos, load-sharing, auth) | `git revert a694097`; en el router, se vuelve al estado anterior con `backups/2026-10-10/DIST-1.rsc` y `DIST-2.rsc` (procedimiento en 6.2) |
| `2026-10-16` | R3 — Tomás Martin | `f369cc4` `feat(ospf): area 0 con md5 en CORE-1 y CORE-2` | Epic F2 — OSPF área 0 con MD5 (incluido core–core) | `git revert f369cc4`; en el router, se vuelve al estado anterior con `backups/2026-10-10/CORE-1.rsc` y `CORE-2.rsc` (procedimiento en 6.2) |
| `2026-10-16` | R1 — Santiago Natalichio Bestosini | `7a3128a` `feat(ospf): area 0 con md5 en EDGE` | Epic F2 — OSPF área 0 con MD5 + ruta por defecto hacia adentro (`originate-default=if-installed`) | `git revert 7a3128a`; en el router, se vuelve al estado anterior con `backups/2026-10-10/EDGE.rsc` (procedimiento en 6.2) |
| `2026-10-16` | R4 — Juan Bautista Cuenca | `7cd8582` `feat(ospf): area 0 con md5 en DIST-1 y DIST-2, LANs pasivas` | Epic F2 — OSPF área 0 con MD5, LANs como interfaces pasivas | `git revert 7cd8582`; en el router, se vuelve al estado anterior con la versión de `configs/DIST-1.rsc` y `DIST-2.rsc` del commit de VRRP (procedimiento en 6.2, con las claves de VRRP desde KeePassXC) |
| `2026-10-16` | R5 — Lautaro Aubert | `ccee084` `ops(backup): backup post-F2 y evidencia de VRRP y OSPF` | Epic F2 — Verificación L3, backup post-F2 y capturas | `git revert ccee084` |
| `2026-10-16` | R2 — Tomás Martin | `6c5ddfc` `feat(bgp): ebgp con tcp-md5, default-originate y anuncio del loopback en ISP-1 e ISP-2` | Epic F3 — eBGP multi-homing con TCP-MD5; el anuncio del loopback permite que el host alcance los dos ISP (ver 4.1) | `git revert 6c5ddfc`; en el router, se vuelve al estado anterior con `backups/2026-10-16/ISP-1-postF2.rsc` e `ISP-2-postF2.rsc` (procedimiento en 6.2) |
| `2026-10-16` | R1 — Santiago Natalichio Bestosini | `7d25b6a` `feat(bgp): ebgp con tcp-md5 y redistribucion de LANs en EDGE` | Epic F3 — eBGP multi-homing con TCP-MD5 y redistribución OSPF→BGP (solo las LANs) | `git revert 7d25b6a`; en el router, se vuelve al estado anterior con `backups/2026-10-16/EDGE-postF2.rsc` (procedimiento en 6.2, con la clave de OSPF desde KeePassXC) |
| `2026-10-16` | R1 — Santiago Natalichio Bestosini | `eee3812` `feat(firewall): filtro input y forward en EDGE` | Epic F3 — Firewall edge (filtro de entrada + plano de gestión protegido) | `git revert eee3812`; en el router, `/ip firewall filter remove [find]` quita las reglas (las listas no filtran por sí solas) |
| `2026-10-16` | R5 — Lautaro Aubert | `fd193e4` `ops(backup): backup post-F3 y evidencia de BGP y firewall` | Epic F3 — Salida a "Internet", verificación del firewall, backup post-F3 y capturas | `git revert fd193e4` |
| `2026-10-16` | R5 — Lautaro Aubert | `a1b7aa3` `docs(memoria): verificacion y seguridad de F2 y F3` | Epics F2 y F3 — Verificación (4.1), seguridad aplicada (5), backups (6.2) y capturas (7) | `git revert a1b7aa3` |

> Un commit no puede contener su propio hash: cada commit `ops(changelog): …` (R5) completa las filas de su fase y queda registrado en la actualización siguiente.


### 6.2 Backups

> Evidencia de backup (`/export` + `/system backup save`) y de **restore probado**. (F1 en adelante)

**Backup post-F1 (2026-10-10):**

| Qué | Cómo | Dónde |
|-----|------|-------|
| Export en texto de los 7 routers | `/export` en cada router, con el snapshot `BASE` ya tomado | `backups/2026-10-10/<ROUTER>.rsc` y, como configuración vigente, `configs/<ROUTER>.rsc` |
| Backup binario de los 7 routers | `/system backup save name=<ROUTER>-20261010-F1` | Dentro de cada router (capturas `15-*-backup-binario.png`). No se versiona: incluye usuarios y contraseñas |
| Snapshot GNS3 | `BASE` (ver sección 2) | Máquina donde corre el laboratorio |

- Los `.rsc` se revisaron antes de commitear: no contienen contraseñas ni claves, y no incluyen el cliente DHCP de fábrica.
- Antes de dar por bueno un export se mira la sección `/interface ethernet`: si alguna línea trae `name=`, el router detectó las placas en otro orden en ese arranque (ver el incidente de la sección 2) y ese `.rsc` no se puede importar en un router recién reseteado. Pasó con DIST-2 (captura `14-DIST-2-interfaces-nombre-de-fabrica.png`): el router funcionaba, pero se reinició el nodo y se volvió a exportar para tener un backup importable.

**Restore probado (F1): ISP-2, 2026-10-10.** Se eligió ISP-2 porque tiene un solo enlace. Procedimiento base, según la política de 1.4:

1. `/export file=ISP-2-20261010-postF1`, que deja el `.rsc` dentro del router.
2. `/system reset-configuration no-defaults=yes skip-backup=yes`. Borra la configuración; los archivos del router se conservan.
3. `/import file-name=ISP-2-20261010-postF1.rsc`.
4. Volver a cargar la clave de `admin` y el usuario `monitor`, porque el export no trae usuarios ni contraseñas.
5. Verificar con ping al vecino y comparar el `/export` con el backup.

*Intento 1: no pasó.* Después del reset `/ip address print` salió vacío y el import respondió `Script file loaded and executed successfully`, pero el ping hacia EDGE dio `no route to host`. Causa: tras el reset, RouterOS volvió a nombrar las placas y la del cable hacia EDGE (MAC `…00:00`) quedó como `ether4`, así que la dirección se cargó en un puerto sin cable (capturas `16-restore-intento-1-*.png`). Además, el reset volvió a crear el cliente DHCP de fábrica en `ether1`, aunque se usó `no-defaults=yes`. El texto de la configuración estaba restaurado, pero el router no tenía conectividad.

*Intento 2: pasó.* Un segundo reset dejó las placas en el mismo orden, así que se agregó un paso antes de importar: fijar los nombres por MAC (`/interface ethernet set [find mac-address=<MAC>] name=<nombre>`, pasando por nombres temporales). Después se importó el `.rsc`, se quitó el cliente DHCP (`/ip dhcp-client remove [find]`) y se recrearon los usuarios (tras el reset, `admin` figuraba como `E - expired`, sin contraseña). Resultado (capturas `17-restore-intento-2-*.png`):

- `ether1` con la MAC `…00:00` y con enlace; usuarios y servicios igual que antes del reset.
- Ping ISP-2 → EDGE y EDGE → ISP-2: 4 de 4.
- El `/export` posterior, tomado después de reiniciar el nodo, es **idéntico a `backups/2026-10-10/ISP-2.rsc`** salvo la hora del encabezado (comparado con `diff`).

Procedimiento de restore que queda para esta plataforma: reset → verificar el orden de las placas por MAC y corregirlo si hace falta → import → quitar el cliente DHCP → recrear usuarios → ping al vecino → export y comparación. Un restore no se da por probado hasta que el ping responde: en el intento 1 la configuración coincidía y el router estaba aislado.

**Backups de F2 y F3 (2026-10-16).** Las dos fases se hicieron en la misma sesión, así que comparten la carpeta y se distinguen por el sufijo:

| Qué | Cómo | Dónde |
|-----|------|-------|
| Snapshot GNS3 previo | `pre-F2`, con los nodos apagados, antes de tocar nada (`01-snapshot-pre-F2.png`) | Máquina donde corre el laboratorio |
| Export "antes" | `/export file=<ROUTER>-20261016-preF2` en los 7 routers | Dentro de cada router (punto de vuelta atrás, no se versiona) |
| Export post-F2 | `/export` de los 7 routers al terminar VRRP y OSPF, y `/export file=<ROUTER>-20261016-postF2` dentro de cada uno | `backups/2026-10-16/<ROUTER>-postF2.rsc` |
| Backup binario post-F2 | `/system backup save name=<ROUTER>-20261016-F2` | Dentro de cada router (`07-*-backup-binario.png` en `capturas/F2/`) |
| Export post-F3 | `/export` de los 7 routers al terminar BGP y firewall, y `/export file=<ROUTER>-20261016-postF3` dentro de cada uno | `backups/2026-10-16/<ROUTER>-postF3.rsc` y, como configuración vigente, `configs/<ROUTER>.rsc` |
| Backup binario post-F3 | `/system backup save name=<ROUTER>-20261016-F3` | Dentro de cada router (`15-*-backup-binario.png` en `capturas/F3/`) |
| Snapshot GNS3 | `F2F3`, con los nodos apagados (`16-snapshot-F2F3.png`) | Máquina donde corre el laboratorio |

- Antes de guardar cada export se buscaron `auth-key`, `tcp-md5-key` y `password`: RouterOS 7 no incluye esos datos en `/export`, y no apareció ninguno. **Por eso un restore desde un `.rsc` de F2 en adelante necesita volver a cargar las claves de OSPF, BGP y VRRP desde KeePassXC**, además de los usuarios (paso 4 del procedimiento).
- Dos veces se guardó un archivo con el nombre de otro router: los exports "antes" de seis routers salieron con el nombre de ISP-1, y el backup binario post-F2 de ISP-2 con el de EDGE. Se borraron con `/file remove` y se rehicieron con el nombre correcto; las capturas muestran el estado corregido. Mismo error que el backup de EDGE en F1: conviene revisar el prompt del router antes de pegar cada bloque.

**Incidente: el orden de detección de las placas cambia en cada arranque.** Al prender la red desde el snapshot `pre-F2`, los 7 routers tenían cada nombre en su MAC correcta (`ether1` = `…00:00`, …) y las direcciones en su cable, pero en todos el `default-name` no coincidía con el nombre: en la mayoría, `ether1` tenía `default-name=ether2` y al revés. Se probó un reinicio en caliente (`/system reboot`) y uno en frío (Stop/Start del nodo en GNS3) sobre ISP-2: los dos dejaron las placas en otro orden distinto. Como el orden cambia en cada arranque, reiniciar hasta que coincida no es viable. Todos los exports de F2 y F3 traen entonces líneas `set [ find default-name=… ] … name=…` en `/interface ethernet`. **Decisión del grupo:** se versionan tal cual los genera RouterOS, sin editarlos, y el procedimiento de restore suma un paso: después de fijar los nombres por MAC, y antes de importar, se quitan del `.rsc` las líneas con `name=` de `/interface ethernet` (renombrarían las placas según el orden de ese arranque). Esto reemplaza el chequeo de F1 de "reiniciar el nodo y volver a exportar". La causa de fondo probable (placas `e1000` en vez de `virtio-net-pci`) sigue como tarea en el backlog.

**Backup post-F4 (2026-10-22/23).**

| Qué | Cómo | Dónde |
|-----|------|-------|
| Snapshot GNS3 previo | `pre-F4`, con los nodos apagados (`01-snapshot-pre-F4.png`) | Máquina donde corre el laboratorio |
| Export "antes" | `/export file=<ROUTER>-20261022-preF4` en los 7 routers | Dentro de cada router (punto de vuelta atrás, no se versiona) |
| Export post-F4 | `/export` de los 7 routers al terminar drills y restore | `backups/2026-10-22/<ROUTER>-postF4.rsc` |
| Export y backup binario dentro del router | `/export file=<ROUTER>-20261022-postF4` y `/system backup save name=<ROUTER>-20261022-F4` | Dentro de cada router (`14-*-backup-binario.png`) |
| Snapshot GNS3 | `F4`, con los nodos apagados (`15-snapshot-F4.png`) | Máquina donde corre el laboratorio |

- Los 7 `.rsc` post-F4 son **idénticos** a `configs/` salvo la hora del encabezado: los drills no dejaron cambios en la red. No tienen claves; el nombre de la comunidad SNMP se reemplazó por `<COMUNIDAD_SNMP>`.
- Se repitió el error de F2: el export dentro del router quedó con el nombre del EDGE en los 7. Se borró y se rehízo con `/export file=([/system identity get name] . "-20261022-postF4")`, que arma el nombre con la identidad del propio router y evita el error de raíz. Queda como forma de hacer los próximos backups.

**Restore probado (F4): CORE-2.** Se eligió CORE-2 porque tiene clave de OSPF (prueba la carga de claves desde KeePassXC) y porque lo operó alguien distinto de R3 (dirigió R5), como pidió el docente.

1. `/export file=CORE-2-20261022-preRestore` e `/interface ethernet print` para anotar la MAC de cada placa (`13-CORE-2-antes-del-restore.png`).
2. Antes del reset apareció un `autosupout.rif` que nadie había generado: CORE-2 se había colgado y reiniciado solo durante la sesión (ver 8). Se diagnosticó antes de seguir, porque el reset borra el log (`13-CORE-2-diagnostico.png`).
3. `/system reset-configuration no-defaults=yes skip-backup=yes`. Esta vez las placas quedaron en orden (`13-CORE-2-interfaces-tras-reset.png`) y el `.rsc` no tenía líneas `name=`.
4. `/import file-name=CORE-2-20261022-preRestore.rsc` **se cortó** en la línea del template de OSPF: `auth-key must be specified` (`13-CORE-2-import-error-auth-key.png`). El export no trae la clave y RouterOS no acepta un template `auth=md5` sin clave, así que el script se detiene ahí: lo anterior quedó aplicado y lo posterior no (el router seguía llamándose `MikroTik`).
5. Con un `/export` se vio exactamente qué faltaba y se cargó a mano: el template de OSPF **con** la clave desde KeePassXC, y las líneas que seguían (template del loopback, `/snmp`, identidad, bandwidth-server y mac-server). Después, `/ip dhcp-client remove [find]` y los usuarios `admin` y `monitor` con sus claves desde KeePassXC.
6. Verificación (`13-CORE-2-restore-verificacion.png`): solo `admin` y `monitor`; 4 vecinos OSPF en Full; ping al EDGE 4 de 4; comunidad SNMP de solo lectura y `public` deshabilitada. El `/export` posterior es **idéntico** al de antes del restore salvo la hora (comparado con `diff`).

**Procedimiento de restore actualizado.** El anterior decía "importar y después cargar las claves": sirvió en F1 (ISP-2, sin OSPF), pero en un router con OSPF MD5 el import se corta antes de llegar a ese paso. Queda así:

1. `/export file=<ROUTER>-<fecha>-preRestore` e `/interface ethernet print` (MAC de cada placa).
2. `/system reset-configuration no-defaults=yes skip-backup=yes`.
3. Entrar como `admin` sin clave. Revisar el orden de las placas por MAC; si no coincide, renombrarlas por MAC pasando por nombres temporales.
4. Si el `.rsc` tiene líneas `name=` en `/interface ethernet`, quitarlas antes de importar.
5. `/import`. Si se corta en una línea que necesita una clave (OSPF MD5; en VRRP con autenticación no se probó, pero hay que esperar lo mismo), cargar esa línea a mano con la clave desde KeePassXC y después el resto del archivo. Otra opción es quitar esas líneas del `.rsc` antes de importar y cargarlas a mano al final.
6. `/ip dhcp-client remove [find]` (el reset lo vuelve a crear).
7. Recrear `admin` y `monitor` con las claves de KeePassXC.
8. Verificar vecinos y sesiones, ping a los vecinos, y comparar el `/export` con el de antes usando `diff`.

### 6.3 Monitoreo

**Qué se monitorea (F4).** Los 5 routers de la empresa: EDGE, CORE-1, CORE-2, DIST-1 y DIST-2. Los ISP representan a otras organizaciones y en una red real no se monitorean desde la empresa; de ellos solo se vigila que su loopback responda, que es la forma de ver si cada enlace de salida funciona. El backlog decía "los 7 routers" y el grupo acordó corregirlo a los 5 de la empresa.

**Con qué:**

| Herramienta | Dónde | Qué hace |
|-------------|-------|----------|
| SNMP de solo lectura | Los 5 routers de la empresa | `/snmp` habilitado con contacto y ubicación. Comunidad de solo lectura (`write-access=no`) que solo acepta consultas desde las redes de gestión (loopbacks y LAN SERVERS). La comunidad `public` de fábrica queda deshabilitada (es la entrada por defecto de RouterOS y no se puede borrar). El nombre de la comunidad funciona como una contraseña: está en KeePassXC y en el repo figura `<COMUNIDAD_SNMP>` (`04-*-snmp.png`) |
| Netwatch | EDGE | Ping cada 10 s a los loopbacks de CORE-1, CORE-2, DIST-1, DIST-2, ISP-1 e ISP-2. Cada caída y cada vuelta queda en el log (`netwatch,info event down/up`). Antes de cargarlo se comprobó que registra los cambios sin necesidad de scripts, con un host inexistente (`05-EDGE-netwatch.png`) |

**Chequeos de salud** (antes y después de cada drill):

| Qué | Dónde | Comando | Esperado |
|-----|-------|---------|----------|
| VRRP | DIST-1 y DIST-2 | `/interface vrrp print` | DIST-1: `vrrp10` master, `vrrp20` backup. DIST-2: al revés |
| OSPF | EDGE, CORE-1, CORE-2, DIST-1, DIST-2 | `/routing ospf neighbor print` | 2, 4, 4, 2 y 2 vecinos en Full |
| BGP | EDGE | `/routing bgp session print` | 2 sesiones establecidas, `prefix-count=2` cada una |
| Ruta por defecto | EDGE | `/ip route print where dst-address=0.0.0.0/0` | Dos por BGP, activa la de ISP-1 |
| Conectividad | PC-USER y SRV | `ping 198.51.100.1`, `ping 198.51.100.2`, `ping 192.0.2.1` | Responden |
| Monitoreo | EDGE | `/tool netwatch print` y `/log print where topics~"netwatch"` | Las 6 entradas `up`; en el log, las caídas y vueltas de cada drill |

**Lo que registró netwatch durante los drills:** la caída y vuelta del loopback de CORE-1 en el drill 2 (A); en el corte silencioso del drill 2 (B), CORE-1, DIST-1 y DIST-2 a la vez (los DIST volvieron cuando reconvergió el EDGE y CORE-1 cuando reconvergió él mismo); ISP-1 en las dos variantes del drill 3. El corte con *Suspend* del drill 2 duró menos que su intervalo de 10 s y no quedó registrado.

**Limitaciones:**
- En el laboratorio no hay una estación que consulte SNMP (los hosts son VPCS). La verificación es `/snmp print` y `/snmp community print`.
- El firewall del EDGE descarta lo que no está permitido en `input`, incluido SNMP (UDP 161). Cuando haya un servidor de monitoreo hay que agregar una regla que acepte SNMP desde la lista `gestion`.
- Netwatch solo deja registro en el log. El cuelgue de CORE-2 durante la sesión (ver 8) recién se detectó horas después, al ver el archivo de diagnóstico. Mejora: que netwatch dispare un aviso (script o correo) y revisar su log después de cada drill.

---

## 7. Capturas

> Listar o enlazar la carpeta de capturas (drills, tablas, failover).

**F1: `capturas/F1/`**

| Archivos | Contenido |
|----------|-----------|
| `01-topologia.png` | Proyecto GNS3 con los 11 nodos y los 15 enlaces |
| `02-…` a `09-…` (un prefijo por router) | Por router: direcciones y hardening (`-ips-hardening`, `-hardening`, `-ips`), orden de interfaces (`-interfaces`), ping a los vecinos directos (`-ping-…`) y baja del cliente DHCP (`-sin-dhcp-client`) |
| `10-PC-USER-ip-ping.png`, `11-SRV-ip-ping.png` | IP, gateway y ping de los hosts a DIST-1 y DIST-2 |
| `12-snapshot-BASE.png`, `13-*-ping-post-snapshot.png` | Snapshot `BASE` y ping después de volver a prender los nodos |
| `14-DIST-2-*.png` | Export de DIST-2 con las interfaces en otro orden, y ping después del reinicio |
| `15-*-backup-binario.png` | Backup binario dentro de cada router (`/file print`) |
| `16-restore-intento-1-*.png`, `17-restore-intento-2-*.png` | Restore probado en ISP-2: intento fallido e intento correcto |

**F2: `capturas/F2/`**

| Archivos | Contenido |
|----------|-----------|
| `01-snapshot-pre-F2.png` | Snapshot `pre-F2` antes de tocar los routers |
| `02-DIST-1-vrrp.png`, `02-DIST-2-vrrp.png` | Grupos VRRP (master/backup, versión 2, auth `simple`) y las IP virtuales |
| `03-PC-USER-ping-gateway.png`, `03-SRV-ping-gateway.png` | Los gateways virtuales `10.10.0.1` y `10.20.0.1` responden |
| `04-*-ospf-vecinos.png` (5) | Vecinos OSPF Full en EDGE, CORE-1, CORE-2, DIST-1 y DIST-2 |
| `05-DIST-1-rutas-ospf.png` | Tabla de rutas de DIST-1 con las rutas aprendidas por OSPF |
| `06-*.png` | Ping PC-USER ↔ SRV y de DIST-1 a la loopback del EDGE |
| `07-*-backup-binario.png` (7) | Export y backup binario post-F2 dentro de cada router (`/file print`) |

**F3: `capturas/F3/`**

| Archivos | Contenido |
|----------|-----------|
| `01-EDGE-bgp-sesiones.png`, `02-EDGE-rutas-default-bgp.png` | Sesiones BGP del EDGE y las dos rutas por defecto |
| `03-ISP-1-bgp-rutas.png`, `03-ISP-2-bgp-rutas.png` | Sesión de cada ISP y las rutas que recibe (solo las dos LANs) |
| `04-DIST-1-ruta-default-ospf.png` | La ruta por defecto llega a DIST-1 por OSPF |
| `05-PC-USER-ping-ISP-2-sin-loopback-anunciado.png` | Ping a ISP-2 fallido antes del ajuste (ver 4.1), y `trace` a ISP-1 |
| `06-PC-USER-ping-trace-ISP-1-ISP-2.png` | Ping a los dos loopbacks y `trace` a ISP-2, después del ajuste |
| `07-EDGE-rutas-bgp-loopbacks-ISP.png`, `08-ISP-*-rutas-despues-del-anuncio.png` | Rutas BGP del EDGE con los loopbacks de cada ISP; los ISP siguen recibiendo solo las LANs |
| `09-EDGE-*-despues-firewall.png` | BGP y OSPF siguen arriba con el firewall aplicado |
| `10-…` a `13-…` | Pruebas del firewall: salida desde la LAN, ISP → LAN bloqueado, ICMP al EDGE, SSH desde ISP-1 bloqueado (contadores antes y después) |
| `14-EDGE-firewall-stats.png` | Contadores de las 12 reglas del firewall |
| `15-*-backup-binario.png` (7) | Export y backup binario post-F3 dentro de cada router |
| `16-snapshot-F2F3.png` | Snapshot `F2F3` |

**F4: `capturas/F4/`**

| Archivos | Contenido |
|----------|-----------|
| `01-snapshot-pre-F4.png` | Snapshot `pre-F4` antes de tocar los routers |
| `02-*-salud-inicial.png` (7) | Chequeo de salud inicial en EDGE, CORE-1, CORE-2, DIST-1, DIST-2, PC-USER y SRV |
| `03-*.png` | Destino de prueba `192.0.2.1` en los dos ISP, sin anunciar por BGP, y ping desde PC-USER |
| `04-*-snmp.png` (5), `05-EDGE-netwatch.png` | SNMP de solo lectura en los 5 routers de la empresa y netwatch en el EDGE |
| `06-drill1-*.png` | Drill 1: VRRP, caída de DIST-1 |
| `07-drill2-*.png` | Drill 2: OSPF, corte EDGE–CORE-1 (con interfaz, intento con *Suspend* y corte silencioso) |
| `08-drill3-*.png` | Drill 3: BGP, caída de ISP-1 (con interfaz y corte silencioso) |
| `09-drill4-*.png` | Drill 4: check-gateway |
| `10-drill5-*.png` | Drill 5: load-sharing VRRP |
| `11-*.png` | Prueba de clave incorrecta en OSPF (CORE-1) y BGP (EDGE), y vuelta a la clave real |
| `12-*.png` | El failover no degradó la seguridad: MD5 de OSPF, autenticación VRRP, contadores del firewall y bloqueo desde ISP-1 |
| `13-CORE-2-*.png` | Restore probado en CORE-2: estado previo, diagnóstico del cuelgue, reset, error del import y verificación |
| `14-*-backup-binario.png` (7) | Export y backup binario post-F4 dentro de cada router |
| `15-snapshot-F4.png` | Snapshot `F4` |

---

## 8. Conclusiones y lecciones aprendidas

**Qué salió bien.** La red sobrevivió a todas las fallas provocadas en F4: caída de un gateway, corte de un enlace interno, caída de un proveedor y caída del siguiente salto, sin intervención manual. Cada mecanismo hizo lo que el diseño de F0 prometía: VRRP en distribución, OSPF con el cable core–core y eBGP con dos proveedores. La seguridad quedó intacta después de los drills, y con una clave incorrecta OSPF y BGP no levantan. La configuración final coincide línea por línea con lo versionado, y el restore de un router con OSPF MD5 quedó probado.

**Tiempos medidos y por qué cada mecanismo tarda lo que tarda:**

| Mecanismo | Falla | Tiempo sin servicio | De qué depende |
|-----------|-------|:-------------------:|----------------|
| VRRP (drill 1) | Cae la pata LAN del master | ~16 s | *Master down interval*: 3 anuncios perdidos (intervalo 1 s) + *skew* ≈ 3,6 s teórico. La diferencia con lo medido no la explicamos |
| VRRP (drill 5) | Ídem, en el otro DIST | ~4 s | Ídem, más cerca de la teoría |
| OSPF (drill 2 A) | Se apaga la interfaz | ~2 s | El router ve caer su interfaz y recalcula al instante (SPF) |
| OSPF (drill 2 B) | El cable deja de pasar tráfico | ~35 s | *Dead interval* de 40 s desde el último *hello* (cada 10 s) + instalación de la ruta |
| BGP (drill 3 A) | Se apaga la interfaz hacia el ISP | ~2 s | No lo hace BGP: la ruta queda inactiva porque su *gateway* quedó en una interfaz apagada |
| BGP (drill 3 B) | El enlace con el ISP deja de pasar tráfico | ~160 s | *Hold time* de 180 s desde el último *keepalive* (cada 60 s) |
| check-gateway (drill 4) | El siguiente salto deja de responder | ~17 s | Dos pings fallidos al *gateway* (uno cada 10 s) |

La conclusión central: **lo que define el tiempo de failover es cómo se detecta la falla.** Si la falla apaga una interfaz, todo converge en segundos. Si es silenciosa, cada protocolo depende de su temporizador: OSPF espera 40 s y BGP hasta 3 minutos. BGP es el más lento porque une organizaciones distintas y cerrar una sesión por una pérdida corta obliga a retirar y volver a anunciar todas las rutas; por eso sus valores por defecto son conservadores. En una red real se complementa con detección rápida (BFD, temporizadores acordados con el proveedor o chequeos del siguiente salto como el del drill 4).

**Incidentes y lo que aprendimos de cada uno:**

| Fase | Incidente | Qué cambió en la operación |
|:----:|-----------|----------------------------|
| F1 | El orden en que RouterOS detecta las placas no coincide con el de GNS3: en ISP-1 la dirección quedó en un puerto sin cable | Chequeo de MAC por interfaz antes de configurar cada router (sección 2) |
| F1 | El primer restore (ISP-2) restauró el texto pero dejó al router aislado, por el mismo problema de placas | Un restore no se da por probado hasta que el ping responde; fijar las placas por MAC antes de importar (6.2) |
| F2 | El orden de las placas cambia en cada arranque; los exports traen líneas `name=` | Se quitan esas líneas del `.rsc` antes de un restore (6.2) |
| F2 y F4 | Exports y backups guardados con el nombre de otro router | En F4 se adoptó un export que toma el nombre de la identidad del router |
| F3 | El host no llegaba a ISP-2: cada ISP solo mandaba la ruta por defecto | Cada ISP anuncia también su loopback (4.1) |
| F4 | Se perdió la contraseña maestra de la base de KeePassXC | Las claves de OSPF, BGP y VRRP se recuperaron de los routers (con la sesión de `admin` abierta) y se pasaron a una base nueva, sin pasar por el chat ni por capturas. La contraseña maestra la tienen al menos dos integrantes y se prueba al cierre de cada sesión |
| F4 | CORE-2 se colgó y se reinició solo (`kernel failure`, archivo `autosupout.rif`); se detectó horas después | La configuración sobrevivió y la red siguió por CORE-1. Causa no confirmada. Al cierre de cada sesión se revisa el `uptime` y la presencia de `supout` en los 7 routers, y el log de netwatch después de cada drill |
| F4 | Los relojes de los routers no coinciden entre sí y se atrasaron más de 2 h durante la sesión (sin NTP) | Los tiempos se miden con ping y cronómetro; las horas del log solo se comparan dentro de un mismo router. Mejora: NTP |
| F4 | El *Suspend* de GNS3 no produce un corte silencioso (baja la señal de la placa) | Los cortes silenciosos se hacen con un filtro de pérdida del 100 % en el cable |
| F4 | El import de un router con OSPF MD5 se corta (`auth-key must be specified`) | Procedimiento de restore actualizado (6.2) |
| F4 | Errores de pegado en la consola (una ruta duplicada en el drill 4, comillas sin cerrar al reponer una clave) | Pegar de a un comando y revisar con `print` antes de seguir; claves solo con letras y números |

**Qué haríamos distinto:**
- **NTP en todos los routers** desde F1, para poder seguir un mismo evento en los logs de varios equipos.
- **Detección rápida de fallas:** BFD o temporizadores más cortos para OSPF y BGP.
- **Monitoreo con avisos**, no solo registro en el log.
- **Probar `virtio-net-pci`** en vez de `e1000` para ver si se resuelve el desorden de las placas (quedó pendiente en el backlog).
- **Repetir cada drill varias veces:** con una sola medición por caso, diferencias como la del drill 1 contra el 5 no se pueden explicar.
- **Custodia compartida de la contraseña maestra** del gestor de secretos desde el principio.

**Lecciones por área** (redactado por R5 con lo que aportó cada rol):
- **Edge / WAN (R1):** el multi-homing protege la salida, pero el tiempo de failover ante un corte silencioso depende de los temporizadores de BGP. El firewall no interfirió con ningún failover y siguió bloqueando lo que debía.
- **Proveedores y core (R2 + R3):** el cable core–core es lo que le da a CORE-1 un camino de respaldo. El destino de prueba en los ISP fue necesario para poder medir el cambio de proveedor de punta a punta.
- **Distribución (R4):** VRRP con los masters cruzados mantiene a los dos DIST trabajando. Su límite es que solo ve la caída del router o de su pata hacia la LAN.
- **Operación (R5):** sin el chequeo de salud antes y después de cada drill, el cuelgue de CORE-2 y el atraso de los relojes no se hubieran detectado. La evidencia (capturas numeradas, exports comparados con `diff`) permitió demostrar que la red quedó exactamente como estaba.

---

## 9. Referencias

- RFC 5798 — VRRP v3 · RFC 2281 — HSRP · RFC 2328 — OSPF v2 · RFC 4271 — BGP-4 · RFC 2385 — TCP-MD5 · RFC 5737 — IPv4 Address Blocks Reserved for Documentation
- Halabi, S. (2000). *Internet Routing Architectures* (multi-homing)
- Doyle & Carroll (2005). *Routing TCP/IP, Vol. I* (IGP, FHRP)
- MikroTik Wiki — VRRP, BGP, OSPF, check-gateway, Securing your router
- Análisis del diagrama viral (`analisis.md`, material de cátedra)
- MikroTik CHR 7.21.5 — Ayuda oficial de RouterOS 7 (https://help.mikrotik.com/docs/), páginas usadas: VRRP, OSPF, BGP, Route Selection and Filters, Filter (firewall), IP Routing (`check-gateway`), Configuration Management (`/export`, `/import`, `reset-configuration`), Backup, SNMP, Netwatch, Torch
- GNS3 — Documentación (https://docs.gns3.com/): snapshots y filtros de paquetes en los enlaces
- RFC 5880 — Bidirectional Forwarding Detection (BFD), citado como mejora en la sección 8

---

## 10. Checklist de entrega

### Diseño (F0)
- [x] IPAM completo y sin solapamiento
- [x] Corrección del diagrama justificada (≥ 3 defectos)
- [x] Política de seguridad definida (usuarios, servicios, claves)
- [x] Política de operación definida (change log + backup)

### Redes
- [x] 7 CHR + 2 switches + 2 hosts levantados y cableados
- [x] VRRP operativo (2 grupos, load-sharing)
- [x] OSPF área 0 con adyacencias (incluido core–core)
- [x] BGP eBGP ×2 establecido (multi-homing)
- [x] Los 5 drills ejecutados y documentados (runbook + post-mortem + tiempo)

### Seguridad
- [x] Hardening aplicado (password, usuario mínimo, servicios apagados)
- [x] OSPF MD5 funcionando
- [x] BGP TCP-MD5 funcionando
- [x] VRRP auth funcionando
- [x] Firewall edge aplicado
- [x] Prueba con clave incorrecta → debe **fallar** (documentado)

### Operación
- [ ] Change log completo (refleja los commits del repo)
- [x] Backups con restore probado
- [x] Monitoreo habilitado y documentado
- [x] Runbook por drill + post-mortem global

### Entrega
- [x] Memoria completa (todas las secciones de esta plantilla)
- [x] Repo git con la estructura correcta y commits por rol
- [ ] `backlog.md` con todas las tareas en "done"
- [x] Capturas en la carpeta `capturas/`
- [ ] Cada integrante puede defender su parte **y** una parte ajena

# Backlog — Laboratorio Failover Routing

> **Grupo:** 11 · **Vencimiento final:** vie 23/10

## Leyenda de estado

- `[ ]` pendiente · `[~]` en curso · `[x]` hecho · `~~tachada~~` descartada por el grupo (con el motivo)
- Cada tarea lleva **dueño** (rol): `[R1]` … `[R5]`.
- **"Hecho" = criterio de aceptación cumplido** (ver spec, sección 6). No "más o menos".

| Rol | Integrante | Responsabilidad |
|-----|-----------|-----------------|
| R1 | Santiago Natalichio Bestosini | Líder / Edge-WAN (EDGE, eBGP, firewall) |
| R2 | Tomás Martin | Proveedores (ISP-1, ISP-2) |
| R3 | Tomás Martin | Core (CORE-1, CORE-2, OSPF) |
| R4 | Juan Bautista Cuenca | Distribución (DIST-1, DIST-2, VRRP) |
| R5 | Lautaro Aubert | Hosts / QA / Ops (backlog, change log, backups, runbooks, drills) |

---

## Epic F0 — Diseño y gestión de cambio · *vence vie 2/10*

### IPAM / direccionamiento
- [x] [R1] definir bloques de direccionamiento (P2P, LANs, loopbacks, ISP) y convención de numeración
- [x] [R1] completar tabla de los 15 enlaces con subred, IP e interfaz de cada extremo
- [x] [R4] definir grupos VRRP (VRID 10/20, master, priority, IP virtual) con load-sharing
- [x] [R3] asignar loopbacks / router-ids a los 7 routers y verificar cero solapamiento

### Corrección del diagrama (≥ 3 defectos)
- [x] [R3] documentar defectos 3 y 4 (falta core–core, HSRP en el core) con corrección y justificación
- [x] [R1] documentar defectos 1 y 5 (firewall SPOF, iBGP RR mal ubicado) con corrección y justificación
- [x] [R4] documentar defecto 2 (subredes solapadas) y vincularlo al IPAM

### Política de seguridad
- [x] [R2] definir usuarios y privilegios (`admin` full, `monitor` read) y reglas de uso
- [x] [R2] definir servicios a deshabilitar en `/ip service` y restricciones de acceso a ssh/winbox
- [x] [R1] definir claves de autenticación OSPF MD5, BGP TCP-MD5 (por ISP) y VRRP (por grupo)
- [x] [R1] definir lineamientos del firewall del EDGE (input / forward)

### Política de operación (change log + backup)
- [x] [R5] definir formato del change log (Conventional Commits + tabla 6.1 con alcances válidos)
- [x] [R5] definir política de backup (cuándo, cómo, dónde, restore probado)

### Repositorio git
- [x] [R5] crear repo `goys-failover-grupo11` con la estructura de la spec (README, backlog, carpetas)
- [x] [R5] dar acceso de lectura al docente y a todos los integrantes
- [x] [R1..R5] cada integrante hace su commit inicial siguiendo la convención (trazabilidad por autor)
- [x] [R1] enviar F0 al docente y registrar observaciones → aprobación (gate)

---

## Epic F1 — Topología + hardening + backup · *vence vie 9/10*

### Despliegue (7 CHR + 2 switches + 2 hosts)
- ~~[R1..R5] verificar GNS3 + imagen CHR instalados en cada laptop~~ — descartada por el grupo el 23/10: el laboratorio corrió siempre en la PC del anfitrión (R1) y el resto participó dirigiendo cada paso en la llamada; no se usó en ninguna fase
- [x] [R5] armar el proyecto GNS3 `Failover-G11` desde cero (7 CHR + 2 switches + 2 VPCS) y verificar 11 nodos / 15 enlaces
- [x] [R5] contrastar numeración `etherN` del proyecto con la tabla IPAM; corregir tabla si difiere (change log) — sin diferencias, la tabla no cambió

### IPs de enlace + loopbacks
- [x] [R2] configurar IPs y loopbacks en ISP-1 e ISP-2
- [x] [R1] configurar IPs y loopback en EDGE
- [x] [R3] configurar IPs y loopbacks en CORE-1 y CORE-2 (incluido core–core)
- [x] [R4] configurar IPs (P2P + LAN) y loopbacks en DIST-1 y DIST-2
- [x] [R5] configurar PC-USER y SRV (IP + gateway virtual) y hacer ping a cada vecino directo

### Snapshot BASE
- [x] [R5] tomar snapshot GNS3 `BASE` y documentarlo en la memoria (sección 2)

### Hardening (los 7 routers)
- [x] [R2] aplicar password `admin` + usuario `monitor` + servicios apagados en ISP-1/ISP-2
- [x] [R1] ídem en EDGE
- [x] [R3] ídem en CORE-1/CORE-2
- [x] [R4] ídem en DIST-1/DIST-2
- [x] [R5] verificar con `/ip service print` y `/user print` en los 7 routers
- [x] [R2] agregar a la política 1.3 la baja del cliente DHCP de fábrica (aplicada en los 7 routers)

### Backup inicial (`/export`)
- [x] [R5] `/export` de los 7 routers → `backups/2026-10-10/` + commit `ops(backup): backup post-F1`
- [x] [R5] probar restore de un router desde su `.rsc` y documentar (sección 6.2)

### Observaciones del docente sobre F0
- [x] [R2] definir el gestor de secretos (KeePassXC) y reemplazar las claves de la memoria por marcadores
- [x] [R1] crear la base KeePassXC, cargar las claves de `admin` y `monitor` y compartirla con el grupo (antes de configurar claves en F2)

---

## Epic F2 — VRRP + OSPF · *vence vie 16/10*

### Pendientes que vienen de F1
- [ ] [R1] probar en un nodo suelto si cambiar las placas de los CHR de `e1000` a `virtio-net-pci` evita el desorden de interfaces (memoria, sección 2) — no se hizo en F4 por tiempo; queda como mejora (memoria 8)

### VRRP (2 grupos, load-sharing, auth)
- [x] [R4] configurar VRRP vrid 10 en DIST-1 (master, priority 200) y DIST-2 (backup, 100)
- [x] [R4] configurar VRRP vrid 20 en DIST-2 (master, priority 200) y DIST-1 (backup, 100)
- [x] [R4] activar auth simple en ambos grupos con las claves de 1.3 (VRRP versión 2: en v3 la auth está obsoleta)
- [x] [R5] verificar master/backup con `/interface vrrp print` y ping al gateway virtual desde los hosts

### OSPF área 0 (con MD5, incluido core–core)
- [x] [R3] configurar OSPF área 0 en CORE-1/CORE-2 (todas las P2P + loopback) con MD5
- [x] [R1] configurar OSPF en EDGE (hacia ambos CORE) con MD5 + default-route
- [x] [R4] configurar OSPF en DIST-1/DIST-2 (P2P activas, LANs pasivas) con MD5
- [x] [R5] verificar adyacencias FULL con `/routing ospf neighbor print` en todos los routers

### Verificación L3 (ping intra-LAN + gateway virtual)
- [x] [R5] ping PC-USER ↔ SRV, ping a loopbacks internos, capturas → `capturas/F2/`
- [x] [R5] backup post-F2 + change log

---

## Epic F3 — BGP + firewall · *vence vie 16/10*

### eBGP multi-homing (2 sesiones, TCP-MD5)
- [x] [R2] configurar eBGP en ISP-1 (AS 65001) e ISP-2 (AS 65002) con default-originate y TCP-MD5
- [x] [R1] configurar eBGP en EDGE (AS 65000) hacia ambos ISP con TCP-MD5
- [x] [R5] verificar `established` con `/routing bgp session print`

### Redistribución OSPF→BGP
- [x] [R1] redistribuir las LANs 10.10.0.0/24 y 10.20.0.0/24 hacia BGP (filtro de salida)
- [x] [R2] verificar que los ISP reciben las LANs

### Salida a "Internet" (host → loopback ISP)
- [x] [R2] anunciar el loopback de cada ISP por BGP para que el host alcance los dos (ajuste de F3, memoria 4.1)
- [x] [R5] ping/traceroute desde PC-USER a 198.51.100.1 y 198.51.100.2, capturas

### Firewall edge (filtro + plano de gestión)
- [x] [R1] implementar reglas input/forward definidas en 1.3
- [x] [R5] verificar que ssh/winbox solo entran desde redes de gestión (SSH desde ISP-1 bloqueado, con contadores); backup post-F3

---

## Epic F4 — Drills + monitoreo · *vence mar 20/10* · entregada con F5 el vie 23/10 (ver README)

> Rotación obligatoria R1 ↔ R2 en esta fase.

### Los 5 drills (runbook + post-mortem + tiempo)
- [x] [R5] escribir plantilla de runbook (detección → respuesta → recuperación → post-mortem) en `runbooks/`
- [x] [R4]+[R5] Drill 1 VRRP: apagar DIST-1, medir tiempo, runbook
- [x] [R3]+[R5] Drill 2 OSPF: cortar EDGE↔CORE-1, medir reconvergencia, runbook (corte con interfaz y corte silencioso)
- [x] [R1..R5] definir qué otro integrante opera CORE-1/CORE-2 junto a R3 en el drill 2 (observación del docente en F0) — R4 dirigió el drill 2 con R3 al lado, y R5 el restore de CORE-2
- [x] [R2→R1]+[R5] Drill 3 BGP: cortar ISP-1↔EDGE, medir conmutación, runbook (corte con interfaz y corte silencioso)
- [x] [R1→R2]+[R5] Drill 4 check-gateway: failover estático, runbook
- [x] [R4]+[R5] Drill 5 load-sharing: demostrar ambos DIST activos, runbook

### Monitoreo (SNMP/chequeos)
- [x] [R5] habilitar SNMP (comunidad de solo lectura) en los 5 routers de la empresa y documentar — corregido de "los 7 routers": los ISP representan a otras organizaciones (memoria 6.3)
- [x] [R5] definir chequeos (vecinos OSPF, sesiones BGP, estado VRRP) — más netwatch en el EDGE (memoria 6.3)

### Verificación de seguridad (clave incorrecta falla)
- [x] [R3] cambiar clave OSPF en un extremo → adyacencia cae; capturar y revertir
- [x] [R1] cambiar clave BGP en un extremo → sesión cae; capturar y revertir
- [x] [R5] backup post-F4 + change log

### Restore probado (política 1.4, una vez en F4)
- [x] [R5] probar restore de un router con config de F2/F3: fijar placas por MAC, quitar del `.rsc` las líneas `name=` de `/interface ethernet`, importar y volver a cargar las claves desde KeePassXC (memoria 6.2) — CORE-2: el import se cortó en el template OSPF sin clave; se completó a mano y se actualizó el procedimiento

---

## Epic F5 — Memoria + defensa · *vence vie 23/10*

### Memoria (plantilla completa)
- [x] [R1..R5] cada rol completa sus secciones de configuración (3.x) y seguridad (5)
- [x] [R5] completa gestión operativa (6), capturas (7) y conclusiones (8)

### Backlog cerrado (todo en "hecho")
- [x] [R5] revisar que cada tarea cumple su criterio de aceptación; cerrar — queda abierta, con su motivo, la prueba de `virtio-net-pci`; la instalación de GNS3 en cada laptop se descartó

### Defensa oral (parte propia + ajena)
- [x] [R1..R5] asignar a cada integrante una parte ajena para defender y ensayar

| Integrante | Parte propia | Parte ajena |
|---|---|---|
| Santiago (R1) | EDGE: BGP, redistribución, firewall | ISP y drill 3 (lo dirigió en la rotación) |
| Tomás (R2+R3) | ISP (BGP, default-originate, destino de prueba) y CORE (OSPF, core–core, MD5) | EDGE: check-gateway (drill 4) y firewall |
| Juan Bautista (R4) | DIST: VRRP, load-sharing, OSPF de los DIST | CORE: drill 2 y reconvergencia OSPF |
| Lautaro (R5) | Operación: change log, backups, restore, monitoreo, runbooks | VRRP y los drills 1 y 5 |

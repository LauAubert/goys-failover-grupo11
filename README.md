# goys-failover-grupo11 — Grupo 11 · Laboratorio "Failover Routing: la red que no se cae"

**Materia:** Gestión Operativa y Seguridad en Redes (GOYS) — UTN FR La Plata
**Simulador:** GNS3 · MikroTik CHR (RouterOS 7)
**Vencimiento final:** viernes 23/10/2026

## Integrantes y roles

> Grupo de 4 integrantes: R2 y R3 los cubre la misma persona (ambos son roles de routers de tránsito; R2 es el de menor carga).

| Rol | Integrante | Responsabilidad |
|-----|-----------|-----------------|
| R1 — Líder / Edge-WAN | Santiago Natalichio Bestosini | EDGE: eBGP ×2, redistribución, BGP MD5, firewall |
| R2 — Proveedores | Tomás Martin | ISP-1 / ISP-2: default-originate, eBGP, hardening |
| R3 — Core | Tomás Martin | CORE-1 / CORE-2: OSPF, core–core, OSPF MD5 |
| R4 — Distribución | Juan Bautista Cuenca | DIST-1 / DIST-2: VRRP (auth), OSPF, gateways |
| R5 — Hosts / QA / Ops | Lautaro Aubert | Hosts, drills, backlog, change log, backups, runbooks |

## Resumen del laboratorio

Red empresarial jerárquica de 5 capas (Internet → Edge → Core → Distribución → Acceso) con
7 routers MikroTik CHR, 2 switches y 2 hosts, que sobrevive a fallas de enlace y de nodo mediante:

- **VRRP** en distribución (redundancia de gateway, 2 grupos con load-sharing)
- **OSPF área 0** en el interior (reconvergencia ante cortes, con MD5)
- **eBGP multi-homing** en el edge contra dos ISPs (con TCP-MD5)

Se corrigen 5 defectos del diagrama viral "Enterprise Network Design (Cisco)" y se integran
seguridad (hardening, autenticación del plano de control, firewall) y operación (change log, backups,
monitoreo, runbooks y 5 drills de failover).

## Estado

| Fase | Contenido | Vence | Estado |
|:----:|-----------|:-----:|--------|
| F0 | Diseño + políticas + repo | vie 2/10 | 🟡 entregado, esperando aprobación |
| F1 | Topología + hardening + backup | vie 9/10 | ⚪ pendiente |
| F2 | VRRP + OSPF | vie 16/10 | ⚪ pendiente |
| F3 | BGP + firewall | vie 16/10 | ⚪ pendiente |
| F4 | Drills + monitoreo | mar 20/10 | ⚪ pendiente |
| F5 | Memoria + defensa | vie 23/10 | ⚪ pendiente |

## Estructura del repositorio

```
├── README.md          # este archivo
├── backlog.md         # tareas por epic con dueño y estado
├── docs/
│   ├── memoria.md     # memoria del lab (sección 1 = F0)
│   └── diagramas/     # topología y diagramas de diseño
├── configs/           # .rsc finales por router (F1–F3)
├── backups/           # /export por fecha (F1 en adelante)
├── runbooks/          # un .md por drill (F4)
└── capturas/          # screenshots por fase/drill
```

## Convención de commits

`tipo(alcance): descripción` — tipos: `feat`, `fix`, `docs`, `ops`, `chore`. Detalle en `docs/memoria.md` sección 1.4.
Cada integrante commitea su propia parte.

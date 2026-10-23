# Drill 5 — Load-sharing VRRP: los dos DIST trabajan a la vez

- Fecha y hora: entre el drill 4 (reloj del EDGE `00:51`) y la prueba de clave OSPF (reloj de CORE-1 `01:07`). Sesión de laboratorio del 22/10/2026 a la madrugada del 23/10 (snapshot `pre-F4` a las 19:37 y snapshot `F4` a la 01:19, hora local). Las horas de este runbook son las del **reloj del router** que se indica: los routers no tienen NTP y su reloj se fue atrasando durante la sesión (al empezar iban ~3 h adelante de la hora local y al terminar ~40 min), así que no se convierten a hora local. Los tiempos medidos no dependen de esos relojes.
- Dirigió: Juan Bautista Cuenca · Ejecutó en consola: Santiago Natalichio Bestosini (anfitrión de GNS3) · Midió: Lautaro Aubert
- Mecanismo que se prueba: VRRP con dos grupos y los masters cruzados (memoria 1.2). DIST-1 es master del grupo 10 (LAN USERS, gateway `10.10.0.1`) y backup del 20. DIST-2 es master del grupo 20 (LAN SERVERS, gateway `10.20.0.1`) y backup del 10. Los dos routers trabajan siempre, y cada uno es el respaldo del otro.

## Estado inicial (precondiciones)

Chequeo de salud en verde (fin del drill 4).

`/interface vrrp print` (`10-drill5-DIST-1-vrrp.png`, `10-drill5-DIST-2-vrrp.png`):

| Router | `vrrp10` (USERS) | `vrrp20` (SERVERS) |
|---|:-:|:-:|
| DIST-1 | `RM` master, prioridad 200 | `B` backup, prioridad 100 |
| DIST-2 | `B` backup, prioridad 100 | `RM` master, prioridad 200 |

## Demostración: cada DIST atiende una LAN

No se rompe nada. Se mira por dónde sale cada host:

- **PC-USER** (LAN USERS), `trace 198.51.100.1`: primer salto **`10.10.0.2` (DIST-1)** (`10-drill5-PC-USER-trace.png`).
- **SRV** (LAN SERVERS), `trace 198.51.100.1`: primer salto **`10.20.0.3` (DIST-2)** (`10-drill5-SRV-trace.png`).

Los dos hosts usan como gateway la IP virtual `.1` de su LAN, pero la atiende un router distinto. Así los dos DIST cargan tráfico al mismo tiempo, en vez de tener uno trabajando y otro esperando.

## Falla provocada (parte opcional: cae DIST-2)

Para mostrar que cada uno es el respaldo del otro, con un ping continuo en las dos PCs (`ping 198.51.100.1 -t`), en DIST-2:

```routeros
/interface disable ether4
```

Apaga la pata de DIST-2 hacia la LAN SERVERS.

## Detección

El ping de SRV deja de responder en `icmp_seq` 10 y 11 (`10-drill5-SRV-ping-y-trace-DIST-2-caido.png`).

## Respuesta

DIST-1 toma también el grupo 20: queda como master de las dos LANs. `trace 198.51.100.1` desde SRV: el primer salto pasa a ser **`10.20.0.2` (DIST-1)** (`10-drill5-SRV-ping-y-trace-DIST-2-caido.png`).

## Recuperación

En DIST-2, `/interface enable ether4`. DIST-2 recupera el master del grupo 20 por prioridad (200 contra 100): `vrrp20` otra vez en `RM` (`10-drill5-DIST-2-vuelta.png`).

No se guardaron el ping de SRV durante la vuelta, el ping de PC-USER ni el log VRRP de los dos DIST: no se puede saber si el grupo 10 cambió de estado por un instante, como pasó con el grupo 20 en el drill 1.

## Tiempo medido

| Momento | Respuestas perdidas (SRV → `198.51.100.1`) | Tiempo sin servicio |
|---|:-:|:-:|
| Caída de DIST-2 | 2 (`icmp_seq` 10 y 11) | ~4 s |
| Vuelta de DIST-2 | sin captura | no medido |

Cómo se midió: ping continuo desde SRV. En VPCS cada `timeout` equivale a ~2 s (calibrado con cronómetro en el drill 3).

## Post-mortem

**Por qué funcionó:** con dos grupos VRRP y los masters cruzados, cada DIST es gateway de una LAN y respaldo de la otra. Cuando uno cae, el otro toma su IP y su MAC virtual, y los hosts no se enteran.

**Comparación con el drill 1.** Es el mismo mecanismo, en el router y la LAN opuestos. Acá el corte fue de ~4 s, cerca de la teoría: el *master down interval* de un backup con prioridad 100 es 3 × 1 s + 0,61 s ≈ 3,6 s. En el drill 1 fue de ~16 s (8 `timeout`). No encontramos la causa de la diferencia. Como cada caso se midió una sola vez, no alcanza para decir cuál es el valor típico. Para eso habría que repetir cada uno varias veces.

**Qué aprendimos:** el load-sharing con VRRP no reparte el tráfico de un mismo host entre dos routers. Reparte **grupos de hosts**: cada LAN usa un router. Si una LAN tuviera mucho más tráfico que la otra, la carga no quedaría pareja.

## Evidencia

- `capturas/F4/10-drill5-DIST-1-vrrp.png`, `10-drill5-DIST-2-vrrp.png`
- `capturas/F4/10-drill5-PC-USER-trace.png`, `10-drill5-SRV-trace.png`
- `capturas/F4/10-drill5-SRV-ping-y-trace-DIST-2-caido.png`
- `capturas/F4/10-drill5-DIST-2-vuelta.png`

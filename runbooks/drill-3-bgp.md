# Drill 3 — BGP: se cae ISP-1

- Fecha y hora: de `00:14` a `00:25`, reloj del EDGE. Sesión de laboratorio del 22/10/2026 a la madrugada del 23/10 (snapshot `pre-F4` a las 19:37 y snapshot `F4` a la 01:19, hora local). Las horas de este runbook son las del **reloj del router** que se indica: los routers no tienen NTP y su reloj se fue atrasando durante la sesión (al empezar iban ~3 h adelante de la hora local y al terminar ~40 min), así que no se convierten a hora local. Los tiempos medidos no dependen de esos relojes.
- Dirigió y ejecutó en consola: Santiago Natalichio Bestosini (rotación R1 → ISP: el drill rompe el enlace con ISP-1, a cargo de Tomás Martin) · Midió: Lautaro Aubert
- Mecanismo que se prueba: multi-homing con eBGP. El EDGE recibe una ruta por defecto de cada ISP (`default-originate`), las dos con distancia 20, y usa la de ISP-1. Si ISP-1 se cae, la empresa tiene que salir por ISP-2.
- Temporizadores BGP (`/routing bgp session print` en EDGE): `hold-time=3m`, `keepalive-time=1m`.

## Estado inicial (precondiciones)

En EDGE (`08-drill3-EDGE-antes.png`): ruta por defecto activa (`DAb`) por `203.0.113.1` (ISP-1) y la de `203.0.113.5` (ISP-2) en espera. Las 2 sesiones BGP establecidas (`E`).

**Destino de la medición: `192.0.2.1`.** Es una dirección que tienen los dos ISP y que no se anuncia por BGP (memoria 1.2), así que la responde el ISP por el que sale la empresa. Los loopbacks de los ISP no sirven, porque cada uno se alcanza siempre por su propio ISP. El `trace` tampoco distingue el proveedor (siempre muestra `EDGE → 192.0.2.1`). Para ver por dónde sale el tráfico se usa **torch** en el EDGE: `ether1` = ISP-1, `ether2` = ISP-2. Antes del corte, torch en `ether1` muestra el ping `10.10.0.100` ↔ `192.0.2.1` (`08-drill3-EDGE-torch-ether1-antes.png`).

Ping continuo desde PC-USER: `ping 192.0.2.1 -t`.

## Falla provocada

**Variante A — corte que se ve.** En EDGE:

```routeros
/interface disable ether1
```

**Variante B — corte silencioso.** En GNS3, **filtro de pérdida de paquetes del 100 %** en el cable ISP-1 ↔ EDGE (clic derecho → *Packet filters*). El cable deja de pasar tráfico, pero las placas mantienen la señal (`ether1` sigue con `R`). En el drill 2 se vio que el *Suspend* de GNS3 no sirve para esto, porque baja la señal.

## Detección

**Variante A.**
- `/ip route print` en EDGE: la ruta de ISP-1 queda `DIb` (**inactiva**), porque su *gateway* `203.0.113.1` quedó en una interfaz apagada (`08-drill3-A-EDGE-respuesta.png`).
- **La sesión BGP con ISP-1 sigue `E`**, y el log de BGP no registra ninguna caída. BGP no se enteró: la interfaz se volvió a habilitar antes de que venciera el *hold time*.
- Netwatch en EDGE: loopback de ISP-1 `down` a las `00:14:20` y `up` a las `00:14:37`.

**Variante B.**
- Netwatch en EDGE: loopback de ISP-1 `down` a las `00:19:10` (`08-drill3-B-EDGE-netwatch.png`).
- Un minuto después del corte (`08-drill3-B-EDGE-durante.png`): `ether1` sigue con `R`, **la ruta por defecto sigue activa por ISP-1** y la sesión sigue `E`. El EDGE sigue mandando todo a un proveedor que no responde.
- Desde `icmp_seq=35`, el EDGE (`10.0.0.5`) contesta a PC-USER `Destination host unreachable` en una de cada dos solicitudes. No consigue resolver la dirección MAC de ISP-1 (el ARP no pasa por el cable), pero tampoco saca la ruta.
- Log del EDGE: `00:21:35 route,bgp,error HoldTimer expired hacia-ISP-1-1` y la sesión pasa a `Idle` (`08-drill3-B-EDGE-respuesta.png`). `/routing bgp session print` muestra `last-stopped=2026-10-23 00:21:35` y la notificación de BGP enviada al cerrar (código de error 4: *Hold Timer Expired*).

## Respuesta

- **Variante A:** la ruta por defecto activa pasa a ser la de `203.0.113.5` (ISP-2) en el momento del corte (`08-drill3-A-EDGE-respuesta.png`). El ping a `192.0.2.1` sigue respondiendo; ahora contesta ISP-2.
- **Variante B:** al vencer el *hold time*, BGP retira las rutas de ISP-1 y queda una sola ruta por defecto, la de ISP-2 (`DAb 0.0.0.0/0 203.0.113.5`). `ether2` está arriba (`08-drill3-B-EDGE-ether2-ruta.png`). El ping de PC-USER vuelve en `icmp_seq=109`.

## Recuperación

- **Variante A:** `/interface enable ether1`. La sesión con ISP-1 nunca había caído (su `uptime` sigue corriendo, `08-drill3-A-EDGE-recuperacion-sesiones.png`), y la ruta de ISP-1 vuelve a ser la activa.
- **Variante B:** se saca el filtro del cable. BGP vuelve a conectarse solo: la sesión con ISP-1 se restablece a las `00:23:21` (`last-started`, `08-drill3-B-EDGE-recuperacion-sesiones.png`) y la ruta por defecto vuelve a ISP-1. En la vuelta se pierde 1 respuesta (`icmp_seq=217`).

Chequeo de salud final (`08-drill3-salud-final-EDGE.png`, `08-drill3-salud-final-PC-USER.png`): ruta por defecto activa otra vez por ISP-1, `198.51.100.1/32` aprendido por ISP-1 y `198.51.100.2/32` por ISP-2, 2 sesiones `E` con `prefix-count=2` cada una. PC-USER llega a los dos loopbacks y a `192.0.2.1`. Justo después de volver, la sesión con ISP-1 mostraba `prefix-count=1`: las rutas todavía estaban llegando.

## Tiempo medido

| Variante | Respuestas perdidas (PC-USER → `192.0.2.1`) | Tiempo sin servicio |
|---|:-:|:-:|
| A — `disable ether1` en EDGE (corte + vuelta) | 1 (`icmp_seq=39`) | ~2 s |
| B — corte silencioso | 93 (`icmp_seq` 16 a 108) | **~160 s** (2 min 40 s, cronómetro) |
| B — vuelta | 1 (`icmp_seq=217`) | ~2 s |

Cómo se midió: ping continuo desde PC-USER y, en la variante B, **cronómetro** desde que se puso el filtro (el ping iba por `icmp_seq=15`) hasta la primera respuesta. De las 93 respuestas perdidas, 56 fueron `timeout` y 37 `Destination host unreachable`. Esta medición sirvió para calibrar VPCS: cada `timeout` equivale a unos 2 s.

**Comparación con la teoría.** BGP da por caído al vecino cuando pasa el *hold time* (180 s) sin recibir nada de él. Los *keepalive* llegan cada 60 s, así que, según cuándo llegó el último, la sesión cae entre 120 y 180 s después del corte. Con las horas del propio EDGE: netwatch vio la caída a las `00:19:10` (el corte fue entre `00:19:00` y `00:19:10`, porque netwatch revisa cada 10 s) y el *hold timer* venció a las `00:21:35`, es decir, entre 145 y 155 s después. El cronómetro (160 s) coincide, sumando el tiempo de reacción.

## Post-mortem

**Por qué funcionó:** el EDGE tiene dos rutas por defecto, una por proveedor. Cuando la de ISP-1 deja de servir, queda la de ISP-2 sin que nadie toque nada.

**Qué aprendimos:**
- **El failover rápido de la variante A no lo hizo BGP.** La sesión siguió establecida todo el tiempo. Lo que pasó es que el router desactivó la ruta porque su *gateway* quedó en una interfaz apagada. Si la falla apaga la interfaz, el cambio es inmediato aunque BGP no se entere.
- **En un corte silencioso, BGP es lento a propósito.** Con los valores por defecto (*keepalive* 60 s, *hold* 180 s) tardó unos 2 min 40 s. Durante ese tiempo el EDGE mandó todo el tráfico a un proveedor que no respondía, aunque ni siquiera podía resolver su dirección MAC.
- **Por qué BGP tarda más que OSPF** (drill 2, corte silencioso: ~35 s): OSPF manda *hellos* cada 10 s y da por caído al vecino a los 40 s. BGP manda *keepalives* cada 60 s y espera 180 s. BGP está pensado para sesiones entre organizaciones, muchas veces a través de enlaces largos, donde cerrar la sesión por una pérdida corta sería peor (se retiran y vuelven a anunciar todas las rutas). OSPF corre dentro de la red propia y puede ser más agresivo.

**Qué cambiaríamos:**
- Bajar los temporizadores de BGP con los ISP (por ejemplo, *hold* de 9 s y *keepalive* de 3 s) o usar BFD, que detecta la caída en menos de un segundo. Las dos opciones requieren acuerdo con el proveedor.
- Complementar con un chequeo del siguiente salto. Es lo que prueba el drill 4 (`check-gateway`).

## Evidencia

- `capturas/F4/08-drill3-EDGE-antes.png`, `08-drill3-EDGE-torch-ether1-antes.png`
- `capturas/F4/08-drill3-A-EDGE-respuesta.png`, `08-drill3-A-EDGE-recuperacion-sesiones.png`
- `capturas/F4/08-drill3-A-PC-USER-ping-1.png` a `-3.png`
- `capturas/F4/08-drill3-B-EDGE-durante.png`, `08-drill3-B-EDGE-respuesta.png`, `08-drill3-B-EDGE-ether2-ruta.png`, `08-drill3-B-EDGE-netwatch.png`
- `capturas/F4/08-drill3-B-PC-USER-ping-1.png` a `-5.png`
- `capturas/F4/08-drill3-B-EDGE-recuperacion-sesiones.png`
- `capturas/F4/08-drill3-salud-final-EDGE.png`, `08-drill3-salud-final-PC-USER.png`

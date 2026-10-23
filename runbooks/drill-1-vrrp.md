# Drill 1 — VRRP: se cae el gateway

- Fecha y hora: corte a las `23:46:39` y vuelta a las `23:48:02`, reloj de DIST-1. Sesión de laboratorio del 22/10/2026 a la madrugada del 23/10 (snapshot `pre-F4` a las 19:37 y snapshot `F4` a la 01:19, hora local). Las horas de este runbook son las del **reloj del router** que se indica: los routers no tienen NTP y su reloj se fue atrasando durante la sesión (al empezar iban ~3 h adelante de la hora local y al terminar ~40 min), así que no se convierten a hora local. Los tiempos medidos no dependen de esos relojes.
- Dirigió: Juan Bautista Cuenca · Ejecutó en consola: Santiago Natalichio Bestosini (anfitrión de GNS3) · Midió: Lautaro Aubert
- Mecanismo que se prueba: VRRP v2 con autenticación en DIST-1 y DIST-2. Grupo 10 (LAN USERS, IP virtual `10.10.0.1`): DIST-1 master con prioridad 200, DIST-2 backup con 100. Intervalo de anuncios: 1 s.

## Estado inicial (precondiciones)

Chequeo de salud completo en verde (`02-*-salud-inicial.png`): DIST-1 master del grupo 10 y backup del 20, DIST-2 al revés; 7 adyacencias OSPF en Full; 2 sesiones BGP establecidas.

Desde PC-USER, `trace 198.51.100.1`: el primer salto es `10.10.0.2`, DIST-1 (`06-drill1-PC-USER-trace-antes.png`).

Ping continuo desde PC-USER durante el drill: `ping 198.51.100.1 -t`. Se cortó para hacer el `trace` durante la falla y se volvió a lanzar, así que el ping de la vuelta es otra corrida: su `icmp_seq` arranca de nuevo.

## Falla provocada

En DIST-1:

```routeros
/interface disable ether3
```

Apaga la pata de DIST-1 hacia la LAN USERS, que es la forma de simular la caída del gateway que usa el laboratorio de VRRP de la cátedra. DIST-1 deja de mandar anuncios VRRP del grupo 10 a esa LAN. El log de DIST-1 registra el cambio: `23:46:39 system,info device changed by console:admin ... (/interface set ether3 disabled=yes ...)`.

## Detección

- **En el host:** el ping de PC-USER deja de responder a partir de `icmp_seq=18` (`06-drill1-PC-USER-ping-corte.png`).
- **En DIST-2:** el log registra `23:46:36 vrrp10 now MASTER, master down timer`, y `/interface vrrp print` muestra `vrrp10` en `RM` (`06-drill1-DIST-2-vrrp-master.png`). "Master down timer" significa que DIST-2 tomó el control porque dejó de recibir anuncios de DIST-1 durante el tiempo de espera. Al apagarse la interfaz, DIST-1 no llega a avisar que se va.
- **En DIST-1:** `vrrp10` queda en `I` (inválida), porque su interfaz está apagada (`06-drill1-DIST-1-durante-falla.png`).

## Respuesta

DIST-2 toma la IP virtual `10.10.0.1` y la MAC virtual del grupo (`00:00:5E:00:01:0A`). PC-USER no cambia nada: sigue apuntando al mismo gateway y a la misma MAC.

- El ping vuelve a responder en `icmp_seq=26`.
- `trace 198.51.100.1` desde PC-USER: el primer salto pasa a ser `10.10.0.3`, DIST-2 (`06-drill1-PC-USER-trace-durante.png`).

## Recuperación

En DIST-1:

```routeros
/interface enable ether3
```

En el log de DIST-1, la interfaz se habilita a las `23:48:02` y tiene enlace a las `23:48:03`. DIST-1 vuelve a master del grupo 10 por prioridad (200 contra 100) a las `23:48:13`, **11 s después de habilitar la interfaz**: `vrrp10 now MASTER, master down timer` (`06-drill1-DIST-1-recuperacion.png`). Mientras tanto, DIST-2 siguió atendiendo como master, por eso la vuelta no cortó el servicio. DIST-2 vuelve a backup del grupo 10 y sigue master del 20 (`06-drill1-DIST-2-salud-final.png`).

Ping durante la vuelta: **ninguna respuesta perdida**. Una sola respuesta tardó más de lo normal (`icmp_seq=37`, 858 ms contra unos 6 ms de las demás) (`06-drill1-PC-USER-ping-vuelta.png`).

## Tiempo medido

| Momento | Respuestas perdidas | Tiempo sin servicio |
|---|:-:|:-:|
| Caída de DIST-1 | 8 (`icmp_seq` 18 a 25) | ~16 s |
| Vuelta de DIST-1 | 0 | 0 s (una respuesta demorada 858 ms) |

Cómo se midió: ping continuo desde PC-USER; se cuentan los `timeout`. En VPCS cada `timeout` equivale a unos **2 s**: espera 1 s la respuesta y después deja 1 s antes de la siguiente solicitud. Lo calibramos con cronómetro en el drill 3 (93 respuestas perdidas, 56 de ellas `timeout`, en unos 160 s). Por eso 8 `timeout` son unos 16 s, no 8.

**Por qué no se usan las horas de distintos routers:** el log de DIST-2 registra que tomó el master a las `23:46:36`, 3 s *antes* del corte según el log de DIST-1 (`23:46:39`). Como eso no puede pasar, los relojes de los dos routers no coinciden (el de DIST-2 va atrasado más de 3 s): los routers no tienen NTP. Las horas del log solo se comparan dentro de un mismo router; el tiempo sin servicio sale del ping.

**Comparación con la teoría.** En VRRP v2 el backup espera el *master down interval*: 3 × intervalo + *skew time*, con skew = (256 − prioridad) / 256. Para DIST-2 (prioridad 100, intervalo 1 s): 3 + 0,61 ≈ **3,6 s**. El corte medido (~16 s) es bastante mayor. No medimos en detalle de dónde salen los segundos de más. Lo que sí sabemos es que VRRP no es lo único que tiene que cambiar: el switch de la LAN tiene que aprender que la MAC virtual ahora está en el puerto de DIST-2, y OSPF tiene que dejar de mandarle a DIST-1 el tráfico de vuelta hacia `10.10.0.0/24`.

## Post-mortem

**Por qué funcionó:** el host no apunta a un router sino a una IP y una MAC virtuales que pueden moverse de un router al otro. Cuando el master deja de anunciarse, el backup las toma y el host no tiene que reconfigurarse.

**Qué aprendimos:**
- Al apagar la interfaz, el master no avisa que se va (no manda un anuncio con prioridad 0), así que el backup tiene que esperar el temporizador completo. Una caída ordenada sería más rápida.
- La vuelta del master con más prioridad no cortó el servicio (preemption), pero sí produjo un pequeño retraso.
- **Observación no prevista:** 2 s después del corte (reloj de DIST-1: corte `23:46:39`), DIST-1 pasó a master del grupo 20 (SERVERS) durante 1 s (`23:46:41 vrrp20 now MASTER, master down timer`), y volvió a backup al recibir el anuncio de DIST-2 (`23:46:42 ... got higher priority 200 from 10.20.0.3`). Ese grupo no se tocó en el drill. Durante ese segundo hubo dos masters en la LAN SERVERS. No confirmamos la causa, y como SRV no tenía un ping corriendo, no sabemos si lo afectó.
- **Limitación de VRRP** (la marca la cátedra): VRRP solo detecta la caída del router o de su pata hacia la LAN. Si DIST-1 perdiera sus dos enlaces hacia los CORE pero siguiera vivo en la LAN, seguiría siendo master y los hosts quedarían sin salida. Ese caso lo cubre OSPF, no VRRP.

**Qué cambiaríamos:**
- Para repetirlo, dejar también un ping continuo desde SRV, para ver si el efecto sobre el grupo 20 corta algo.
- Que quien mide anote la hora local de cada comando, además de las del log.
- Sincronizar los relojes de los routers con NTP, para poder seguir un mismo evento en el log de varios routers. No se agregó en F4 porque es un cambio de diseño.

## Evidencia

- `capturas/F4/06-drill1-PC-USER-trace-antes.png`
- `capturas/F4/06-drill1-PC-USER-ping-corte.png`
- `capturas/F4/06-drill1-DIST-2-vrrp-master.png`
- `capturas/F4/06-drill1-DIST-1-durante-falla.png`
- `capturas/F4/06-drill1-PC-USER-trace-durante.png`
- `capturas/F4/06-drill1-DIST-1-recuperacion.png`
- `capturas/F4/06-drill1-PC-USER-ping-vuelta.png`
- `capturas/F4/06-drill1-DIST-2-salud-final.png`

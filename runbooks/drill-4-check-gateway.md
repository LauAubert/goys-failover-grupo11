# Drill 4 — check-gateway: failover estático

- Fecha y hora: desde `00:50:57`, reloj del EDGE. Sesión de laboratorio del 22/10/2026 a la madrugada del 23/10 (snapshot `pre-F4` a las 19:37 y snapshot `F4` a la 01:19, hora local). Las horas de este runbook son las del **reloj del router** que se indica: los routers no tienen NTP y su reloj se fue atrasando durante la sesión (al empezar iban ~3 h adelante de la hora local y al terminar ~40 min), así que no se convierten a hora local. Los tiempos medidos no dependen de esos relojes.
- Dirigió: Tomás Martin (rotación R2 → EDGE: el drill se hace en el router de Santiago) · Ejecutó en consola: Santiago Natalichio Bestosini (anfitrión de GNS3) · Midió: Lautaro Aubert
- Mecanismo que se prueba: el failover más simple, sin protocolo dinámico. Son dos rutas por defecto escritas a mano, y el router deja de usar la principal cuando su siguiente salto no responde al ping (`check-gateway=ping`).

## Estado inicial (precondiciones)

Chequeo de salud en verde (fin del drill 3): las 2 sesiones BGP establecidas y la ruta por defecto de BGP activa por ISP-1.

**Cómo se arma sin romper BGP.** Se agregan dos rutas por defecto estáticas. Tienen menor distancia que las de eBGP (1 y 2 contra 20), así que mientras existen mandan ellas. BGP sigue funcionando por debajo y vuelve a mandar cuando se borran: no hay que apagar BGP ni tocar los ISP. En EDGE:

```routeros
/ip route add dst-address=0.0.0.0/0 gateway=203.0.113.1 check-gateway=ping distance=1 comment="drill 4: principal ISP-1"
/ip route add dst-address=0.0.0.0/0 gateway=203.0.113.5 check-gateway=ping distance=2 comment="drill 4: respaldo ISP-2"
```

`/ip route print where dst-address=0.0.0.0/0`: queda activa (`As`) la estática de distancia 1 por `203.0.113.1`. Las dos de BGP quedan en espera (`09-drill4-EDGE-rutas-antes.png`).

*Error al cargarlo:* al pegar los comandos se mezclaron dos líneas y la ruta de respaldo quedó creada **dos veces** (dos filas iguales con el comentario "drill 4: respaldo ISP-2"). No cambió el resultado: cuando se activaron, el router las tomó como dos caminos iguales (marca `+`, ECMP) hacia el mismo siguiente salto. Al final se borraron todas juntas.

Ping continuo desde PC-USER: `ping 192.0.2.1 -t` (el destino que responde el ISP activo, ver memoria 1.2).

## Falla provocada

El caso que resuelve check-gateway es **"el enlace sigue arriba pero el siguiente salto no responde"**. Por eso la falla se provoca del lado del ISP y no apagando la interfaz del EDGE (eso desactivaría la ruta sin necesidad de check-gateway, como pasó en la variante A del drill 3). En ISP-1:

```routeros
/interface disable ether1
```

En EDGE, `/interface print where name=ether1`: **`ether1` sigue con `R`** (running). El EDGE no ve ningún problema en su interfaz (`09-drill4-EDGE-ether1-sigue-arriba.png`).

## Detección

El EDGE manda un ping a `203.0.113.1` cada 10 s (así funciona `check-gateway=ping`). Cuando deja de recibir respuesta, marca ese *gateway* como inalcanzable y desactiva la ruta. En `/ip route print`, la estática de ISP-1 pasa a `Is` (inactiva) (`09-drill4-EDGE-rutas-durante.png`).

El log del EDGE no registra el cambio: check-gateway no deja un mensaje propio. La evidencia es la tabla de rutas y el ping.

## Respuesta

Queda activa la estática de distancia 2 por `203.0.113.5` (ISP-2) (`As+`, por la ruta duplicada). El ping de PC-USER a `192.0.2.1` vuelve a responder: ahora contesta ISP-2.

## Recuperación

En ISP-1, `/interface enable ether1`. El EDGE vuelve a recibir respuesta al ping de check-gateway y la estática de ISP-1 vuelve a estar activa (`09-drill4-EDGE-rutas-vuelta.png`).

Después se borran las rutas del drill, que **no quedan** en la configuración final:

```routeros
/ip route remove [find comment~"drill 4"]
```

Chequeo de salud final (`09-drill4-EDGE-salud-final.png`): quedan solo las 2 rutas por defecto de BGP, activa la de ISP-1, y las 2 sesiones `E`. La sesión con ISP-1 **no se cayó** durante el drill: su `uptime` viene desde `00:23:21`, de antes del drill. El corte duró menos que el *hold time* de BGP (3 min).

## Tiempo medido

| Momento | Respuestas perdidas (PC-USER → `192.0.2.1`) | Tiempo sin servicio |
|---|:-:|:-:|
| Corte (ISP-1 deja de responder) | sin captura del ping | **~17 s** (cronómetro) |
| Vuelta | sin captura del ping | no medido |

Cómo se midió: cronómetro desde el `disable` en ISP-1 (el ping de PC-USER iba por `icmp_seq=10`) hasta la primera respuesta, El ping de PC-USER corrió durante todo el drill, pero no se guardó la captura, así que no hay conteo de respuestas perdidas ni medición de la vuelta.

**Comparación con la teoría.** check-gateway hace un ping al siguiente salto cada 10 s y da al *gateway* por caído cuando falla dos veces seguidas. Según en qué momento del ciclo de 10 s cae el corte, eso da **entre 10 y 20 s**. Medido: ~17 s.

## Post-mortem

**Por qué funcionó:** la ruta principal depende de que el siguiente salto conteste un ping, no solo de que la interfaz esté arriba. Cuando ISP-1 dejó de contestar, el EDGE pasó a la ruta de respaldo aunque su interfaz estaba perfecta.

**Comparación con el drill 3 (BGP), mismo tipo de corte:**

| | Corte silencioso | Qué lo detecta |
|---|:-:|---|
| BGP (drill 3, variante B) | ~160 s | Vence el *hold time* (180 s desde el último *keepalive*) |
| check-gateway (drill 4) | ~17 s | Dos pings fallidos al siguiente salto (cada 10 s) |

**Cuándo conviene cada uno:**
- **check-gateway:** barato y rápido de armar, sin protocolo y sin acordar nada con el proveedor. Detecta rápido que el siguiente salto no responde. Su límite es que solo prueba el primer salto: si el router del ISP contesta el ping pero el ISP no tiene salida a Internet, la ruta sigue activa. Y no anuncia nada: el ISP no sabe cómo llegar a la empresa si no se le configura a mano.
- **BGP:** es el multi-homing real. La empresa anuncia sus redes a los dos proveedores (por eso el tráfico de vuelta también cambia de camino), y elige qué rutas acepta y cuáles manda. Con los temporizadores por defecto tarda mucho en detectar un corte silencioso. Se acelera bajando *keepalive* y *hold*, o con BFD.
- En la práctica se combinan: BGP para el intercambio de rutas y un mecanismo de detección rápida (BFD, o temporizadores más cortos).

**Qué cambiaríamos:** pegar los comandos de a uno y revisar con `print` antes de seguir, para no duplicar rutas como pasó acá.

Las rutas del drill no quedan en ningún export. Para repetirlo, se usan los comandos de arriba.

## Evidencia

- `capturas/F4/09-drill4-EDGE-rutas-antes.png`
- `capturas/F4/09-drill4-EDGE-ether1-sigue-arriba.png`
- `capturas/F4/09-drill4-EDGE-rutas-durante.png`
- `capturas/F4/09-drill4-EDGE-rutas-vuelta.png`
- `capturas/F4/09-drill4-EDGE-salud-final.png`

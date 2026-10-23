# Drill 2 — OSPF: se corta EDGE ↔ CORE-1

- Fecha y hora: de `23:57` a `00:05`, reloj de CORE-1. Sesión de laboratorio del 22/10/2026 a la madrugada del 23/10 (snapshot `pre-F4` a las 19:37 y snapshot `F4` a la 01:19, hora local). Las horas de este runbook son las del **reloj del router** que se indica: los routers no tienen NTP y su reloj se fue atrasando durante la sesión (al empezar iban ~3 h adelante de la hora local y al terminar ~40 min), así que no se convierten a hora local. Los tiempos medidos no dependen de esos relojes.
- Dirigió: Juan Bautista Cuenca, acompañado por Tomás Martin (operación de CORE-1 y CORE-2, rotación pedida por la cátedra) · Ejecutó en consola: Santiago Natalichio Bestosini (anfitrión de GNS3) · Midió: Lautaro Aubert
- Mecanismo que se prueba: OSPF área 0 con MD5 y el cable core–core (CORE-1 ↔ CORE-2), que es la corrección 3 del diagrama de la cátedra. Si se corta el cable EDGE ↔ CORE-1, CORE-1 tiene que encontrar solo el camino de respaldo por CORE-2.
- Temporizadores OSPF (`/routing ospf interface-template print detail` en CORE-1): `hello-interval=10s`, `dead-interval=40s`, los valores por defecto.

## Estado inicial (precondiciones)

Chequeo de salud en verde: CORE-1 con 4 vecinos Full y EDGE con 2.

Desde CORE-1, `/tool traceroute 10.255.255.1` llega al loopback del EDGE en **un solo salto**, porque el EDGE es vecino directo por `ether1` (`07-drill2-CORE-1-traceroute-antes.png`).

**Dónde se mide:** se usa el tráfico del propio CORE-1. Los DIST reparten su salida entre los dos CORE (ECMP), así que el tráfico de los hosts puede no pasar por el cable que se corta. El que sí depende de ese cable es CORE-1.

## Falla provocada

Se hicieron dos variantes.

**Variante A — corte que se ve.** En CORE-1, el corte y el ping van en la misma línea, así el ping arranca en el instante del corte (el ping de RouterOS ocupa la consola):

```routeros
/interface disable ether1; /ping 10.255.255.1 count=15
```

**Variante B — corte silencioso.** En la vida real un cable puede dejar de pasar tráfico sin que la placa pierda la señal, y entonces OSPF solo se entera cuando deja de recibir *hellos*. Para simularlo, con un ping continuo corriendo en CORE-1 (`/ping 10.255.255.1 count=70`), se puso en GNS3 un **filtro de pérdida de paquetes del 100 %** en el cable EDGE ↔ CORE-1 (clic derecho en el cable → *Packet filters*).

*Primer intento, descartado:* se probó primero con *Suspend* sobre el cable. No sirvió como corte silencioso: GNS3 le baja la señal a la placa, `ether1` quedó sin la marca `R` (running) y el vecino cayó en el momento, igual que en la variante A (`07-drill2-CORE-1-suspend-*.png`). Ese intento perdió 2 respuestas, como la variante A.

## Detección

**Variante A.**
- El ping de CORE-1 falla en las dos primeras respuestas: `seq 0` "22 (Invalid argument)" (la ruta todavía apunta a la interfaz que se acaba de apagar) y `seq 1` "no route to host" (ya no hay ruta) (`07-drill2-CORE-1-corte-interfaz.png`).
- Log de CORE-1: `23:57:59 ... neighbor { router-id: 10.255.255.1 state: Full } state change to Down` y la interfaz OSPF `destroyed` (`07-drill2-CORE-1-respuesta-log.png`).
- Netwatch en EDGE: loopback de CORE-1 `down` a las `23:57:58` y `up` a las `23:58:05`, hora del reloj del EDGE (`07-drill2-EDGE-netwatch.png`).

**Variante B.**
- El ping de CORE-1 responde hasta `seq 22` y da `timeout` desde `seq 23` (`07-drill2-CORE-1-silencioso-ping-1.png`). En `seq 54` cambia la respuesta: `10.0.0.2 ... host unreachable`. Es CORE-1 contestándose a sí mismo: en ese momento venció el *dead interval*, CORE-1 borró la ruta por el EDGE y todavía no tenía instalada la nueva (`07-drill2-CORE-1-silencioso-ping-2.png`).
- Mientras el filtro está puesto, OSPF no se entera: la interfaz sigue arriba y el vecino sigue en Full hasta que vence el *dead interval*.
- Log de CORE-1: `00:04:56 ... neighbor { router-id: 10.255.255.1 state: Full } timeout` y `state change to Down` (`07-drill2-CORE-1-silencioso-log.png`). La palabra **timeout** es la diferencia con la variante A: el vecino cayó porque dejaron de llegar *hellos*, no porque se apagó la interfaz.
- Netwatch en EDGE (`07-drill2-EDGE-netwatch-silencioso.png`, reloj del EDGE): a las `00:04:29` marca caídos los loopbacks de CORE-1, DIST-1 y DIST-2. DIST-1 y DIST-2 vuelven a las `00:04:36` y CORE-1 a las `00:04:56`.

## Respuesta

En las dos variantes, OSPF recalcula y CORE-1 llega al EDGE por el cable core–core:

- `/routing ospf neighbor print` en CORE-1: 3 vecinos en Full. Ya no aparece el EDGE (`10.255.255.1`) (`07-drill2-CORE-1-respuesta.png`, `07-drill2-CORE-1-silencioso-detalle.png`).
- `/tool traceroute 10.255.255.1` en CORE-1: ahora son dos saltos, `10.0.0.10` (CORE-2) y después `10.255.255.1` (`07-drill2-CORE-1-respuesta.png`).
- El ping vuelve con **TTL 63** en lugar de 64: la respuesta pasa por un router más. En la variante B vuelve en `seq 58`, 4 s después de vencer el *dead interval*.

## Recuperación

- **Variante A:** `/interface enable ether1` en CORE-1. En el log de CORE-1, la interfaz OSPF se crea a las `23:59:12` y el vecino llega a Full a las `23:59:21`: **9 s** (el log está en `07-drill2-CORE-1-suspend-log.png`, que muestra también el intento del *Suspend*; el vecino otra vez en Full, en `07-drill2-CORE-1-recuperacion.png`). En el medio aparece un aviso `dropping 4 from 10.0.0.1 - unknown neighbor`: el EDGE mandó paquetes OSPF antes de que CORE-1 lo tuviera registrado como vecino. Es normal mientras se arma la adyacencia.
- **Variante B:** se saca el filtro del cable en GNS3. Los vecinos vuelven a Full solos.

Chequeo de salud final: CORE-1 con 4 vecinos Full y EDGE con 2 (`07-drill2-salud-final-CORE-1.png`, `07-drill2-salud-final-EDGE.png`).

## Tiempo medido

| Variante | Qué se midió | Respuestas perdidas | Tiempo sin servicio |
|---|---|:-:|:-:|
| A — `disable` de la interfaz | Ping de CORE-1 al EDGE | 2 de 15 | ~2 s |
| A — vuelta | Adyacencia CORE-1 ↔ EDGE otra vez en Full | — | 9 s (log de CORE-1) |
| B — corte silencioso | Ping de CORE-1 al EDGE | 35 (`seq` 23 a 57) | **~35 s** (esperado: entre 30 y 40 s) |
| B — corte silencioso | Ping de PC-USER a `198.51.100.1` | 8 (`icmp_seq` 32 a 39) | ~16 s |

Cómo se midió: ping continuo; se cuentan los `timeout`. El ping de RouterOS manda una solicitud por segundo aunque no haya respuesta, así que cada `timeout` es 1 s. En VPCS cada `timeout` equivale a unos 2 s (espera 1 s la respuesta y deja 1 s antes de la siguiente). Lo calibramos con cronómetro en el drill 3.

**Por qué la variante B tarda tanto más.** En la variante A, el router ve que se apagó su interfaz y recalcula en el momento: el tiempo es el cálculo de rutas (SPF), unos 2 s. En la variante B no hay ninguna señal: el router solo sabe que el vecino no está cuando pasan 40 s (*dead interval*) sin recibir su *hello*. Como los *hellos* llegan cada 10 s, desde el corte hasta que vence el temporizador pasan entre 30 y 40 s. En la medición: 31 s desde el corte (`seq 23`) hasta que vence el temporizador (`seq 54`), y 4 s más hasta que funciona la ruta nueva (`seq 58`). Total: unos 35 s, contra unos 2 s de la variante A.

**El host perdió menos que CORE-1.** PC-USER perdió 8 respuestas (~16 s), no 35 s, porque su tráfico se reparte entre los dos CORE (ECMP) y solo una parte pasaba por el cable cortado. No medimos con precisión en qué momento del corte cayeron esas 8 respuestas. Los relojes de los routers no están sincronizados y la hora de VPCS no se registra.

## Post-mortem

**Por qué funcionó:** existe el cable core–core. Sin él, al cortarse EDGE ↔ CORE-1, CORE-1 se quedaba sin camino hacia el EDGE y hacia Internet, y todo el tráfico que los DIST le mandaran se perdía. Con el cable, OSPF encuentra el camino nuevo solo, sin que nadie toque nada.

**Qué aprendimos:**
- El tiempo de convergencia depende de **cómo** se entera el router. Si la interfaz se cae, son ~2 s. Si el cable deja de pasar tráfico sin bajar la señal, manda el *dead interval* (40 s por defecto).
- El *dead interval* también se ve en el monitoreo: netwatch marcó caídos al mismo tiempo CORE-1, DIST-1 y DIST-2, y los DIST volvieron 20 s antes que CORE-1. Cada punta del cable cuenta su propio *dead interval* desde el último *hello* que recibió, así que el EDGE y CORE-1 no reconvergen en el mismo instante: los DIST vuelven cuando reconverge el EDGE, y CORE-1 cuando reconverge él mismo. Además, netwatch revisa cada 10 s, así que sus horas tienen hasta 10 s de margen.
- El *Suspend* de GNS3 no sirve para simular un corte silencioso, porque baja la señal de la placa. Hace falta un filtro de pérdida de paquetes.

**Qué cambiaríamos:**
- Para converger más rápido sin depender del *dead interval* se podría bajar el *hello* y el *dead* (con más tráfico de control), o usar BFD, que detecta la caída en menos de un segundo. No se aplicó porque cambia el diseño.
- Sincronizar los relojes con NTP para poder seguir el mismo evento en los logs de varios routers.

## Evidencia

- `capturas/F4/07-drill2-CORE-1-traceroute-antes.png`
- `capturas/F4/07-drill2-CORE-1-corte-interfaz.png`
- `capturas/F4/07-drill2-CORE-1-respuesta.png`, `07-drill2-CORE-1-respuesta-log.png`
- `capturas/F4/07-drill2-CORE-1-recuperacion.png`
- `capturas/F4/07-drill2-EDGE-netwatch.png`
- `capturas/F4/07-drill2-CORE-1-suspend-ping.png`, `07-drill2-CORE-1-suspend-interfaz-y-log.png`, `07-drill2-CORE-1-suspend-log.png`, `07-drill2-CORE-1-vecinos-tras-suspend.png`, `07-drill2-EDGE-vecinos-tras-suspend.png` (primer intento, descartado)
- `capturas/F4/07-drill2-CORE-1-silencioso-ping-1.png`, `07-drill2-CORE-1-silencioso-ping-2.png`
- `capturas/F4/07-drill2-PC-USER-ping-silencioso.png`
- `capturas/F4/07-drill2-CORE-1-silencioso-detalle.png`, `07-drill2-CORE-1-silencioso-log.png`
- `capturas/F4/07-drill2-EDGE-netwatch-silencioso.png`
- `capturas/F4/07-drill2-salud-final-CORE-1.png`, `07-drill2-salud-final-EDGE.png`

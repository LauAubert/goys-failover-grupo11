# Topología lógica — diseño F0

Diagrama de la red de 5 capas con el direccionamiento definido en `docs/memoria.md` sección 1.2.
El proyecto GNS3 con el cableado real se captura en F1 (memoria sección 2).

## Resumen de bloques

| Bloque | Uso |
|--------|-----|
| `10.0.0.0/24` | 7 enlaces P2P internos (/30 cada uno) |
| `10.10.0.0/24` | LAN USERS — VRID 10, master DIST-1 |
| `10.20.0.0/24` | LAN SERVERS — VRID 20, master DIST-2 |
| `10.255.255.0/24` | Loopbacks internos / router-ids |
| `203.0.113.0/24` | Enlaces EDGE ↔ ISP (/30) |
| `198.51.100.0/24` | Loopbacks de ISP ("Internet") |

## Diagrama

```mermaid
graph TB
  subgraph INTERNET
    ISP1["ISP-1<br/>AS 65001<br/>lo 198.51.100.1"]
    ISP2["ISP-2<br/>AS 65002<br/>lo 198.51.100.2"]
  end
  subgraph EDGE
    E["EDGE<br/>AS 65000<br/>lo 10.255.255.1"]
  end
  subgraph CORE
    C1["CORE-1<br/>lo 10.255.255.2"]
    C2["CORE-2<br/>lo 10.255.255.3"]
  end
  subgraph DISTRIBUTION
    D1["DIST-1<br/>lo 10.255.255.4<br/>VRID10 master"]
    D2["DIST-2<br/>lo 10.255.255.5<br/>VRID20 master"]
  end
  subgraph ACCESS
    SU["SW-USERS<br/>10.10.0.0/24"]
    SS["SW-SERVERS<br/>10.20.0.0/24"]
    PC["PC-USER<br/>10.10.0.100"]
    SRV["SRV<br/>10.20.0.100"]
  end
  ISP1 -- "203.0.113.0/30 eBGP" --> E
  ISP2 -- "203.0.113.4/30 eBGP" --> E
  E -- "10.0.0.0/30" --> C1
  E -- "10.0.0.4/30" --> C2
  C1 -- "10.0.0.8/30 core-core" --> C2
  C1 -- "10.0.0.12/30" --> D1
  C2 -- "10.0.0.16/30" --> D1
  C1 -- "10.0.0.20/30" --> D2
  C2 -- "10.0.0.24/30" --> D2
  D1 --> SU
  D2 --> SU
  D1 --> SS
  D2 --> SS
  SU --> PC
  SS --> SRV
```

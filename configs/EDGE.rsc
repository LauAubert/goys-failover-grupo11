# 2026-10-22 23:38:02 by RouterOS 7.21.5
# system id = ZEighdbDNJC
#
/interface bridge
add comment="loopback = router-id" name=loopback
/interface ethernet
set [ find default-name=ether3 ] disable-running-check=no name=ether1
set [ find default-name=ether4 ] disable-running-check=no name=ether2
set [ find default-name=ether1 ] disable-running-check=no name=ether3
set [ find default-name=ether2 ] disable-running-check=no name=ether4
/interface list
add comment="enlaces hacia los ISP" name=WAN
/routing bgp instance
add as=65000 comment="EDGE, router-id = loopback" name=bgp-as65000 router-id=10.255.255.1
/routing ospf instance
add name=ospf-g11 originate-default=if-installed router-id=10.255.255.1
/routing ospf area
add instance=ospf-g11 name=backbone
/snmp community
set [ find default=yes ] disabled=yes
add addresses=10.255.255.0/24,10.20.0.0/24 name=<COMUNIDAD_SNMP>
/ip neighbor discovery-settings
set discover-interface-list=none
/interface list member
add interface=ether1 list=WAN
add interface=ether2 list=WAN
/ip address
add address=203.0.113.2/30 comment="hacia ISP-1" interface=ether1 network=203.0.113.0
add address=203.0.113.6/30 comment="hacia ISP-2" interface=ether2 network=203.0.113.4
add address=10.0.0.1/30 comment="hacia CORE-1" interface=ether3 network=10.0.0.0
add address=10.0.0.5/30 comment="hacia CORE-2" interface=ether4 network=10.0.0.4
add address=10.255.255.1 interface=loopback network=10.255.255.1
/ip firewall address-list
add address=10.255.255.0/24 comment=loopbacks list=gestion
add address=10.20.0.0/24 comment="LAN SERVERS" list=gestion
add address=10.10.0.0/24 comment="LAN USERS" list=lans
add address=10.20.0.0/24 comment="LAN SERVERS" list=lans
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
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes
/routing bgp connection
add as=65000 comment="eBGP con ISP-1" instance=bgp-as65000 local.role=ebgp name=hacia-ISP-1 output.filter-chain=lans-a-isp .redistribute=ospf remote.address=203.0.113.1 .as=65001
add as=65000 comment="eBGP con ISP-2" instance=bgp-as65000 local.role=ebgp name=hacia-ISP-2 output.filter-chain=lans-a-isp .redistribute=ospf remote.address=203.0.113.5 .as=65002
/routing filter rule
add chain=lans-a-isp comment="LAN USERS" rule="if (dst == 10.10.0.0/24) { accept }"
add chain=lans-a-isp comment="LAN SERVERS" rule="if (dst == 10.20.0.0/24) { accept }"
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 comment="enlaces P2P con MD5 hacia CORE" interfaces=ether3,ether4 type=ptp
add area=backbone comment="loopback = router-id" interfaces=loopback passive
/snmp
set contact="Grupo 11" enabled=yes location=EDGE
/system identity
set name=EDGE
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none
/tool netwatch
add comment=CORE-1 host=10.255.255.2 interval=10s type=simple
add comment=CORE-2 host=10.255.255.3 interval=10s type=simple
add comment=DIST-1 host=10.255.255.4 interval=10s type=simple
add comment=DIST-2 host=10.255.255.5 interval=10s type=simple
add comment=ISP-1 host=198.51.100.1 interval=10s type=simple
add comment=ISP-2 host=198.51.100.2 interval=10s type=simple

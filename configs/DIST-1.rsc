# 2026-10-10 20:32:48 by RouterOS 7.21.5
# system id = Om+hKlKu04D
#
/interface bridge
add comment="loopback = router-id" name=loopback
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
/ip neighbor discovery-settings
set discover-interface-list=none
/ip address
add address=10.0.0.14/30 comment="hacia CORE-1" interface=ether1 network=10.0.0.12
add address=10.0.0.18/30 comment="hacia CORE-2" interface=ether2 network=10.0.0.16
add address=10.10.0.2/24 comment="LAN USERS" interface=ether3 network=10.10.0.0
add address=10.20.0.2/24 comment="LAN SERVERS" interface=ether4 network=10.20.0.0
add address=10.255.255.4 interface=loopback network=10.255.255.4
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes
/system identity
set name=DIST-1
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none

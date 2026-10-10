# 2026-10-10 20:32:42 by RouterOS 7.21.5
# system id = fyeNtWEyEqP
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
add address=10.0.0.6/30 comment="hacia EDGE" interface=ether1 network=10.0.0.4
add address=10.0.0.10/30 comment="hacia CORE-1" interface=ether2 network=10.0.0.8
add address=10.0.0.17/30 comment="hacia DIST-1" interface=ether3 network=10.0.0.16
add address=10.0.0.25/30 comment="hacia DIST-2" interface=ether4 network=10.0.0.24
add address=10.255.255.3 interface=loopback network=10.255.255.3
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes
/system identity
set name=CORE-2
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none

# 2026-10-16 22:35:02 by RouterOS 7.21.5
# system id = 4GgrFFhNUrD
#
/interface bridge
add comment="loopback = router-id" name=loopback
/interface ethernet
set [ find default-name=ether2 ] disable-running-check=no name=ether1
set [ find default-name=ether1 ] disable-running-check=no name=ether2
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
/ip neighbor discovery-settings
set discover-interface-list=none
/ip address
add address=203.0.113.1/30 comment="hacia EDGE" interface=ether1 network=203.0.113.0
add address=198.51.100.1 interface=loopback network=198.51.100.1
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes
/system identity
set name=ISP-1
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none

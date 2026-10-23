# 2026-10-22 22:56:03 by RouterOS 7.21.5
# system id = 4GgrFFhNUrD
#
/interface bridge
add comment="destino de prueba de los drills (no se anuncia por BGP)" name=internet-test
add comment="loopback = router-id" name=loopback
/interface ethernet
set [ find default-name=ether4 ] disable-running-check=no name=ether1
set [ find default-name=ether1 ] disable-running-check=no name=ether2
set [ find default-name=ether2 ] disable-running-check=no name=ether3
set [ find default-name=ether3 ] disable-running-check=no name=ether4
/routing bgp instance
add as=65001 comment="ISP-1, router-id = loopback" name=bgp-as65001 router-id=198.51.100.1
/ip neighbor discovery-settings
set discover-interface-list=none
/ip address
add address=203.0.113.1/30 comment="hacia EDGE" interface=ether1 network=203.0.113.0
add address=198.51.100.1 interface=loopback network=198.51.100.1
add address=192.0.2.1 interface=internet-test network=192.0.2.1
/ip firewall address-list
add address=198.51.100.1 comment="loopback ISP-1, se anuncia por BGP" list=anuncio-bgp
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes
/routing bgp connection
add as=65001 comment="eBGP con EDGE, TCP-MD5" instance=bgp-as65001 local.role=ebgp name=hacia-EDGE output.default-originate=always .network=anuncio-bgp remote.address=203.0.113.2 .as=65000
/system identity
set name=ISP-1
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none

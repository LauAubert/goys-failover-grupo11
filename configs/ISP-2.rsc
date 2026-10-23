# 2026-10-22 22:56:05 by RouterOS 7.21.5
# system id = Pxll50OAQqP
#
/interface bridge
add comment="destino de prueba de los drills (no se anuncia por BGP)" name=internet-test
add comment="loopback = router-id" name=loopback
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
/routing bgp instance
add as=65002 comment="ISP-2, router-id = loopback" name=bgp-as65002 router-id=198.51.100.2
/ip neighbor discovery-settings
set discover-interface-list=none
/ip address
add address=203.0.113.5/30 comment="hacia EDGE" interface=ether1 network=203.0.113.4
add address=198.51.100.2 interface=loopback network=198.51.100.2
add address=192.0.2.1 interface=internet-test network=192.0.2.1
/ip firewall address-list
add address=198.51.100.2 comment="loopback ISP-2, se anuncia por BGP" list=anuncio-bgp
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes
/routing bgp connection
add as=65002 comment="eBGP con EDGE, TCP-MD5" instance=bgp-as65002 local.role=ebgp name=hacia-EDGE output.default-originate=always .network=anuncio-bgp remote.address=203.0.113.6 .as=65000
/system identity
set name=ISP-2
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none

# 2026-10-16 23:09:47 by RouterOS 7.21.5
# system id = Tsx7+jQWeyJ
#
/interface bridge
add comment="loopback = router-id" name=loopback
/interface ethernet
set [ find default-name=ether2 ] disable-running-check=no name=ether1
set [ find default-name=ether1 ] disable-running-check=no name=ether2
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
/interface vrrp
add authentication=simple comment="USERS: DIST-2 backup" interface=ether3 name=vrrp10 version=2 vrid=10
add authentication=simple comment="SERVERS: DIST-2 master" interface=ether4 name=vrrp20 priority=200 version=2 vrid=20
/routing ospf instance
add name=ospf-g11 router-id=10.255.255.5
/routing ospf area
add instance=ospf-g11 name=backbone
/ip neighbor discovery-settings
set discover-interface-list=none
/ip address
add address=10.0.0.22/30 comment="hacia CORE-1" interface=ether1 network=10.0.0.20
add address=10.0.0.26/30 comment="hacia CORE-2" interface=ether2 network=10.0.0.24
add address=10.10.0.3/24 comment="LAN USERS" interface=ether3 network=10.10.0.0
add address=10.20.0.3/24 comment="LAN SERVERS" interface=ether4 network=10.20.0.0
add address=10.255.255.5 interface=loopback network=10.255.255.5
add address=10.10.0.1 comment="gateway virtual USERS" interface=vrrp10 network=10.10.0.1
add address=10.20.0.1 comment="gateway virtual SERVERS" interface=vrrp20 network=10.20.0.1
/ip service
set ftp disabled=yes
set ssh address=10.255.255.0/24,10.20.0.0/24
set telnet disabled=yes
set www disabled=yes
set winbox address=10.255.255.0/24,10.20.0.0/24
set api disabled=yes
set api-ssl disabled=yes
/routing ospf interface-template
add area=backbone auth=md5 auth-id=1 comment="enlaces P2P con MD5 hacia CORE" interfaces=ether1,ether2 type=ptp
add area=backbone comment="loopback = router-id" interfaces=loopback passive
add area=backbone comment="LANs USERS y SERVERS, pasivas" interfaces=ether3,ether4 passive
/system identity
set name=DIST-2
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none

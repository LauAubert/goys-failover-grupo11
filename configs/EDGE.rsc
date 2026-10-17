# 2026-10-16 22:57:55 by RouterOS 7.21.5
# system id = ZEighdbDNJC
#
/interface bridge
add comment="loopback = router-id" name=loopback
/interface ethernet
set [ find default-name=ether2 ] disable-running-check=no name=ether1
set [ find default-name=ether1 ] disable-running-check=no name=ether2
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
/routing bgp instance
add as=65000 comment="EDGE, router-id = loopback" name=bgp-as65000 router-id=10.255.255.1
/routing ospf instance
add name=ospf-g11 originate-default=if-installed router-id=10.255.255.1
/routing ospf area
add instance=ospf-g11 name=backbone
/ip neighbor discovery-settings
set discover-interface-list=none
/ip address
add address=203.0.113.2/30 comment="hacia ISP-1" interface=ether1 network=203.0.113.0
add address=203.0.113.6/30 comment="hacia ISP-2" interface=ether2 network=203.0.113.4
add address=10.0.0.1/30 comment="hacia CORE-1" interface=ether3 network=10.0.0.0
add address=10.0.0.5/30 comment="hacia CORE-2" interface=ether4 network=10.0.0.4
add address=10.255.255.1 interface=loopback network=10.255.255.1
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
/system identity
set name=EDGE
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none

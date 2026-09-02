# RouterOS configuration for CRS326-24S+2Q+RM (mdf-agg01)
# Generated from switch configuration data — do not edit manually.
#
# Port map:
#   sfp-sfpplus1: lab-1 storage (VLAN 200)
#   sfp-sfpplus2: lab-1 lab (VLAN 210)
#   sfp-sfpplus3: lab-2 storage (VLAN 200)
#   sfp-sfpplus4: lab-2 lab (VLAN 210)
#   sfp-sfpplus5: lab-3 storage (VLAN 200)
#   sfp-sfpplus6: lab-3 lab (VLAN 210)
#   sfp-sfpplus7: lab-4 storage (VLAN 200)
#   sfp-sfpplus8: lab-4 lab (VLAN 210)
#   bond-css326: CSS326 trunk
#   bond-sigil: Sigil (VLAN 10)
#   sfp-sfpplus20: trunk to idf-dist01
#   sfp-sfpplus24: trunk to mdf-brk01
#

# ── System ──
/system identity set name="mdf-agg01"
# ── User accounts (lockout-safety: do this before everything else) ──
:do { /user add name=admin group=full password="" } on-error={ /user set [find name=admin] group=full password="" }
/ip service set [find name=ssh] disabled=no port=22

# ── SSH keys ──
/file add name=admin-key1.pub contents="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPK+1GlLeOjyDZjcdGFXjDnJfgtO7OOOoeTliAwZRSsf psyc@sigil"
/user ssh-keys import public-key-file=admin-key1.pub user=admin
:do { /file remove admin-key1.pub } on-error={}

/system clock set time-zone-name=America/Los_Angeles
/ip dns set servers=10.0.240.1
/ip ssh set host-key-type=ed25519
/snmp set enabled=yes

# ── Bonds ──
/interface bonding
add name=bond-css326 mode=802.3ad slaves=sfp-sfpplus9,sfp-sfpplus10 comment="CSS326 trunk"
add name=bond-sigil mode=802.3ad slaves=sfp-sfpplus11,sfp-sfpplus12 lacp-mode=passive comment="Sigil"

# ── Bridge ──
/interface bridge
add name=bridge1 protocol-mode=none igmp-snooping=yes multicast-querier=yes multicast-router=temporary-query igmp-version=3 mld-version=2

# ── Bridge ports ──
/interface bridge port
add bridge=bridge1 interface=sfp-sfpplus1 pvid=200 comment="lab-1 storage"
add bridge=bridge1 interface=sfp-sfpplus2 pvid=210 comment="lab-1 lab"
add bridge=bridge1 interface=sfp-sfpplus3 pvid=200 comment="lab-2 storage"
add bridge=bridge1 interface=sfp-sfpplus4 pvid=210 comment="lab-2 lab"
add bridge=bridge1 interface=sfp-sfpplus5 pvid=200 comment="lab-3 storage"
add bridge=bridge1 interface=sfp-sfpplus6 pvid=210 comment="lab-3 lab"
add bridge=bridge1 interface=sfp-sfpplus7 pvid=200 comment="lab-4 storage"
add bridge=bridge1 interface=sfp-sfpplus8 pvid=210 comment="lab-4 lab"
add bridge=bridge1 interface=bond-css326 pvid=1 comment="CSS326 trunk"
add bridge=bridge1 interface=bond-sigil pvid=10 comment="Sigil"
add bridge=bridge1 interface=sfp-sfpplus20 pvid=1 comment="trunk to idf-dist01"
add bridge=bridge1 interface=sfp-sfpplus24 pvid=1 comment="trunk to mdf-brk01"

# ── VLAN table ──
/interface bridge vlan
add bridge=bridge1 vlan-ids=10 tagged=bond-css326,sfp-sfpplus20,sfp-sfpplus24,bridge1 untagged=bond-sigil
add bridge=bridge1 vlan-ids=25 tagged=bond-css326,sfp-sfpplus20,sfp-sfpplus24
add bridge=bridge1 vlan-ids=200 tagged=bond-css326,sfp-sfpplus20,sfp-sfpplus24,bridge1 untagged=sfp-sfpplus1,sfp-sfpplus3,sfp-sfpplus5,sfp-sfpplus7
add bridge=bridge1 vlan-ids=210 tagged=bond-css326,sfp-sfpplus20,sfp-sfpplus24,bridge1 untagged=sfp-sfpplus2,sfp-sfpplus4,sfp-sfpplus6,sfp-sfpplus8
add bridge=bridge1 vlan-ids=220 tagged=bond-css326,sfp-sfpplus20,sfp-sfpplus24,bridge1
add bridge=bridge1 vlan-ids=221 tagged=bond-css326,sfp-sfpplus20,sfp-sfpplus24,bridge1
add bridge=bridge1 vlan-ids=222 tagged=bond-css326,sfp-sfpplus20,sfp-sfpplus24,bridge1
add bridge=bridge1 vlan-ids=223 tagged=bond-css326,sfp-sfpplus20,sfp-sfpplus24,bridge1
add bridge=bridge1 vlan-ids=240 tagged=bond-css326,sfp-sfpplus20,sfp-sfpplus24,bridge1
add bridge=bridge1 vlan-ids=250 tagged=sfp-sfpplus20,sfp-sfpplus24
add bridge=bridge1 vlan-ids=251 tagged=sfp-sfpplus20,sfp-sfpplus24
add bridge=bridge1 vlan-ids=252 tagged=sfp-sfpplus24,bridge1

# ── VLAN interfaces ──
/interface vlan
add interface=bridge1 name=vlan223 vlan-id=223 mtu=1500
add interface=bridge1 name=vlan220 vlan-id=220 mtu=1500
add interface=bridge1 name=vlan222 vlan-id=222 mtu=1500
add interface=bridge1 name=vlan221 vlan-id=221 mtu=1500
add interface=bridge1 name=vlan252 vlan-id=252 mtu=1500
add interface=bridge1 name=vlan210 vlan-id=210 mtu=1500
add interface=bridge1 name=vlan10 vlan-id=10 mtu=1500
add interface=bridge1 name=vlan240 vlan-id=240 mtu=1500
add interface=bridge1 name=vlan200 vlan-id=200 mtu=9000

# ── Bridge L3 hardware offloading ──
/interface bridge settings set l3-hw-offloading=yes

# ── L3HW chip settings ──
/interface ethernet switch l3hw-settings set ipv6-hw=yes

# ── IPv6 settings ──
/ipv6 settings set forward=yes

# ── IP addresses ──
/ip address
add address=10.0.223.1/24 interface=vlan223 network=10.0.223.0
add address=10.0.220.1/24 interface=vlan220 network=10.0.220.0
add address=10.0.222.1/24 interface=vlan222 network=10.0.222.0
add address=10.0.221.1/24 interface=vlan221 network=10.0.221.0
add address=10.0.252.2/30 interface=vlan252 network=10.0.252.0
add address=10.0.210.1/24 interface=vlan210 network=10.0.210.0
add address=10.0.10.2/24 interface=vlan10 network=10.0.10.0
add address=10.0.240.2/24 interface=vlan240 network=10.0.240.0
add address=10.0.200.1/24 interface=vlan200 network=10.0.200.0

# ── Routes ──
/ip route
add dst-address=0.0.0.0/0 gateway=10.0.10.1

# ── DHCP relay ──
/ip dhcp-relay
add name=relay-cluster-orch interface=vlan223 dhcp-server=10.0.10.1 local-address=10.0.223.1 disabled=no
add name=relay-cluster-prod interface=vlan220 dhcp-server=10.0.10.1 local-address=10.0.220.1 disabled=no
add name=relay-cluster-scratch interface=vlan222 dhcp-server=10.0.10.1 local-address=10.0.222.1 disabled=no
add name=relay-cluster-stage interface=vlan221 dhcp-server=10.0.10.1 local-address=10.0.221.1 disabled=no
add name=relay-lab interface=vlan210 dhcp-server=10.0.10.1 local-address=10.0.210.1 disabled=no
add name=relay-main interface=vlan10 dhcp-server=10.0.10.1 local-address=10.0.10.2 disabled=no
add name=relay-storage interface=vlan200 dhcp-server=10.0.10.1 local-address=10.0.200.1 disabled=no

# ── IPv6 addresses ──
/ipv6 address
add address=fd9a:e830:4b1e:df::1/64 interface=vlan223
add address=fd9a:e830:4b1e:dc::1/64 interface=vlan220
add address=fd9a:e830:4b1e:de::1/64 interface=vlan222
add address=fd9a:e830:4b1e:dd::1/64 interface=vlan221
add address=fd9a:e830:4b1e:fc::2/64 interface=vlan252
add address=fd9a:e830:4b1e:d2::1/64 interface=vlan210
add address=fd9a:e830:4b1e:a::2/64 interface=vlan10
add address=fd9a:e830:4b1e:f0::2/64 interface=vlan240
add address=fd9a:e830:4b1e:c8::1/64 interface=vlan200

# ── IPv6 ND ──
/ipv6 nd
add interface=vlan10 ra-lifetime=none

# ── Disable unused ports ──
/interface ethernet
set [find default-name=qsfpplus1-1] disabled=yes
set [find default-name=qsfpplus1-2] disabled=yes
set [find default-name=qsfpplus1-3] disabled=yes
set [find default-name=qsfpplus1-4] disabled=yes
set [find default-name=qsfpplus2-1] disabled=yes
set [find default-name=qsfpplus2-2] disabled=yes
set [find default-name=qsfpplus2-3] disabled=yes
set [find default-name=qsfpplus2-4] disabled=yes
set [find default-name=sfp-sfpplus13] disabled=yes
set [find default-name=sfp-sfpplus14] disabled=yes
set [find default-name=sfp-sfpplus15] disabled=yes
set [find default-name=sfp-sfpplus16] disabled=yes
set [find default-name=sfp-sfpplus17] disabled=yes
set [find default-name=sfp-sfpplus18] disabled=yes
set [find default-name=sfp-sfpplus19] disabled=yes
set [find default-name=sfp-sfpplus21] disabled=yes
set [find default-name=sfp-sfpplus22] disabled=yes
set [find default-name=sfp-sfpplus23] disabled=yes

# ── Enable VLAN filtering (must be LAST to avoid lockout) ──
/interface bridge set bridge1 vlan-filtering=yes

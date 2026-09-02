# Incremental diff for mdf-agg01
# Generated from spec → current-state delta.

/interface bridge vlan
set [find vlan-ids=10] tagged=bond-css326,bridge1,sfp-sfpplus20,sfp-sfpplus24
set [find vlan-ids=200] tagged=bond-css326,bridge1,sfp-sfpplus20,sfp-sfpplus24
set [find vlan-ids=210] tagged=bond-css326,bridge1,sfp-sfpplus20,sfp-sfpplus24
set [find vlan-ids=220] tagged=bond-css326,bridge1,sfp-sfpplus20,sfp-sfpplus24
set [find vlan-ids=221] tagged=bond-css326,bridge1,sfp-sfpplus20,sfp-sfpplus24
set [find vlan-ids=222] tagged=bond-css326,bridge1,sfp-sfpplus20,sfp-sfpplus24
set [find vlan-ids=223] tagged=bond-css326,bridge1,sfp-sfpplus20,sfp-sfpplus24
set [find vlan-ids=252] tagged=bridge1,sfp-sfpplus24

/interface ethernet switch
set [find name=switch1] l3-hw-offloading=yes

/interface ethernet switch l3hw-settings
set ipv6-hw=yes

/ip dhcp-relay
add name=relay-cluster-orch interface=vlan223 dhcp-server=10.0.10.1 local-address=10.0.223.1 disabled=no
add name=relay-cluster-prod interface=vlan220 dhcp-server=10.0.10.1 local-address=10.0.220.1 disabled=no
add name=relay-cluster-scratch interface=vlan222 dhcp-server=10.0.10.1 local-address=10.0.222.1 disabled=no
add name=relay-cluster-stage interface=vlan221 dhcp-server=10.0.10.1 local-address=10.0.221.1 disabled=no
add name=relay-lab interface=vlan210 dhcp-server=10.0.10.1 local-address=10.0.210.1 disabled=no
add name=relay-main interface=vlan10 dhcp-server=10.0.10.1 local-address=10.0.10.2 disabled=no
add name=relay-storage interface=vlan200 dhcp-server=10.0.10.1 local-address=10.0.200.1 disabled=no

/ipv6 settings
set forward=yes

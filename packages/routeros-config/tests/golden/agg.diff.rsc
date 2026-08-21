# Incremental diff for mdf-agg01
# Generated from spec → current-state delta.

/interface ethernet switch
set [find name=switch1] l3-hw-offloading=yes

/interface ethernet switch l3hw-settings
set ipv6-hw=yes

/ipv6 settings
set forward=yes

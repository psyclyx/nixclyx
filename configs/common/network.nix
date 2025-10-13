# WiP
# Eventual goal is to describe my entire network, and have all the interfaces on all the machines configured.
# This is easy for nixos hosts, but also, there are openwrt routers, mikrotik switches, etc.

# Generation of a network diagram would be neat too - probably a good milestone before colmena for all hosts works

# TODO: psyclyx.config.network is... okay, i guess..., it doesn't conflict with psyclyx.networking.
# maybe this'll be better once psyclyx.config is able to describe the correct psyclyx.* settings

{ lib }:
let
  inherit (lib) genAttrs range mergeAttrsList;

  panels = {
    front-panel = {

      # TODO: I don't think I like this. this can be handled outside of psyclyx.networking,
      interfaces._generate = [
        {
          base.portType = "patch";
          start = 1;
          count = 48;
        }
      ];
    };

    back-panel = {
      interfaces._generate = [
        {
          base.portType = "patch";
          start = 1;
          count = 24;
        }
      ];
    };
  };

  switches = {
    sw-lab-1 = {
      interfaces._generate = [
        {
          base.portType = "rj45";
          prefix = "Port";
          start = 1;
          count = 24;
        }
        {
          base.portType = "sfp+";
          prefix = "SFP";
          start = 1;
          count = 2;
          default = {
          };
        }
      ];
    };
  };

  routers = {
    rt-apt-1 = {
      interfaces = {
        _generate = [
          {
            base.portType = "rj45";
            prefix = "eth";
            start = 0;
            count = 2;
          }
          {
            base.portType = "dsa";
            prefix = "lan";
            start = 1;
            count = 5;
            dsaMaster = "eth0";
          }
        ];
      };
    };
  };

  servers = {

    lab-1 = {
      # TODO: these boxes have ilo on board, it should be represented in a diagram as a group with 2 hosts, ig?
      interfaces = {
        _generate = [
          {
            type = "rj45";
            prefix = "eno";
            start = 1;
            count = 4;
          }
        ];
        ens2 = {
          type = "rj45";
        };
      };
    };

    lab-2 = {
      interfaces = {
        _generate = [
          {
            type = "rj45";
            prefix = "eno";
            start = 1;
            count = 4;
          }
          {
            type = "rj45";
            prefix = "eno";
            start = 49;
            count = 2;
          }
        ];
        ens2 = {
          type = "rj45";
        };
      };
    };

  };

  devices = mergeAttrsList [
    panels
    switches
    routers
    servers
  ];

  links = [
    # TODO: somehow describe every link between devices

  ];
in
{
  inherit devices;
}

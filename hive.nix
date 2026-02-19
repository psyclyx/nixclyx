{nixclyx ? import ./.}: {
  meta = {
    nixpkgs = import ./nixpkgs.nix {};
  };

  sigil = {...}: {
    imports = [
      nixclyx.modules.nixos.options
      nixclyx.modules.nixos.config
    ];
    config = {
      psyclyx.nixos.host = "sigil";
      deployment = {
        tags = [
          "apartment"
          "workstation"
          "desktop"
          "fixed"
        ];
        allowLocalDeployment = true;
        targetHost = "sigil.psyclyx.net";
        targetUser = "root";
      };
    };
  };

  omen = {...}: {
    imports = [
      nixclyx.modules.nixos.options
      nixclyx.modules.nixos.config
    ];
    config = {
      psyclyx.nixos.host = "omen";
      deployment = {
        tags = [
          "workstation"
          "laptop"
        ];
        allowLocalDeployment = true;
      };
    };
  };

  iyr = {...}: {
    imports = [
      nixclyx.modules.nixos.options
      nixclyx.modules.nixos.config
    ];
    config = {
      psyclyx.nixos.host = "iyr";
      deployment = {
        tags = [
          "apartment"
          "router"
          "minipc"
          "fixed"
        ];
        targetHost = "iyr.psyclyx.net";
        targetUser = "root";
      };
    };
  };

  tleilax = {...}: {
    imports = [
      nixclyx.modules.nixos.options
      nixclyx.modules.nixos.config
    ];
    config = {
      psyclyx.nixos.host = "tleilax";
      deployment = {
        tags = [
          "server"
          "colo"
        ];
        targetHost = "tleilax.psyclyx.net";
        targetUser = "root";
      };
    };
  };

  lab-1 = {...}: {
    imports = [
      nixclyx.modules.nixos.options
      nixclyx.modules.nixos.config
    ];
    config = {
      psyclyx.nixos.host = "lab-1";
      deployment = {
        tags = [
          "server"
          "apartment"
          "lab"
          "fixed"
        ];
        targetHost = "lab-1.rack-vpn.home.psyclyx.net";
        targetUser = "root";
      };
    };
  };

  lab-2 = {...}: {
    imports = [
      nixclyx.modules.nixos.options
      nixclyx.modules.nixos.config
    ];
    config = {
      psyclyx.nixos.host = "lab-2";
      deployment = {
        tags = [
          "server"
          "apartment"
          "lab"
          "fixed"
        ];
        targetHost = "lab-2.rack-vpn.home.psyclyx.net";
        targetUser = "root";
      };
    };
  };

  lab-3 = {...}: {
    imports = [
      nixclyx.modules.nixos.options
      nixclyx.modules.nixos.config
    ];
    config = {
      psyclyx.nixos.host = "lab-3";
      deployment = {
        tags = [
          "server"
          "apartment"
          "lab"
          "fixed"
        ];
        targetHost = "lab-3.rack-vpn.home.psyclyx.net";
        targetUser = "root";
      };
    };
  };

  lab-4 = {...}: {
    imports = [
      nixclyx.modules.nixos.options
      nixclyx.modules.nixos.config
    ];
    config = {
      psyclyx.nixos.host = "lab-4";
      deployment = {
        tags = [
          "server"
          "apartment"
          "lab"
          "fixed"
        ];
        targetHost = "lab-4.rack-vpn.home.psyclyx.net";
        targetUser = "root";
      };
    };
  };
}

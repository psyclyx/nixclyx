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
        ];
        allowLocalDeployment = true;
        targetHost = "sigil.lan";
        targetPort = 22;
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
        ];
        targetHost = "iyr.main.home.psyclyx.net";
        targetPort = 22;
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
        targetHost = "tleilax.psyclyx.xyz";
        targetPort = 17891;
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
        ];
        targetHost = "lab-1.lan";
        targetPort = 22;
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
        ];
        targetHost = "lab-2.lan";
        targetPort = 22;
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
        ];
        targetHost = "lab-3.lan";
        targetPort = 22;
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
        ];
        targetHost = "lab-4.lan";
        targetPort = 22;
        targetUser = "root";
      };
    };
  };
}

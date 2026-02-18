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
        targetHost = "10.157.0.3";
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
        targetHost = "10.157.0.2";
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
        targetHost = "10.157.0.1";
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
        targetHost = "10.157.10.11";
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
        targetHost = "10.157.10.12";
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
        targetHost = "10.157.10.13";
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
        targetHost = "10.157.10.14";
        targetUser = "root";
      };
    };
  };
}

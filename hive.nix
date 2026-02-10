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
          "workstation"
          "desktop"
        ];
        allowLocalDeployment = true;
        targetHost = "sigil.home.psyclyx.net";
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

  vigil = {...}: {
    imports = [
      nixclyx.modules.nixos.options
      nixclyx.modules.nixos.config
    ];
    config = {
      psyclyx.nixos.host = "vigil";
      deployment = {
        tags = [
          "server"
          "lab"
        ];
        targetHost = "vigil.home.psyclyx.net";
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
        tags = ["server"];
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
          "lab"
        ];
        targetHost = "lab-1.home.psyclyx.net";
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
          "lab"
        ];
        targetHost = "lab-2.home.psyclyx.net";
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
          "lab"
        ];
        targetHost = "lab-3.home.psyclyx.net";
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
          "lab"
        ];
        targetHost = "lab-4.home.psyclyx.net";
        targetPort = 22;
        targetUser = "root";
      };
    };
  };
}

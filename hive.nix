let
  nixclyx = import ./.;
in {
  meta = {
    nixpkgs = import ./nixpkgs.nix {};
  };

  sigil = {...}: {
    imports = [
      (nixclyx.modules.nixos.options {inherit nixclyx;})
      (nixclyx.modules.nixos.config {inherit nixclyx;})
    ];
    config = {
      psyclyx.nixos.config.hosts.sigil.enable = true;
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
      (nixclyx.modules.nixos.options {inherit nixclyx;})
      (nixclyx.modules.nixos.config {inherit nixclyx;})
    ];
    config = {
      psyclyx.nixos.config.hosts.omen.enable = true;
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
      (nixclyx.modules.nixos.options {inherit nixclyx;})
      (nixclyx.modules.nixos.config {inherit nixclyx;})
    ];
    config = {
      psyclyx.nixos.config.hosts.vigil.enable = true;
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

  lab-1 = {...}: {
    imports = [
      (nixclyx.modules.nixos.options {inherit nixclyx;})
      (nixclyx.modules.nixos.config {inherit nixclyx;})
    ];
    config = {
      psyclyx.nixos.config.hosts.lab-1.enable = true;
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
      (nixclyx.modules.nixos.options {inherit nixclyx;})
      (nixclyx.modules.nixos.config {inherit nixclyx;})
    ];
    config = {
      psyclyx.nixos.config.hosts.lab-2.enable = true;
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
      (nixclyx.modules.nixos.options {inherit nixclyx;})
      (nixclyx.modules.nixos.config {inherit nixclyx;})
    ];
    config = {
      psyclyx.nixos.config.hosts.lab-3.enable = true;
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
      (nixclyx.modules.nixos.options {inherit nixclyx;})
      (nixclyx.modules.nixos.config {inherit nixclyx;})
    ];
    config = {
      psyclyx.nixos.config.hosts.lab-4.enable = true;
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

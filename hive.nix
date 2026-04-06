{nixclyx ? import ./.}: {
  meta = {
    nixpkgs = import ./nixpkgs.nix {};
  };

  sigil = {...}: {
    imports = [nixclyx.modules.nixos nixclyx.hosts.nixos.sigil];
    config.deployment = {
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

  omen = {...}: {
    imports = [nixclyx.modules.nixos nixclyx.hosts.nixos.omen];
    config.deployment = {
      tags = [
        "workstation"
        "laptop"
      ];
      allowLocalDeployment = true;
    };
  };

  glyph = {...}: {
    imports = [nixclyx.modules.nixos nixclyx.hosts.nixos.glyph];
    config.deployment = {
      tags = [
        "workstation"
        "laptop"
      ];
      allowLocalDeployment = true;
      targetHost = "10.1.0.240";
      targetUser = "root";
    };
  };

  iyr = {...}: {
    imports = [nixclyx.modules.nixos nixclyx.hosts.nixos.iyr];
    config.deployment = {
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

  tleilax = {...}: {
    imports = [nixclyx.modules.nixos nixclyx.hosts.nixos.tleilax];
    config.deployment = {
      tags = [
        "server"
        "colo"
        "fixed"
      ];
      targetHost = "tleilax.psyclyx.net";
      targetUser = "root";
    };
  };

  semuta = {...}: {
    imports = [nixclyx.modules.nixos nixclyx.hosts.nixos.semuta];
    config.deployment = {
      tags = [
        "server"
        "vps"
        "fixed"
      ];
      targetHost = "5.78.144.186";
      targetUser = "root";
    };
  };

  lab-1 = {...}: {
    imports = [nixclyx.modules.nixos nixclyx.hosts.nixos.lab-1];
    config.deployment = {
      tags = [
        "server"
        "apartment"
        "lab"
        "fixed"
      ];
      targetHost = "lab-1.infra.apt.psyclyx.net";
      targetUser = "root";
    };
  };

  lab-2 = {...}: {
    imports = [nixclyx.modules.nixos nixclyx.hosts.nixos.lab-2];
    config.deployment = {
      tags = [
        "server"
        "apartment"
        "lab"
        "fixed"
      ];
      targetHost = "lab-2.infra.apt.psyclyx.net";
      targetUser = "root";
    };
  };

  lab-3 = {...}: {
    imports = [nixclyx.modules.nixos nixclyx.hosts.nixos.lab-3];
    config.deployment = {
      tags = [
        "server"
        "apartment"
        "lab"
        "fixed"
      ];
      targetHost = "lab-3.infra.apt.psyclyx.net";
      targetUser = "root";
    };
  };

  lab-4 = {...}: {
    imports = [nixclyx.modules.nixos nixclyx.hosts.nixos.lab-4];
    config.deployment = {
      tags = [
        "server"
        "apartment"
        "lab"
        "fixed"
      ];
      targetHost = "lab-4.infra.apt.psyclyx.net";
      targetUser = "root";
    };
  };
}

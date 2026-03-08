{
  path = ["psyclyx" "nixos" "hosts" "glyph"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./filesystems.nix];
  config = {
    lib,
    pkgs,
    nixclyx,
    ...
  }: {
    networking.hostName = "glyph";

    psyclyx.nixos = {
      hardware.presets.apple-silicon.enable = true;

      network.wireless.enable = true;

      services = {
        fstrim.enable = true;
        kanata.enable = true;
        resolved.enable = true;
      };

      role = "workstation";
      system = {
        emulation.enable = true;
      };
    };

    stylix = {
      image = nixclyx.assets.wallpapers."4x-ppmm-city-night.jpg";
      polarity = "dark";
    };

    psyclyx.nixos.filesystems = {
      impermanence = {
        enable = true;
        device = "/dev/disk/by-partlabel/nvme0-root";
        subvolume = "subvolumes/root";
        retention = {
          keepLast = 3;
          hourly = 6;
          daily = 7;
          weekly = 4;
          monthly = 3;
        };
      };

      bcachefs-snapshots = {
        enable = true;
        targets = {
          home-psyc = {
            device = "/dev/disk/by-partlabel/nvme0-root";
            subvolume = "subvolumes/home_psyc";
            calendar = "*:0/10";
            retention = {
              keepLast = 3;
              hourly = 6;
              daily = 7;
              weekly = 4;
              monthly = 6;
            };
          };
          home-root = {
            device = "/dev/disk/by-partlabel/nvme0-root";
            subvolume = "subvolumes/home_root";
            calendar = "*:0/10";
            retention = {
              keepLast = 3;
              hourly = 6;
              daily = 7;
              weekly = 4;
              monthly = 6;
            };
          };
        };
      };
    };

    preservation = {
      enable = true;
      preserveAt."/persist" = {
        directories = [
          "/var/lib/nixos"
          "/var/lib/systemd"
        ];
        files = [
          {file = "/etc/machine-id"; inInitrd = true;}
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];
      };
    };
  };
}

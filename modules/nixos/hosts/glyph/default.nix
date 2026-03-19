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

      network = {
        wireless.enable = true;
        firewall = {
          zones.local.interfaces = ["wl*" "wg0"];
          input.local.policy = "accept";
        };
      };

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
      base16Scheme = nixclyx.assets.palettes."4x-ppmm-city-night.yaml";
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
          {directory = "/etc/secrets/wireguard"; mode = "0750"; group = "systemd-network";}
        ];
        files = [
          {file = "/etc/machine-id"; inInitrd = true;}
          {file = "/etc/ssh/ssh_host_ed25519_key"; inInitrd = true;}
          {file = "/etc/ssh/ssh_host_ed25519_key.pub"; inInitrd = true;}
        ];
      };
    };
  };
}

{ pkgs, ... }:
{
  system.stateVersion = "25.05";
  networking.hostName = "omen";
  time.timeZone = "America/Los_Angeles";
  imports = [
    ../../../modules/nixos/nixpkgs.nix
    ../../../modules/nixos/module.nix
    ../../../modules/nixos/system/home-manager.nix

    ./boot.nix
    ./filesystems.nix
    ./hardware.nix
    ./users.nix
  ];

  services.resolved.enable = true;
  networking = {
    wireless = {
      iwd = {
        enable = true;
        settings = {
          IPv6.Enabled = true;
          Settings.AutoConnect = true;
        };
      };
    };
  };

  services = {
    kanata = {
      enable = true;
      keyboards = {
        default = {
          extraDefCfg = ''
            process-unmapped-keys yes
            danger-enable-cmd yes
            sequence-timeout 2000
            sequence-input-mode visible-backspaced
            log-layer-changes no
          '';

          config = ''
            (defsrc)

            (deflayermap (base-layer)
               caps esc

               a (tap-hold 125 125 a S-a)
               s (tap-hold 125 125 s S-s)
               d (tap-hold 125 125 d S-d)
               f (tap-hold 125 125 f S-f)
               g (tap-hold 125 125 g S-g)
               h (tap-hold 125 125 h S-h)
               j (tap-hold 125 125 j S-j)
               k (tap-hold 125 125 k S-k)
               l (tap-hold 125 125 l S-l)
               ; (tap-hold 125 125 ; S-;)
               ' (tap-hold 125 125 ' S-')

               z (tap-hold 125 125 z S-z)
               x (tap-hold 125 125 x S-x)
               c (tap-hold 125 125 c S-c)
               v (tap-hold 125 125 v S-v)
               b (tap-hold 125 125 b S-b)
               n (tap-hold 125 125 n S-n)
               m (tap-hold 125 125 m S-m)
               , (tap-hold 125 125 , S-,)
               . (tap-hold 125 125 . S-.)
               / (tap-hold 125 125 / S-/)

               lctl (one-shot 2000 lctl)
               rctl (one-shot 2000 rctl)
               lalt (one-shot 2000 lalt)
               ralt (one-shot 2000 ralt)
               lmet (one-shot 2000 lmet)
               rmet (one-shot 2000 rmet))
          '';
        };
      };
    };
  };

  psyclyx = {
    programs = {
      sway = {
        enable = true;
      };
    };

    services = {
      autoMount = {
        enable = true;
      };
      gnome-keyring = {
        enable = true;
      };
      greetd = {
        enable = true;
      };
      openssh = {
        enable = true;
      };
      printing = {
        enable = true;
      };
      tailscale = {
        enable = true;
      };
    };

    system = {
      fonts = {
        enable = true;
      };
      sudo = {
        enable = true;
      };
    };
  };
}

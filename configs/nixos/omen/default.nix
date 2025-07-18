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
            (defvar
              tap-repress-timeout 100
              hold-timeout 150
              one-shot-timeout 2000
              tt $tap-repress-timeout
              ht $hold-timeout
              ost $one-shot-timeout)

            (defsrc)

            (deflayermap (base-layer)
               caps esc

               ` (tap-hold $tt $ht ` S-`)
               1 (tap-hold $tt $ht 1 S-1)
               2 (tap-hold $tt $ht 2 S-2)
               3 (tap-hold $tt $ht 3 S-3)
               4 (tap-hold $tt $ht 4 S-4)
               5 (tap-hold $tt $ht 5 S-5)
               6 (tap-hold $tt $ht 6 S-6)
               7 (tap-hold $tt $ht 7 S-7)
               8 (tap-hold $tt $ht 8 S-8)
               9 (tap-hold $tt $ht 9 S-9)
               0 (tap-hold $tt $ht 0 S-0)
               - (tap-hold $tt $ht - S--)
               = (tap-hold $tt $ht = S-=)

               q (tap-hold $tt $ht q S-q)
               w (tap-hold $tt $ht w S-w)
               e (tap-hold $tt $ht e S-e)
               r (tap-hold $tt $ht r S-r)
               t (tap-hold $tt $ht t S-t)
               y (tap-hold $tt $ht y S-y)
               u (tap-hold $tt $ht u S-u)
               i (tap-hold $tt $ht i S-i)
               o (tap-hold $tt $ht o S-o)
               p (tap-hold $tt $ht p S-p)
               lbrc (tap-hold $tt $ht lbrc S-lbrc)
               rbrc (tap-hold $tt $ht rbrc S-rbrc)
               \ (tap-hold $tt $ht \ S-\)

               a (tap-hold $tt $ht a S-a)
               s (tap-hold $tt $ht s S-s)
               d (tap-hold $tt $ht d S-d)
               f (tap-hold $tt $ht f S-f)
               g (tap-hold $tt $ht g S-g)
               h (tap-hold $tt $ht h S-h)
               j (tap-hold $tt $ht j S-j)
               k (tap-hold $tt $ht k S-k)
               l (tap-hold $tt $ht l S-l)
               ; (tap-hold $tt $ht ; S-;)
               ' (tap-hold $tt $ht ' S-')

               z (tap-hold $tt $ht z S-z)
               x (tap-hold $tt $ht x S-x)
               c (tap-hold $tt $ht c S-c)
               v (tap-hold $tt $ht v S-v)
               b (tap-hold $tt $ht b S-b)
               n (tap-hold $tt $ht n S-n)
               m (tap-hold $tt $ht m S-m)
               , (tap-hold $tt $ht , S-,)
               . (tap-hold $tt $ht . S-.)
               / (tap-hold $tt $ht / S-/)

               lsft (one-shot $ost lsft)
               rsft (one-shot $ost rsft)
               lctl (one-shot $ost lctl)
               rctl (one-shot $ost rctl)
               lalt (one-shot $ost lalt)
               ralt (one-shot $ost ralt)
               lmet (one-shot $ost lmet)
               rmet (one-shot $ost rmet))
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

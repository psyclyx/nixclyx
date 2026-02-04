{lib, ...}: {
  options = {
    psyclyx.keys = lib.mkOption {type = lib.types.attrs;};
  };
  config = {
    psyclyx.keys = {
      ca = {
        host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF1dwMWaH79XUtEOEudr8NfNVpwCTBMewH8+0ktSh4rk psyc@sigil";
        initrd-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPoL+z/ID9p7XsNI+/r4660ce4jYFzGUE6yK60Z0hOnd psyc@sigil";
        user = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIChLECzCJ0yaLGCpAfKMtg595+m2+5PoRtBPZGm3K0mw psyc@sigil";
      };
      psyc = {
        openssh = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwUKqMso49edYpzalH/BFfNlwmLDmcUaT00USWiMoFO me@psyclyx.xyz"
        ];
      };
    };
  };
}

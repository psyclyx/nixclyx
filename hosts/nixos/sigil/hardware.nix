{
  config,
  lib,
  ...
}: {
  psyclyx.nixos.hardware = {
      cpu = {
        amd.enable = true;
        enableMitigations = false;
      };

      gpu.nvidia.enable = true;

      monitors = {
        gawfolk = {
          connector = "DP-1";
          identifier = "QHX GF005";
          mode = {
            width = 3840;
            height = 2560;
          };
        };

        benq = {
          connector = "DP-6";
          identifier = "BNQ BenQ RD280U V5R0042101Q";
          mode = {
            width = 3840;
            height = 2560;
          };
          position.x = 3840;
        };

        dell = {
          connector = "DP-3";
          identifier = "Dell Inc. DELL S2721QS 9PPZM43";
          mode = {
            width = 3840;
            height = 2160;
          };
          position.x = 7680;
        };
      };
    };
}

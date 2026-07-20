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
          identifier = "QHX GF005";
          mode = {
            width = 3840;
            height = 2560;
          };
          # Calibrated SDR profile (ArgyllCMS). Loaded on session start via
          # set-output-icc. NOTE: measured on DP-2 in Feb; re-measure with the
          # i1 in the panel's SDR mode once loading is confirmed.
          colorProfile = ./gawfolk.icc;
        };

        benq = {
          identifier = "BNQ BenQ RD280U V5R0042101Q";
          mode = {
            width = 3840;
            height = 2560;
          };
          position.x = 3840;
        };

        dell = {
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

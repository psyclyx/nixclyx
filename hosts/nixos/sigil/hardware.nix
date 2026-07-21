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
          # ArgyllCMS shaper+matrix profile (dispread + colprof, native panel),
          # loaded on session start via set-output-icc. Re-measure with the i1
          # after any panel OSD change (mode/brightness invalidate it).
          colorProfile = ./gawfolk.icc;
        };

        benq = {
          identifier = "BNQ BenQ RD280U V5R0042101Q";
          mode = {
            width = 3840;
            height = 2560;
          };
          position.x = 3840;
          colorProfile = ./benq.icc;
        };

        dell = {
          identifier = "Dell Inc. DELL S2721QS 9PPZM43";
          mode = {
            width = 3840;
            height = 2160;
          };
          position.x = 7680;
          colorProfile = ./dell.icc;
        };
      };
    };
}

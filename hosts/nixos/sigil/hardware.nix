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
      gpu.unlock = {
        enable = true;
        targets = ["0000:0d:00.0"]; # the 3090
      };

      monitors = {
        gawfolk = {
          identifier = "QHX GF005";
          mode = {
            width = 3840;
            height = 2560;
          };
        };

        benq = {
          identifier = "BNQ BenQ RD280U V5R0042101Q";
          primary = true;
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

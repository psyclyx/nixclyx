{ ... }:
{
  config = {
    psyclyx.nixos.hardware = {
      cpu = {
        amd.enable = true;
        enableMitigations = false;
      };

      gpu.nvidia.enable = true;

      monitors = {
        benq = {
          connector = "DP-4";
          identifier = "BNQ BenQ RD280U V5R0042101Q";
          mode = {
            width = 3840;
            height = 2560;
          };
        };

        gawfolk = {
          connector = "DP-2";
          identifier = "QHX GF005 Unknown";
          mode = {
            width = 3840;
            height = 2560;
          };
          position.x = -3840;
        };

        dell = {
          connector = "DP-1";
          identifier = "Dell Inc. DELL S2721QS 9PPZM43";
          mode = {
            width = 3840;
            height = 2160;
          };
          position.x = 3840;
        };
      };

    };

  };

}

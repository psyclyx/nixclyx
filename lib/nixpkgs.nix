let
  mkLib = {overlay ? import ../overlay.nix}: {
    args = {
      config = {
        allowUnfree = true;
        nvidia.acceptLicense = true;
      };
      overlays = [overlay];
    };
    __functor = self: mkLib;
  };
in
  mkLib {}

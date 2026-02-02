{nixclyx, ...}: {
  default = final: prev: let
    inherit (prev.stdenv.hostPlatform) system;
  in {
    psyclyx =
      (nixclyx.packages."${system}")
      // {
        envs = nixclyx.envs."${system}";
      };
  };
}

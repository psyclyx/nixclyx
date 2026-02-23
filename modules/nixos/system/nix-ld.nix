{
  path = ["psyclyx" "nixos" "system" "nix-ld"];
  description = "support externally compiled, statically linked binaries via nix-ld";
  config = _: {
    programs.nix-ld.enable = true;
  };
}

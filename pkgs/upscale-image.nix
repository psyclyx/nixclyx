{ nodejs, writeShellApplication }:
writeShellApplication {
  name = "upscale-image";
  runtimeInputs = [ nodejs ];
  text = ''
    : "''${REPLICATE_TOKEN:=$(< ~/.tokens/replicate)}"
    node ${./upscale-image.js} "$@"
  '';
}

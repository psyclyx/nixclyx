{ nodejs, writeShellApplication }:
writeShellApplication {
  name = "upscale-image";
  runtimeInputs = [ nodejs ];
  text = ''
    : "''${REPLICATE_API_TOKEN:=$(< ~/.tokens/replicate)}"
    export REPLICATE_API_TOKEN
    node ${./upscale-image.js} "$@"
  '';
}

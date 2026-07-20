{ callPackage }:
# The set-output-icc derivation lives in the river repo (nix/set-output-icc.nix)
# alongside the client source and the protocol it speaks. Here we just wire it
# into the package set, supplying river's shared zig dependency lock.
let
  sources = import ../../npins;
in
callPackage (sources.river + "/nix/set-output-icc.nix") {
  deps = callPackage ../river/build.zig.zon.nix { };
}

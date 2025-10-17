{ lib, psyclyxLib, ... }:
let
  mkNixosSystem =
    specialArgs:
    let
      inherit (lib) nixosSystem;
    in
    {
      modules,
      system ? "x86_64-linux",
    }:
    nixosSystem {
      inherit modules specialArgs system;
    };

  mkNixosSystems =
    specialArgs:
    let
      inherit (lib) mapAttrs;
      nixosSystem = mkNixosSystem specialArgs;
    in
    set: mapAttrs (_: nixosSystem) set;

  mkNixosToplevels = lib.mapAttrs (_: config: config.config.system.build.toplevel);

  mkNixosImages = lib.mapAttrs (
    _: config:
    let
      build = config.config.system.build;
    in
    {
      iso = build.isoImage or null;
      sd = build.sdImage or null;
      vm = build.vm or null;
      vmWithBootLoader = build.vmWithBootLoader or null;
      amazon = build.amazonImage or null;
      azure = build.azureImage or null;
      digitalOcean = build.digitalOceanImage or null;
      google = build.googleComputeImage or null;
      oci = build.ociImage or null;
      proxmox = build.proxmoxImage or null;
      virtualBox = build.virtualBoxOVA or null;
    }
  );
in
{
  inherit
    mkNixosSystem
    mkNixosSystems
    mkNixosToplevels
    mkNixosImages
    ;
}

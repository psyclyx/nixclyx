{
  path = ["psyclyx" "nixos" "programs" "adb"];
  description = "Android Debug Bridge and Android Studio";
  config = {
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages =
      [pkgs.android-tools]
      ++ lib.optional pkgs.stdenv.hostPlatform.isx86_64
      (pkgs.android-studio.override {forceWayland = false;});
  };
}

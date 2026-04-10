{
  path = ["psyclyx" "nixos" "programs" "adb"];
  description = "Android Debug Bridge and Android Studio";
  config = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.android-tools
      (pkgs.android-studio.override { forceWayland = false; })
    ];
  };
}

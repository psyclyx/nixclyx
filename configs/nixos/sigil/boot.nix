{ inputs, pkgs, ... }:
{
  boot = {
    kernelParams = [
      "boot.shell_on_fail"
      "mitigations=off"
    ];
  };
}

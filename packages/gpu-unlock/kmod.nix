# The gpu_unlock kernel module; callPackage it from a kernelPackages set.
{
  callPackage,
  stdenv,
  kernel,
  kernelModuleMakeFlags,
}:
stdenv.mkDerivation {
  pname = "gpu-unlock";
  version = "2.0.0-${kernel.modDirVersion}";
  src = callPackage ./src.nix {};
  sourceRoot = "source/kernel/gpu_unlock";
  nativeBuildInputs = kernel.moduleBuildDependencies;
  makeFlags =
    kernelModuleMakeFlags
    ++ ["KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"];
  # Install through Kbuild, not by hand: modules_install is where nixpkgs'
  # kmodigest (cmd_sign in kernelModuleMakeFlags) signs the module and
  # writes the gpu_unlock.ko.cer that aggregateModules merges.
  installPhase = ''
    runHook preInstall
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build M="$PWD" \
      $makeFlags INSTALL_MOD_PATH=$out INSTALL_MOD_DIR=extra modules_install
    runHook postInstall
  '';
}

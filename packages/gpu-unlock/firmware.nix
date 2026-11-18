# Falcon/GSP blobs gpu_unlock loads via request_firmware(), cut out of the
# NVIDIA 610.43.03 driver. The pin is upstream's and independent of the
# driver actually in use — these only drive the pre-driver unlock. Hashes
# are upstream's PKGBUILD sha256sums.
{
  callPackage,
  fetchurl,
  runCommand,
  python3,
  zstd,
}: let
  src = callPackage ./src.nix {};
  nv = "610.43.03";
  nvSource = fetchurl {
    url = "https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/NVIDIA-kernel-module-source-${nv}.tar.xz";
    sha256 = "7e118923c7a23edc36114d63273a46e3e04e9af98695a42203e7ac2dfe9fc1dc";
  };
  nvInstaller = fetchurl {
    url = "https://download.nvidia.com/XFree86/Linux-x86_64/${nv}/NVIDIA-Linux-x86_64-${nv}-no-compat32.run";
    sha256 = "e084451db730a6df29d3d74f655749c4d236e3c945f7d94b5205e84318fe2f90";
  };
in
  runCommand "gpu-unlock-firmware-${nv}" {
    nativeBuildInputs = [python3 zstd];
  } ''
    mkdir nvsrc
    tar -xf ${nvSource} -C nvsrc
    python3 ${src}/firmware/extract_gsp.py ${nvInstaller} assets
    python3 ${src}/firmware/extract_boot_assets.py nvsrc/NVIDIA-kernel-module-source-${nv} assets
    install -Dm644 -t $out/lib/firmware/gpu-unlock/${nv} assets/*.bin
    install -Dm644 assets/NVIDIA-LICENSE $out/share/licenses/gpu-unlock-firmware/NVIDIA-LICENSE
  ''

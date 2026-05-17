# SCST — Generic SCSI Target Subsystem (out-of-tree kernel module + userspace).
#
# We chose SCST over LIO for its richer iSCSI feature set and stronger
# multi-initiator behavior. It's NOT in nixpkgs; this package skeleton
# documents the shape we'll fill in when we're ready to actually build
# against a kernel. For the planning round it evaluates cleanly but is
# marked broken so accidental builds fail loudly with the right hint.
#
# To unblock building:
#   1. Pin a specific SCST release in npins (sourceforge.net/projects/scst).
#   2. Replace `src = null` below with `src = sources.scst;`.
#   3. Fill in `nativeBuildInputs` and `makeFlags` per SCST's build docs
#      (typically: `KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build`).
#   4. Drop `meta.broken = true`.
#   5. Wire `boot.extraModulePackages = [ scstKernel ];` from the iSCSI
#      target module.
#
# The userspace `scstadmin` tool lives in the same source tree under
# scstadmin/; split that out into a sibling derivation once the kernel
# module builds.
{
  lib,
  stdenv,
  linuxPackages,
}:
let
  kernel = linuxPackages.kernel;
in
stdenv.mkDerivation {
  pname = "scst";
  version = "0.0.0-unpackaged";

  # Real builds will replace this with an npins fetcher pointing at a
  # tagged SCST release tarball.
  src = null;

  nativeBuildInputs = [
    kernel.moduleBuildDependencies
  ];

  makeFlags = [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  meta = {
    description = "SCST iSCSI/SCSI target subsystem (kernel module + userspace)";
    homepage = "http://scst.sourceforge.net/";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    # Flip off once src and makeFlags are real. Until then, building
    # this derivation should fail with this message rather than silently
    # producing a non-functional target.
    broken = true;
  };
}

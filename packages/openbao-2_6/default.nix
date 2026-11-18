# OpenBao 2.6.x, kept for the seal oracle on iyr.
#
# 2.7 removed the `file` storage backend and moved the `pkcs11` seal out
# to an external plugin — the seal oracle uses both. Until its storage
# is migrated (`bao operator migrate` file → raft/pebbledb, which 2.7
# can still read as a source) and the kms-pkcs11 plugin is wired up,
# it stays on this pin. Delete this package once that lands.
{
  lib,
  fetchFromGitHub,
  buildGoModule,
  installShellFiles,
  stdenvNoCC,
}:
buildGoModule (finalAttrs: {
  pname = "openbao";
  version = "2.6.2";

  src = fetchFromGitHub {
    owner = "openbao";
    repo = "openbao";
    tag = "v${finalAttrs.version}";
    hash = "sha256-iFOah7LkuiL4MGhi6ANpgCYDYQl33gF+F4agdKLEFTk=";
  };

  vendorHash = "sha256-gORWU9Yn+AX00mQD5uq9k7ksbkLVWv8W2N4IxEOsE88=";
  proxyVendor = true;
  subPackages = ["."];

  # No `ui` tag: the seal oracle runs with ui = false.
  tags = lib.optional stdenvNoCC.hostPlatform.isLinux "hsm";

  ldflags = [
    "-s"
    "-X github.com/openbao/openbao/version.GitCommit=${finalAttrs.src.rev}"
    "-X github.com/openbao/openbao/version.fullVersion=${finalAttrs.version}"
    "-X github.com/openbao/openbao/version.buildDate=1970-01-01T00:00:00Z"
  ];

  nativeBuildInputs = [installShellFiles];

  postInstall = ''
    mv $out/bin/openbao $out/bin/bao
    installShellCompletion --bash --name bao <(echo complete -C "$out/bin/bao" bao)
  '';

  meta = {
    homepage = "https://www.openbao.org/";
    description = "OpenBao 2.6 (pinned for the file-storage seal oracle)";
    license = lib.licenses.mpl20;
    mainProgram = "bao";
  };
})

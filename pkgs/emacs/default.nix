{
  pkgs,
  package ? pkgs.emacs-unstable-pgtk,
}:
let
  packages = (
    epkgs: with epkgs; [
      better-jumper
      cape
      consult
      corfu
      direnv
      envrc
      evil
      evil-collection
      evil-easymotion
      evil-nerd-commenter
      evil-snipe
      evil-surround
      evil-textobj-anyblock
      exato
      general
      magit
      marginalia
      nerd-icons
      nerd-icons-completion
      nerd-icons-corfu
      orderless
      projectile
      smartparens
      vertico
      ws-butler
      zenburn-theme
    ]
  );
  defaultInitFileName = "default.el";
  configFile = pkgs.writeText defaultInitFileName (builtins.readFile ./config.org);
  orgModeConfigFile = pkgs.runCommand defaultInitFileName { nativeBuildInputs = [ package ]; } ''
    cp ${configFile} config.org
    emacs -Q --batch ./config.org -f org-babel-tangle
    mv config.el $out
  '';
in
(pkgs.emacsPackagesFor package).emacsWithPackages (
  epkgs:
  epkgs.trivialBuild {
    pname = "default";
    src = orgModeConfigFile;
    version = "0.1.0";
    packageRequires = packages epkgs;
  }
)

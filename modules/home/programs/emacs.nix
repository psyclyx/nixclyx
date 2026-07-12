{
  path = ["psyclyx" "home" "programs" "emacs"];
  description = "Emacs editor";
  config = {lib, ...}: {
    psyclyx-emacs.enable = true;

    # nvf is the default editor (psyclyx/nvf.nix); keep emacs installed and
    # available via emacsclient without it claiming EDITOR/VISUAL too.
    services.emacs.defaultEditor = lib.mkForce false;
  };
}

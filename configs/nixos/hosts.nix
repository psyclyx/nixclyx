{
  sigil = {
    system = "x86_64-linux";
    modules = [ ./sigil ];
  };

  omen = {
    system = "x86_64-linux";
    modules = [ ./omen ];
  };

  tleilax = {
    system = "x86_64-linux";
    modules = [ ./tleilax ];
  };

  lab-installer = {
    system = "x86_64-linux";
    modules = [ ./lab/installer.nix ];
  };

  lab-4 = {
    system = "x86_64-linux";
    modules = [ ./lab/lab-4.nix ];
  };
}

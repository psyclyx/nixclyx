{
  harp = {
    system = "aarch64-linux";
    modules = [ ./harp ]
  };

  sigil.modules = [ ./sigil ];

  omen.modules = [ ./omen ];

  tleilax.modules = [ ./tleilax ];

  lab-installer.modules = [ ./lab/installer.nix ];

  lab-4.modules = [ ./lab/lab-4.nix ];
}

{
  ix.modules = [ ./ix ];

  omen.modules = [ ./omen ];

  sigil.modules = [ ./sigil ];

  tleilax.modules = [ ./tleilax ];

  lab-1.modules = [ ./lab/lab-1.nix ];

  lab-3.modules = [ ./lab/lab-3.nix ];

  lab-4.modules = [ { psyclyx.hosts.lab.enable = true; } ];
}

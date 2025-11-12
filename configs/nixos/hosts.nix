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

  lab-base = {
    system = "x86_64-linux";
    modules = [
      ./lab
      { psyclyx.host.suffix = "base"; }
    ];
  };

  lab-1 = {
    system = "x86_64-linux";
    modules = [
      ./lab
      { psyclyx.host.suffix = "1"; }
    ];
  };

  lab-2 = {
    system = "x86_64-linux";
    modules = [
      ./lab
      { psyclyx.host.suffix = "2"; }
    ];
  };

  lab-3 = {
    system = "x86_64-linux";
    modules = [
      ./lab
      { psyclyx.host.suffix = "3"; }
    ];
  };

  lab-4 = {
    system = "x86_64-linux";
    modules = [
      ./lab
      { psyclyx.host.suffix = "4"; }
    ];
  };
}

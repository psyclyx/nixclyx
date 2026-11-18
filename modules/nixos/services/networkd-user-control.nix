{
  path = ["psyclyx" "nixos" "services" "networkd-user-control"];
  description = "let a group take networkd links up and down, renew and reconfigure them, without a password";
  options = {lib, ...}: {
    group = lib.mkOption {
      type = lib.types.str;
      default = "wheel";
      description = ''
        Members of this group, in an active local session, may use networkd's
        link actions (polkit's org.freedesktop.network1.manage-links, .renew,
        .forcerenew and .reconfigure): what Whirlpool's network panel asks
        polkit about before it offers them.
      '';
    };
  };
  config = {cfg, ...}: {
    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      // networkd's link actions (networkctl up/down/renew/forcerenew/reconfigure,
      // and the io.systemd.Network.Link varlink methods), for ${cfg.group}
      // at the machine itself.
      polkit.addRule(function(action, subject) {
        var actions = [
          "org.freedesktop.network1.manage-links",
          "org.freedesktop.network1.renew",
          "org.freedesktop.network1.forcerenew",
          "org.freedesktop.network1.reconfigure"
        ];
        if (actions.indexOf(action.id) >= 0 && subject.local && subject.active
            && subject.isInGroup("${cfg.group}")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}

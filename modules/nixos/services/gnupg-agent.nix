{
  path = ["psyclyx" "nixos" "services" "gnupg-agent"];
  description = "gnupg agent (for pinentry)";
  config = _: {
    programs.gnupg.agent = {
      enable = true;
    };
  };
}

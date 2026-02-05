{
  path = ["psyclyx" "nixos" "system" "documentation"];
  description = "documentation generation";
  config = _: {
    documentation = {
      enable = true;
      dev.enable = true;
      doc.enable = true;
      info.enable = true;
      nixos = {
        enable = true;
      };
    };
  };
}

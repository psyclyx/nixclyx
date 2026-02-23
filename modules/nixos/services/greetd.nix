{
  path = ["psyclyx" "nixos" "services" "greetd"];
  description = "greetd+regreet";
  config = _: {
    programs.regreet = {
      enable = true;
      cageArgs = [
        "-m"
        "last"
        "-s"
      ];
    };
  };
}

{
  path = ["psyclyx" "home" "programs" "zoxide"];
  description = "zoxide (enhanced cd)";
  config = _: {
    programs.zoxide.enable = true;
  };
}

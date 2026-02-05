{
  path = ["psyclyx" "home" "programs" "fuzzel"];
  description = "Fuzzel application launcher";
  config = _: {programs.fuzzel.enable = true;};
}

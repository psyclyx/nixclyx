{
  path = ["psyclyx" "darwin" "programs" "raycast"];
  description = "Raycast launcher";
  config = _: {
    homebrew.casks = ["raycast"];
  };
}

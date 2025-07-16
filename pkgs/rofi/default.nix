{
  rofi-wayland-unwrapped,
  symlinkJoin,
  makeWrapper,
}:
symlinkJoin {
  name = "rofi";
  paths = [ rofi-wayland-unwrapped ];
  buildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/rofi \
      --add-flags "-config ${./theme.rasi}"
  '';
  meta = rofi-wayland-unwrapped.meta // {
    priority = (rofi-wayland-unwrapped.meta.priority or 5) - 1;
  };
}

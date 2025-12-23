let
  submodules = import ./psyclyx;
  psyclyx = {
    imports = builtins.attrValues submodules;
  };
in
submodules
// {
  inherit psyclyx;
  default = psyclyx;
}

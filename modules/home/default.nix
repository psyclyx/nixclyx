{ nixpkgs, ... }@deps:
{
  default = (nixpkgs.lib.modules.importApply ./psyclyx deps);
}

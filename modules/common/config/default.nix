args: {lib, ...}: {
  imports = [(lib.modules.importApply ./system args)];
}

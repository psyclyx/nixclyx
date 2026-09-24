{
  # The flake-compat source used to load flakes; default to nixclyx's own pin.
  flake-compat ? (import ./npins).flake-compat,
  ...
}:
src:
(import flake-compat {
  inherit src;
  copySourceTreeToStore = false;
}).outputs

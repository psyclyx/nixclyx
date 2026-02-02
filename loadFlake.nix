src:
(import (import ./npins).flake-compat {
  inherit src;
  copySourceTreeToStore = false;
}).outputs

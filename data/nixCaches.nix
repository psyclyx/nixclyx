# Binary caches every host trusts. `substituters` are used by default;
# `trusted-substituters` are opt-in (a user may pass them per build).
{
  substituters = [
    "https://nix-community.cachix.org?priority=1"
  ];

  trusted-substituters = [
    "https://psyclyx.cachix.org?priority=10"
  ];

  trusted-public-keys = [
    "psyclyx.cachix.org-1:UFwKXEDn3gLxIW9CeXGdFFUzCIjj8m6IdAQ7GA4XfCk="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
}

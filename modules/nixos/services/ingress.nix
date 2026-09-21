{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "ingress"
  ];
  description = "Reverse-proxy ingress backend overrides";
  options =
    { lib, ... }:
    {
      localBackendAddress = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = ''
          Per-service address override for a `local` service backend,
          keyed by service entity name.

          A `local` backend normally means localhost on the proxy host.
          Set this when the proxy reaches the backend at some other
          host-local address — a network-namespace veth, a socket path
          translated to an address. That address is an implementation
          detail of this box, so it lives in host config, not in the
          egregore service entity.
        '';
      };
    };
}

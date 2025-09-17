{
  networking = {
    useNetworkd = true;
    wireless = {
      iwd = {
        enable = true;
        settings = {
          Settings = {
            AutoConnect = true;
          };
        };
      };
    };
  };
}

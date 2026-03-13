{
  tleilax = {
    wireguard = {
      publicKey = "Hsytr+mjAfsBPoC99XHKLh9+jEbyz1REF0okmlviUVc=";
      endpoint = "vpn.psyclyx.xyz:51820";
    };
    addresses.vpn.ipv4 = "10.157.0.1";
    publicIPv4 = "199.255.18.171";
    publicIPv6 = "2606:7940:32:26::10";
    sshPort = 17891;
    roles = ["server" "vpn-hub"];
    services = {
      node = { port = 9100; networks = ["vpn"]; };
      smartctl = { port = 9633; networks = ["vpn"]; };
    };
  };

  iyr = {
    wireguard = {
      publicKey = "9wnevbvkDGcyNnMECEzgfaghqi4tEw4GsgC/TUcSTS4=";
      exportedRoutes = [
        "10.0.10.0/24"
        "10.157.10.0/24"
      ];
    };
    addresses.vpn.ipv4 = "10.157.0.2";
    sshPort = 17891;
    roles = ["server" "router"];
    hardware.tpm = true;
    services = {
      node = { port = 9100; networks = ["vpn"]; };
      smartctl = { port = 9633; networks = ["vpn"]; };
    };
  };

  sigil = {
    wireguard = {
      publicKey = "XKqqjC62uOUhbCn3JPpI0M6WFYqRf8sLpML90JZ1CmE=";
    };
    addresses.vpn.ipv4 = "10.157.0.3";
    roles = ["workstation"];
    services = {
      node = { port = 9100; networks = ["vpn"]; };
      smartctl = { port = 9633; networks = ["vpn"]; };
    };
  };

  phone = {
    wireguard = {
      publicKey = "SaYcJM6Fl1UhX1qzby9rjUJv+icRyh29jX+iIqFKdDw=";
    };
    addresses.vpn.ipv4 = "10.157.0.4";
    roles = ["mobile"];
  };

  omen = {
    wireguard = {
      publicKey = "yTRNWKLNu6Xb+h7DcPPiWohWe0O6QSwJBlh5AjzChmU=";
    };
    addresses.vpn.ipv4 = "10.157.0.5";
    roles = ["workstation"];
  };

  glyph = {
    wireguard = {
      publicKey = "7ufcd0IzKRR85YMIh0mfoxaG14uwW09c/h4AJaAC1xY=";
    };
    addresses.vpn.ipv4 = "10.157.0.6";
    roles = ["workstation"];
  };
}

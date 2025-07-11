{ ... }:
{
  services.soju = {
    enable = true;
    listen = [ "irc+insecure://0.0.0.0:6697" ];
    enableMessageLogging = true;
  };
}

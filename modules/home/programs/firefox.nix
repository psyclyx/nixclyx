{
  path = ["psyclyx" "home" "programs" "firefox"];
  description = "Firefox web browser";
  options = {lib, ...}: {
    kagiTokenPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to file containing Kagi session token, decrypted at runtime. When null, search defaults to DuckDuckGo.";
    };
  };
  config = {
    cfg,
    config,
    lib,
    pkgs,
    ...
  }: let
    hasKagi = cfg.kagiTokenPath != null;
    kagiPlaceholder = "__KAGI_SESSION_TOKEN__";
    profilePath = "${config.home.homeDirectory}/.mozilla/firefox/${config.programs.firefox.profiles.default.path}";

    patchSearch = pkgs.writers.writePython3 "patch-firefox-search" {
      libraries = [pkgs.python3Packages.lz4];
    } ''
      import lz4.block
      import os
      import sys
      import tempfile

      MAGIC = b"mozLz40\0"

      search_file, token_file, placeholder = sys.argv[1], sys.argv[2], sys.argv[3]

      with open(token_file) as f:
          token = f.read().strip()

      real_path = os.path.realpath(search_file)
      with open(real_path, "rb") as f:
          data = f.read()

      assert data[:8] == MAGIC, "not a valid mozlz4 file"
      content = lz4.block.decompress(data[8:])
      content = content.replace(placeholder.encode(), token.encode())

      out = MAGIC + lz4.block.compress(content)
      dir_name = os.path.dirname(search_file)
      fd, tmp = tempfile.mkstemp(dir=dir_name)
      try:
          os.write(fd, out)
          os.close(fd)
          if os.path.islink(search_file):
              os.unlink(search_file)
          os.rename(tmp, search_file)
      except BaseException:
          os.unlink(tmp)
          raise
    '';
  in {
    stylix.targets.firefox.profileNames = ["default"];

    programs.firefox = {
      enable = true;
      nativeMessagingHosts = [pkgs.tridactyl-native];

      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        OfferToSaveLogins = false;
        PasswordManagerEnabled = false;
        ExtensionSettings = {
          "uBlock0@raymondhill.net" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
            installation_mode = "force_installed";
          };
          "tridactyl.vim@cmcaine.co.uk" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/tridactyl-vim/latest.xpi";
            installation_mode = "force_installed";
          };
        };
      };

      profiles.default = {
        isDefault = true;

        search = {
          default =
            if hasKagi
            then "Kagi"
            else "ddg";
          force = true;
          engines =
            {
              google.metaData.hidden = true;
              bing.metaData.hidden = true;
            }
            // lib.optionalAttrs hasKagi {
              "Kagi" = {
                urls = [
                  {
                    template = "https://kagi.com/search?token=${kagiPlaceholder}&q={searchTerms}";
                  }
                ];
                definedAliases = ["@k"];
              };
            };
        };

        settings = {
          # Vertical tabs
          "sidebar.revamp" = true;
          "sidebar.verticalTabs" = true;

          # Telemetry
          "datareporting.policy.dataSubmissionEnabled" = false;
          "datareporting.healthreport.uploadEnabled" = false;
          "toolkit.telemetry.enabled" = false;
          "toolkit.telemetry.unified" = false;
          "toolkit.telemetry.archive.enabled" = false;
          "toolkit.telemetry.bhrPing.enabled" = false;
          "toolkit.telemetry.firstShutdownPing.enabled" = false;
          "toolkit.telemetry.shutdownPingSender.enabled" = false;
          "toolkit.telemetry.newProfilePing.enabled" = false;
          "toolkit.telemetry.updatePing.enabled" = false;
          "browser.newtabpage.activity-stream.feeds.telemetry" = false;
          "browser.newtabpage.activity-stream.telemetry" = false;
          "browser.ping-centre.telemetry" = false;

          # Disable password manager
          "signon.rememberSignons" = false;
          "signon.autofillForms" = false;

          # Disable other annoyances
          "extensions.pocket.enabled" = false;
          "app.shield.optoutstudies.enabled" = false;
          "browser.discovery.enabled" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.urlbar.suggest.quicksuggest.sponsored" = false;
          "browser.shell.checkDefaultBrowser" = false;

          # Disable form autofill
          "extensions.formautofill.addresses.enabled" = false;
          "extensions.formautofill.creditCards.enabled" = false;

          # HTTPS-only mode
          "dom.security.https_only_mode" = true;
        };
      };
    };

    home.activation.patchFirefoxKagiToken = lib.mkIf hasKagi (
      lib.hm.dag.entryAfter ["linkGeneration" "sops-nix"] ''
        searchFile="${profilePath}/search.json.mozlz4"
        if [ -f "${cfg.kagiTokenPath}" ] && [ -f "$searchFile" ]; then
          $VERBOSE_ECHO "Patching Firefox search config with Kagi token"
          $DRY_RUN_CMD ${patchSearch} "$searchFile" "${cfg.kagiTokenPath}" "${kagiPlaceholder}"
        fi
      ''
    );
  };
}

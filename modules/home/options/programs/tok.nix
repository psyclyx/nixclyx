{
  path = ["psyclyx" "home" "programs" "tok"];
  description = "Token injection for commands";
  options = {lib, ...}: {
    groups = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf (lib.types.submodule {
        options = {
          env = lib.mkOption {
            type = lib.types.str;
            description = "Environment variable name to set";
          };
          secret = lib.mkOption {
            type = lib.types.str;
            description = "Path to the sops secret file";
          };
        };
      }));
      default = {};
      description = "Token groups mapping group names to lists of env/secret pairs";
      example = {
        ai = [
          {env = "OPENROUTER_API_KEY"; secret = "/run/user/1000/secrets/openrouter";}
          {env = "ANTHROPIC_API_KEY"; secret = "/run/user/1000/secrets/anthropic";}
        ];
      };
    };
  };
  config = {cfg, lib, ...}: let
    groupNames = lib.attrNames cfg.groups;
    mkGroupExports = name: let
      tokens = cfg.groups.${name};
    in lib.concatMapStringsSep " "
      (t: ''${t.env}="$(cat '${t.secret}')"'')
      tokens;
    mkCase = name: ''
      ${name})
        exports+="${mkGroupExports name} "
        ;;'';
    tokFunction = ''
      tok() {
        if [[ $# -lt 2 ]]; then
          echo "Usage: tok <group>[,<group>...] <command> [args...]" >&2
          echo "Groups: ${lib.concatStringsSep ", " groupNames}" >&2
          return 1
        fi
        local groups="$1"
        shift
        local exports=""
        local IFS=','
        for group in $groups; do
          case "$group" in
      ${lib.concatStringsSep "\n" (map mkCase groupNames)}
            *)
              echo "Unknown token group: $group" >&2
              echo "Available groups: ${lib.concatStringsSep ", " groupNames}" >&2
              return 1
              ;;
          esac
        done
        eval "$exports \"\$@\""
      }
    '';
  in
    lib.mkIf (cfg.groups != {}) {
      programs.zsh.initContent = tokFunction;
    };
}

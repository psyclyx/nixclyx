_egregore() {
  local cur prev words cword
  _init_completion || return

  local cmds="list ls show attrs verbs verb run graph"

  if [[ $cword -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$cmds" -- "$cur"))
    return
  fi

  local cmd="${words[1]}"

  # Entity name completion for commands that take one
  case "$cmd" in
    show|attrs|verbs|verb|run)
      if [[ $cword -eq 2 ]]; then
        local entities
        entities=$(egregore list --no-color 2>/dev/null | awk '{print $1}')
        COMPREPLY=($(compgen -W "$entities" -- "$cur"))
        return
      fi
      ;;
  esac

  # Verb name completion
  case "$cmd" in
    verb|run)
      if [[ $cword -eq 3 ]]; then
        local entity="${words[2]}"
        local verbs
        verbs=$(egregore verbs "$entity" --no-color 2>/dev/null | awk '{print $1}')
        COMPREPLY=($(compgen -W "$verbs" -- "$cur"))
        return
      fi
      ;;
  esac

  # Flags for list
  case "$cmd" in
    list|ls)
      if [[ "$cur" == --type=* ]]; then
        local prefix="--type="
        local types
        types=$(egregore list --no-color 2>/dev/null | awk '{print $2}' | sort -u)
        COMPREPLY=($(compgen -P "$prefix" -W "$types" -- "${cur#$prefix}"))
        return
      fi
      if [[ "$cur" == --tag=* ]]; then
        local prefix="--tag="
        local tags
        tags=$(egregore list --no-color 2>/dev/null | awk '{gsub(/,/," ",$3); print $3}' | tr ' ' '\n' | sort -u)
        COMPREPLY=($(compgen -P "$prefix" -W "$tags" -- "${cur#$prefix}"))
        return
      fi
      COMPREPLY=($(compgen -W "--type= --tag=" -- "$cur"))
      return
      ;;
  esac
}

complete -F _egregore egregore

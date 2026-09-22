_egregore() {
  local cur prev words cword
  _init_completion || return

  local cmds="list ls show inspect attrs graph"

  if [[ $cword -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$cmds" -- "$cur"))
    return
  fi

  local cmd="${words[1]}"

  case "$cmd" in
    # Entity name completion for entity-first commands.
    show|attrs)
      if [[ $cword -eq 2 ]]; then
        local entities
        entities=$(egregore list --no-color 2>/dev/null | awk '{print $1}')
        COMPREPLY=($(compgen -W "$entities" -- "$cur"))
        return
      fi
      ;;

    # Flags for list.
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

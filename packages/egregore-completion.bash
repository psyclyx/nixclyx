_egregore() {
  local cur prev words cword
  _init_completion || return

  local cmds="list ls show inspect attrs verbs verb run graph"

  if [[ $cword -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$cmds" -- "$cur"))
    return
  fi

  local cmd="${words[1]}"

  case "$cmd" in
    # Entity name completion for entity-first commands
    show|attrs|verbs)
      if [[ $cword -eq 2 ]]; then
        local entities
        entities=$(egregore list --no-color 2>/dev/null | awk '{print $1}')
        COMPREPLY=($(compgen -W "$entities" -- "$cur"))
        return
      fi
      ;;

    # verb <verb> <entity> — verb name first, then entity
    verb|run)
      if [[ $cword -eq 2 ]]; then
        # Complete verb names (union across all entity types)
        local verbs
        verbs=$(egregore list --flat --no-color 2>/dev/null | awk '{print $1}' \
          | while read -r e; do
              egregore verbs "$e" --no-color 2>/dev/null | awk '{print $1}'
            done | sort -u)
        COMPREPLY=($(compgen -W "$verbs" -- "$cur"))
        return
      fi
      if [[ $cword -eq 3 ]]; then
        # Complete entity names that have the given verb
        local verb_name="${words[2]}"
        local entities
        entities=$(egregore list --flat --no-color 2>/dev/null | awk '{print $1}' \
          | while read -r e; do
              egregore verbs "$e" --no-color 2>/dev/null \
                | awk -v v="$verb_name" '$1 == v {print e; exit}' e="$e"
            done)
        COMPREPLY=($(compgen -W "$entities" -- "$cur"))
        return
      fi
      ;;

    # Flags for list
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

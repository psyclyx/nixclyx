#compdef egregore

_egregore_entities() {
  local -a entities
  entities=(${(f)"$(egregore list --no-color 2>/dev/null | awk '{print $1}')"})
  _describe 'entity' entities
}

_egregore_types() {
  local -a types
  types=(${(f)"$(egregore list --no-color 2>/dev/null | awk '{print $2}' | sort -u)"})
  _describe 'type' types
}

_egregore_tags() {
  local -a tags
  tags=(${(f)"$(egregore list --no-color 2>/dev/null | awk '{gsub(/,/,"\n",$3); print $3}' | sort -u)"})
  _describe 'tag' tags
}

_egregore() {
  local -a commands=(
    'list:List entities'
    'ls:List entities'
    'show:Entity overview'
    'inspect:Full fleet overview'
    'aspects:Query entity aspects'
    'graph:Output Graphviz DOT'
  )

  _arguments -C \
    '--color[Force color output]' \
    '--no-color[Disable color output]' \
    '1:command:->cmd' \
    '*::arg:->args'

  case "$state" in
    cmd)
      _describe 'command' commands
      ;;
    args)
      case "$words[1]" in
        list|ls)
          _arguments \
            '--type=[Filter by type]:type:_egregore_types' \
            '--tag=[Filter by tag]:tag:_egregore_tags'
          ;;
        show|aspects|attrs)
          _arguments '1:entity:_egregore_entities'
          ;;
      esac
      ;;
  esac
}

_egregore "$@"

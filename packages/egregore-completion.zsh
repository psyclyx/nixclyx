#compdef egregore

_egregore_entities() {
  local -a entities
  entities=(${(f)"$(egregore list --no-color 2>/dev/null | awk '{print $1}')"})
  _describe 'entity' entities
}

_egregore_verbs() {
  local entity="$words[3]"
  local -a verbs
  verbs=(${(f)"$(egregore verbs "$entity" --no-color 2>/dev/null | awk '{print $1}')"})
  _describe 'verb' verbs
}

_egregore_all_verbs() {
  # Collect all verbs across all entity types for position 2 (before entity is known).
  local -a verbs
  verbs=(${(f)"$(egregore list --flat --no-color 2>/dev/null | awk '{print $1}' | while read -r e; do egregore verbs "$e" --no-color 2>/dev/null | awk '{print $1}'; done | sort -u)"})
  _describe 'verb' verbs
}

_egregore_entities_for_verb() {
  # Complete entities that have the given verb.
  local verb="$words[2]"
  local -a entities
  entities=(${(f)"$(egregore list --flat --no-color 2>/dev/null | awk '{print $1}' | while read -r e; do egregore verbs "$e" --no-color 2>/dev/null | awk -v v="$verb" '$1 == v {print e; exit}' e="$e"; done)"})
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
    'attrs:Query entity attributes'
    'verbs:List entity verbs'
    'verb:Execute a verb'
    'run:Execute a verb'
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
        show|attrs|verbs)
          _arguments '1:entity:_egregore_entities'
          ;;
        verb|run)
          _arguments \
            '1:verb:_egregore_all_verbs' \
            '2:entity:_egregore_entities_for_verb' \
            '*:args:_files'
          ;;
      esac
      ;;
  esac
}

_egregore "$@"

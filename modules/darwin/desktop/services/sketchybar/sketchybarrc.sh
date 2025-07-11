#!/usr/bin/env bash
set -x

bar=(
  height=38
  position=top
  padding_left=16
  padding_right=16
  #y_offset="${Y_OFFSET}"
  color="${THEME_BACKGROUND}"
  sticky=off
  blur_radius=2
)

default=(
  icon.font="Berkeley Mono:ExtraLight:12.0"
  icon.color="${THEME_FOREGROUND}"
  icon.highlight_color="${THEME_BORDER_ACTIVE}"

  label.font="Berkeley Mono:Thin:18.0"
  label.color="${THEME_FOREGROUND}"
  label.highlight_color="${THEME_BORDER_ACTIVE}"

  #background.border_width=0

  background.padding_left=4
  background.padding_right=4
  label.padding_left=4
  label.padding_right=4
  icon.padding_left=4
  icon.padding_right=4
  padding_left=12
  padding_right=12
)

sketchybar \
  --bar "${bar[@]}" \
  --default "${default[@]}"


workspace=(
  label.color="${THEME_WM_UNFOCUSED_TEXT}"
  label.highlight_color="${THEME_WM_FOCUSED_TEXT}"
  label.background.color="${THEME_WM_FOCUSED_BACKGROUND}"
  label.background.drawing="off"
  padding_left=6
  padding_right=6
)

sketchybar --add event aerospace_workspace_change

WORKSPACES=
for _i in 1 2 3; do
  WORKSPACES=$(aerospace list-workspaces --all)
  [[ -n "${WORKSPACES}" ]] && break
  sleep 1;
done;


FOCUSED=$(aerospace list-workspaces --focused)

for sid in ${WORKSPACES}; do
  sketchybar --add item space."${sid}" left \
             --set space."${sid}" \
             "${workspace[@]}" \
             script="aerospace_plugin ${sid}" \
             label="${sid:1}" \
             update_freq=30 \
             --subscribe space."${sid}" aerospace_workspace_change

  FOCUSED_WORKSPACE="${FOCUSED}" NAME="space.${sid}" aerospace_plugin "${sid}" &
done

sketchybar \
  --add bracket spaces '/space\..*/' \
  --set spaces \
  padding_left=6 \
  padding_right=6


sketchybar \
  --add item app_name left \
  --set app_name \
  icon=APP \
  script="app_name_plugin" \
  --subscribe app_name front_app_switched

sketchybar \
  --add item mode left \
  --set mode \
  background.color="${THEME_TERMINAL_RED}" \
  label.color="${THEME_FOREGROUND}" \
  label.drawing=off \
  drawing=off


sketchybar \
  --add item battery right \
  --set battery \
  update_freq=15 \
  icon=BAT \
  script="battery_plugin"

sketchybar \
  --add item clock right \
  --set clock \
  update_freq=15 \
  script="clock_plugin 2>/tmp/sbar"

sketchybar \
  --add item clock_utc right \
  --set clock_utc \
  update_freq=15 \
  script="clock_plugin true"

sketchybar --update

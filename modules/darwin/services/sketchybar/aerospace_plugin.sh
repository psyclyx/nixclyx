#!/usr/bin/env bash

SID=$1
FOCUSED=''
if [ -n "${SID}" ] && [ "${SID}" = "${FOCUSED_WORKSPACE}" ]; then
  FOCUSED=1
  sketchybar --set "${NAME}" label.highlight=on
elif [ -n "${FOCUSED_WORKSPACE}" ]; then
  sketchybar --set "${NAME}" label.highlight=off
fi

if [ -n "${FOCUSED}" ] || [[ -n $(aerospace list-windows --workspace "${SID}") ]]; then
  sketchybar --set "${NAME}" drawing=on
else
  sketchybar --set "${NAME}" drawing=off
fi

#!/usr/bin/env bash

scratchpad_id=$(yabai -m query --windows | jq '.[] | select(.title=="Scratchpad").id')

if [[ "$scratchpad_id" -lt 1 ]]; then
  # scratchpad_id=$(iterm Scratchpad | awk '{print $NF}')
  osascript ~/.config/yabai/iterm_Scratchpad.scpt
  sleep 1
  yabai -m window --focus "$scratchpad_id"
  yabai -m window --toggle float
  yabai -m window --resize abs:2560:800
  yabai -m window --move abs:1280:640
else
  is_minimized=$(yabai -m query --windows --window "$scratchpad_id" | jq '.minimized')
  current_space=$(yabai -m query --spaces --space | jq '.index')

  if [[ "$is_minimized" -eq 1 ]]; then
    yabai -m window "$scratchpad_id" --space "$current_space"
    yabai -m window --focus "$scratchpad_id"
    yabai -m window --resize abs:2560:800
    yabai -m window --move abs:1280:640
  else
    yabai -m window "$scratchpad_id" --minimize
  fi
fi
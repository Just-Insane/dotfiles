#!/bin/bash

brew services stop yabai >>/dev/null 2>&1
brew services stop skhd >>/dev/null 2>&1

ubersicht=$(launchctl list | grep Uebersicht | cut -f3)

# This software is no longer used
# launchctl stop $ubersicht

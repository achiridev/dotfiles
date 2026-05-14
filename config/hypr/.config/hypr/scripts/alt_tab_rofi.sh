#!/usr/bin/env bash

exec rofi -modi "window,drun,run,ssh" -show window \
  -no-lazy-grab \
  -no-custom \
  -kb-element-next "" \
  -kb-element-prev "" \
  -kb-row-tab "" \
  -kb-row-down "Tab,Alt+Tab" \
  -kb-row-up "Shift+Tab,Alt+Shift+Tab" \
  -kb-accept-entry "!Alt_L,!Alt_R,Return" \
  -kb-cancel "Escape" \
  -columns 1 \
  -lines 12

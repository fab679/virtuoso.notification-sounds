#!/usr/bin/env bash
# Install Omarchy Notification Sounds in one go:
#   plugin files -> ~/.config/omarchy/plugins/virtuoso.notification-sounds/
#   shell.json   -> enable plugin + add the bar widget (far right)
#   launcher menu-> add Trigger -> Toggle -> Notification Sounds
#   CLI          -> ~/.local/bin/omarchy-sound (+ omarchy-sound-watch)
#   hooks        -> login, theme, font and update chimes
#   keybindings  -> volume keys and screenshot, appended to hypr/bindings.lua
#   USB alerts   -> ~/.local/bin/omarchy-device-alert + systemd user unit
#   services     -> omarchy-sound-watch (AC/battery/network/bluetooth) and
#                   omarchy-sound-session (logout chime)
# Idempotent: safe to re-run, skips anything already configured.
# Usage: ./install.sh [--no-usb] [--no-system]
set -euo pipefail

PLUGIN_ID="virtuoso.notification-sounds"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
MENU_JSONC="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
MENU_BLOCK="$SELF_DIR/assets/menu-entry.jsonc"
ALERT_BIN="$HOME/.local/bin/omarchy-device-alert"
ALERT_UNIT="$HOME/.config/systemd/user/omarchy-device-alert.service"

USB=1
SYSTEM=1
for arg in "$@"; do
  case "$arg" in
    --no-usb) USB=0 ;;
    --no-system) SYSTEM=0 ;;
    -h|--help)
      echo "Usage: install.sh [--no-usb] [--no-system]"
      echo "  --no-usb     skip the USB hotplug alert service"
      echo "  --no-system  notifications only: no CLI, hooks, keybindings or watchers"
      exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '==> %s\n' "$*"; }

say "1/7 copy plugin files (bundled Ocean sounds included)"
# Stage everything in a temp dir and swap it in with one rename, so the shell's
# file watcher sees a single change instead of ~80 (copying file-by-file into a
# live plugin dir triggered a reload storm that crashed Quickshell's IpcHandler
# reload path).
STAGE="$PLUGIN_DIR.new"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp "$SELF_DIR/manifest.json" "$SELF_DIR/Service.qml" "$SELF_DIR/BarWidget.qml" "$STAGE/"
cp -r "$SELF_DIR/sounds" "$STAGE/"
cp "$SELF_DIR/install.sh" "$SELF_DIR/uninstall.sh" "$SELF_DIR/sound-events.conf" "$STAGE/"
# Everything install.sh needs travels with the plugin, so re-running it from
# ~/.config/omarchy/plugins/... -- the path the README and `omarchy plugin add`
# both point at -- works without the git checkout still being around.
for dir in bin hooks systemd hypr tools; do
  [ -d "$SELF_DIR/$dir" ] && cp -r "$SELF_DIR/$dir" "$STAGE/"
done
chmod +x "$STAGE/install.sh" "$STAGE/uninstall.sh" "$STAGE/bin/"* 2>/dev/null || true
if [ -d "$PLUGIN_DIR" ]; then mv "$PLUGIN_DIR" "$PLUGIN_DIR.old"; fi
mv "$STAGE" "$PLUGIN_DIR"
rm -rf "$PLUGIN_DIR.old"

say "2/7 enable plugin and bar widget in shell.json"
if [ ! -f "$SHELL_JSON" ]; then
  printf '{\n  "plugins": [\n    { "id": "%s" }\n  ],\n  "bar": {\n    "layout": {\n      "right": [\n        { "id": "%s" }\n      ]\n    }\n  },\n  "version": 1\n}\n' "$PLUGIN_ID" "$PLUGIN_ID" > "$SHELL_JSON"
else
  jq --arg id "$PLUGIN_ID" '
    (.plugins //= [])
    | if (.plugins | index({id: $id})) then . else .plugins += [{id: $id}] end
    | (.bar.layout.right //= [])
    | if (.bar.layout.right | index({id: $id})) then . else .bar.layout.right += [{id: $id}] end
  ' "$SHELL_JSON" > "$SHELL_JSON.tmp"
  mv "$SHELL_JSON.tmp" "$SHELL_JSON"
fi

say "3/7 add launcher menu toggle"
mkdir -p "$(dirname "$MENU_JSONC")"
if [ ! -f "$MENU_JSONC" ]; then
  { printf '{\n'; cat "$MENU_BLOCK"; printf '}\n'; } > "$MENU_JSONC"
elif ! grep -q '"trigger.toggle.notification-sounds"' "$MENU_JSONC"; then
  python3 - "$MENU_JSONC" "$MENU_BLOCK" <<'PY'
import sys
path, block_path = sys.argv[1], sys.argv[2]
s = open(path).read()
block = open(block_path).read()
i = s.rstrip().rfind('}')
if i < 0:
    sys.exit('no closing brace found in ' + path)
head, tail = s[:i], s[i:]
sep = ',\n' if head.rstrip() and not head.rstrip().endswith('{') else '\n'
open(path, 'w').write(head.rstrip() + sep + block + tail)
PY
fi

say "4/7 install USB hotplug alerts"
if [ "$USB" = 1 ]; then
  mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
  install -m755 "$SELF_DIR/bin/omarchy-device-alert" "$ALERT_BIN"
  install -m644 "$SELF_DIR/systemd/omarchy-device-alert.service" "$ALERT_UNIT"
  systemctl --user daemon-reload
  systemctl --user enable --now omarchy-device-alert.service >/dev/null
  echo "     systemd user unit: omarchy-device-alert.service (enabled)"
else
  echo "     skipped (--no-usb)"
fi

say "5/7 install the omarchy-sound CLI, hooks and event watchers"
if [ "$SYSTEM" = 1 ]; then
  mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
  install -m755 "$SELF_DIR/bin/omarchy-sound" "$HOME/.local/bin/omarchy-sound"
  install -m755 "$SELF_DIR/bin/omarchy-sound-watch" "$HOME/.local/bin/omarchy-sound-watch"
  # Never clobber a config the user has already tuned.
  [ -f "$HOME/.config/omarchy/sound-events.conf" ] ||
    install -m644 "$SELF_DIR/sound-events.conf" "$HOME/.config/omarchy/sound-events.conf"

  omarchy hook install post-boot   "$SELF_DIR/hooks/post-boot/sound-desktop-login.hook"    >/dev/null
  omarchy hook install theme-set   "$SELF_DIR/hooks/theme-set/sound-theme-changed.hook"    >/dev/null
  omarchy hook install font-set    "$SELF_DIR/hooks/font-set/sound-font-changed.hook"      >/dev/null
  omarchy hook install post-update "$SELF_DIR/hooks/post-update/sound-update-finished.hook" >/dev/null

  install -m644 "$SELF_DIR/systemd/omarchy-sound-watch.service"   "$HOME/.config/systemd/user/omarchy-sound-watch.service"
  install -m644 "$SELF_DIR/systemd/omarchy-sound-session.service" "$HOME/.config/systemd/user/omarchy-sound-session.service"
  systemctl --user daemon-reload
  systemctl --user enable --now omarchy-sound-watch.service omarchy-sound-session.service >/dev/null 2>&1
  echo "     CLI: omarchy-sound | services: sound-watch, sound-session"
else
  echo "     skipped (--no-system)"
fi

say "6/7 add volume and screenshot keybindings"
BINDINGS="$HOME/.config/hypr/bindings.lua"
if [ "$SYSTEM" = 1 ] && ! grep -q "virtuoso.notification-sounds" "$BINDINGS" 2>/dev/null; then
  cp "$BINDINGS" "$BINDINGS.bak.$(date +%s)" 2>/dev/null || true
  cat "$SELF_DIR/hypr/sound-bindings.lua" >> "$BINDINGS"
  hyprctl reload >/dev/null 2>&1 || true
  if [ -n "$(hyprctl configerrors 2>/dev/null)" ]; then
    echo "     WARNING: hyprctl reports config errors, check: hyprctl configerrors" >&2
  else
    echo "     volume keys and PRINT now chime (backup alongside bindings.lua)"
  fi
else
  echo "     skipped (already present, or --no-system)"
fi

say "7/7 validate and restart the shell"
if omarchy plugin validate "$PLUGIN_DIR" >/dev/null; then
  echo "     plugin validate: OK"
fi
# Let the file watcher's hot-reload finish before the restart IPC arrives.
# Reloading plugins while a restart is in flight can crash Quickshell's
# IpcHandler re-registration (a Quickshell bug), so pause to let it settle.
sleep 4
omarchy restart shell

echo
echo "Done. Ocean sounds are live across the desktop."
echo "  hear them:  omarchy-sound test          (plays all 45 in order)"
echo "  check:      omarchy-sound status"
echo "  coverage:   python3 $SELF_DIR/tools/audit-coverage.py"
echo "  toggle:     the speaker glyph in the bar, or Trigger -> Notification Sounds in the menu"
echo "  tune:       ~/.config/omarchy/sound-events.conf"
echo "  remove:     ./uninstall.sh && omarchy plugin remove $PLUGIN_ID"
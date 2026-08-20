#!/usr/bin/env bash
# Install Omarchy Notification Sounds in one go:
#   plugin files -> ~/.config/omarchy/plugins/virtuoso.notification-sounds/
#   shell.json   -> enable plugin + add the bar widget (far right)
#   launcher menu-> add Trigger -> Toggle -> Notification Sounds
#   USB alerts   -> ~/.local/bin/omarchy-device-alert + systemd user unit
# Idempotent: safe to re-run, skips anything already configured.
# Usage: ./install.sh [--no-usb]
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
for arg in "$@"; do
  case "$arg" in
    --no-usb) USB=0 ;;
    -h|--help) echo "Usage: install.sh [--no-usb]"; echo "  --no-usb  skip the USB hotplug alert service"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '==> %s\n' "$*"; }

say "1/5 copy plugin files (bundled Ocean sounds included)"
# Stage everything in a temp dir and swap it in with one rename, so the shell's
# file watcher sees a single change instead of ~80 (copying file-by-file into a
# live plugin dir triggered a reload storm that crashed Quickshell's IpcHandler
# reload path).
STAGE="$PLUGIN_DIR.new"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp "$SELF_DIR/manifest.json" "$SELF_DIR/Service.qml" "$SELF_DIR/BarWidget.qml" "$STAGE/"
cp -r "$SELF_DIR/sounds" "$STAGE/"
cp "$SELF_DIR/install.sh" "$SELF_DIR/uninstall.sh" "$STAGE/"
chmod +x "$STAGE/install.sh" "$STAGE/uninstall.sh"
if [ -d "$PLUGIN_DIR" ]; then mv "$PLUGIN_DIR" "$PLUGIN_DIR.old"; fi
mv "$STAGE" "$PLUGIN_DIR"
rm -rf "$PLUGIN_DIR.old"

say "2/5 enable plugin and bar widget in shell.json"
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

say "3/5 add launcher menu toggle"
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

say "4/5 install USB hotplug alerts"
if [ "$USB" = 1 ]; then
  mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
  cp "$SELF_DIR/omarchy-device-alert" "$ALERT_BIN"
  chmod +x "$ALERT_BIN"
  cp "$SELF_DIR/omarchy-device-alert.service" "$ALERT_UNIT"
  systemctl --user daemon-reload
  systemctl --user enable --now omarchy-device-alert.service >/dev/null
  echo "     systemd user unit: omarchy-device-alert.service (enabled)"
else
  echo "     skipped (--no-usb)"
fi

say "5/5 validate and restart the shell"
if omarchy plugin validate "$PLUGIN_DIR" >/dev/null; then
  echo "     plugin validate: OK"
fi
# Let the file watcher's hot-reload finish before the restart IPC arrives.
# Reloading plugins while a restart is in flight can crash Quickshell's
# IpcHandler re-registration (a Quickshell bug), so pause to let it settle.
sleep 4
omarchy restart shell

echo
echo "Done. Notification sounds are live."
echo "  toggle:  the speaker glyph in the bar, or Trigger -> Notification Sounds in the menu"
echo "  remove:  omarchy plugin remove $PLUGIN_ID   (after running uninstall.sh)"
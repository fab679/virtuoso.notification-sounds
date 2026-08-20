#!/usr/bin/env bash
# Remove Omarchy Notification Sounds and everything it set up:
#   plugin folder, shell.json entries, launcher menu toggle, USB alert service.
# Safe to re-run.
set -euo pipefail

PLUGIN_ID="virtuoso.notification-sounds"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
MENU_JSONC="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
ALERT_BIN="$HOME/.local/bin/omarchy-device-alert"
ALERT_UNIT="$HOME/.config/systemd/user/omarchy-device-alert.service"

say() { printf '==> %s\n' "$*"; }

say "1/4 remove USB alert service"
systemctl --user disable --now omarchy-device-alert.service >/dev/null 2>&1 || true
rm -f "$ALERT_UNIT" "$ALERT_BIN"
systemctl --user daemon-reload

say "2/4 remove entries from shell.json"
if [ -f "$SHELL_JSON" ]; then
  jq --arg id "$PLUGIN_ID" '
    .plugins = ((.plugins // []) | map(select(.id != $id)))
    | .bar.layout.right = ((.bar.layout.right // []) | map(select(.id != $id)))
  ' "$SHELL_JSON" > "$SHELL_JSON.tmp" && mv "$SHELL_JSON.tmp" "$SHELL_JSON"
fi

say "3/4 remove launcher menu toggle"
if [ -f "$MENU_JSONC" ]; then
  python3 - "$MENU_JSONC" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
s = re.sub(r'(?m)^\s*// Virtuoso: notification sound effects toggle[^\n]*\n', '', s)
start = s.find('"trigger.toggle.notification-sounds"')
if start != -1:
    brace = s.find('{', start)
    if brace != -1:
        depth = 0; i = brace; end = len(s)
        while i < len(s):
            c = s[i]
            if c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    j = i + 1
                    while j < len(s) and s[j] in ' \t': j += 1
                    if j < len(s) and s[j] == ',': j += 1
                    while j < len(s) and s[j] in ' \t\r\n': j += 1
                    end = j
                    break
            i += 1
        s = s[:start] + s[end:]
open(p, 'w').write(s)
PY
fi

say "4/4 remove plugin folder and restart the shell"
rm -rf "$PLUGIN_DIR"
omarchy restart shell

echo
echo "Removed. The bar widget, menu toggle, and USB alerts are gone."
echo "The cloned repo and any custom Hyprland bindings are untouched."
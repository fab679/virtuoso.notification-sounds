#!/usr/bin/env bash
# Remove Omarchy Notification Sounds and everything it set up:
#   plugin folder, shell.json entries, launcher menu toggle, USB alert service,
#   the omarchy-sound CLI, the event watchers, the hooks and the keybindings.
# Safe to re-run.
set -euo pipefail

PLUGIN_ID="virtuoso.notification-sounds"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
MENU_JSONC="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
ALERT_BIN="$HOME/.local/bin/omarchy-device-alert"
ALERT_UNIT="$HOME/.config/systemd/user/omarchy-device-alert.service"

say() { printf '==> %s\n' "$*"; }

say "1/7 remove the event watcher and logout chime services"
for unit in omarchy-sound-watch.service omarchy-sound-session.service; do
  systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
  rm -f "$HOME/.config/systemd/user/$unit"
done
systemctl --user daemon-reload

say "2/7 remove the CLI, hooks and event config"
# -f removes a symlink without following it, so this never touches the plugin's
# own copies -- only the links pointing at them.
rm -f "$HOME/.local/bin/omarchy-sound" "$HOME/.local/bin/omarchy-sound-watch"
rm -f "$HOME/.config/omarchy/hooks/post-boot.d/sound-desktop-login.hook" \
      "$HOME/.config/omarchy/hooks/theme-set.d/sound-theme-changed.hook" \
      "$HOME/.config/omarchy/hooks/font-set.d/sound-font-changed.hook" \
      "$HOME/.config/omarchy/hooks/post-update.d/sound-update-finished.hook" \
      "$HOME/.config/omarchy/sound-events.conf"

say "3/7 remove the volume and screenshot keybindings"
BINDINGS="$HOME/.config/hypr/bindings.lua"
if grep -q "virtuoso.notification-sounds" "$BINDINGS" 2>/dev/null; then
  cp "$BINDINGS" "$BINDINGS.bak.$(date +%s)"
  # The block is only ever appended, so everything from its banner to the end of
  # the file belongs to this plugin and can be cut wholesale.
  python3 - "$BINDINGS" <<'PYCUT'
import sys
path = sys.argv[1]
lines = open(path).read().splitlines(keepends=True)
for i, line in enumerate(lines):
    if "Ocean sound effects (virtuoso.notification-sounds)" in line:
        start = i - 1 if i and lines[i - 1].startswith("-- ---") else i
        open(path, "w").write("".join(lines[:start]).rstrip() + "\n")
        break
PYCUT
  hyprctl reload >/dev/null 2>&1 || true
  echo "     restored, and the volume keys are back to the Omarchy defaults"
fi

say "4/7 remove USB alert service"
systemctl --user disable --now omarchy-device-alert.service >/dev/null 2>&1 || true
rm -f "$ALERT_UNIT" "$ALERT_BIN"
systemctl --user daemon-reload

say "5/7 remove entries from shell.json"
if [ -f "$SHELL_JSON" ]; then
  jq --arg id "$PLUGIN_ID" '
    .plugins = ((.plugins // []) | map(select(.id != $id)))
    | .bar.layout.right = ((.bar.layout.right // []) | map(select(.id != $id)))
  ' "$SHELL_JSON" > "$SHELL_JSON.tmp" && mv "$SHELL_JSON.tmp" "$SHELL_JSON"
fi

say "6/7 remove launcher menu toggle"
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

say "7/7 remove plugin folder and restart the shell"
rm -rf "$PLUGIN_DIR"
omarchy restart shell

echo
echo "Removed. The bar widget, menu toggle, and USB alerts are gone."
echo "The cloned repo and any custom Hyprland bindings are untouched."
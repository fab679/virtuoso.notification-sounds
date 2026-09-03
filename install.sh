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

say "1/7 place plugin files"
# Three ways this script gets run, and only one of them should copy anything:
#
#   a) from inside ~/.config/omarchy/plugins/virtuoso.notification-sounds/
#      -- what `omarchy plugin add` sets up. The repo IS the plugin directory,
#      so there is nothing to copy, and copying would destroy the .git that
#      `omarchy plugin update` needs to pull into.
#   b) from a clone elsewhere, with the plugin already installed as a git
#      checkout. Overwriting it would silently break future updates, so refuse
#      and point at the command that does the right thing.
#   c) from a clone elsewhere, with no plugin dir or a plain copy -- install by
#      staged swap, as before.
if [ "$SELF_DIR" = "$PLUGIN_DIR" ]; then
  echo "     already in place (git-managed: update with 'omarchy plugin update $PLUGIN_ID')"
elif [ -d "$PLUGIN_DIR/.git" ]; then
  echo "     $PLUGIN_DIR is a git checkout -- refusing to overwrite it." >&2
  echo "     Update it in place instead:  omarchy plugin update $PLUGIN_ID" >&2
  echo "     Then re-run this script from there to refresh the system wiring:" >&2
  echo "       $PLUGIN_DIR/install.sh" >&2
  exit 1
else
  # Stage everything in a temp dir and swap it in with one rename, so the
  # shell's file watcher sees a single change instead of ~80 (copying
  # file-by-file into a live plugin dir triggered a reload storm that crashed
  # Quickshell's IpcHandler reload path).
  STAGE="$PLUGIN_DIR.new"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  cp "$SELF_DIR/manifest.json" "$SELF_DIR/Service.qml" "$SELF_DIR/BarWidget.qml" "$STAGE/"
  cp -r "$SELF_DIR/sounds" "$STAGE/"
  cp "$SELF_DIR/install.sh" "$SELF_DIR/uninstall.sh" "$SELF_DIR/sound-events.conf" "$STAGE/"
  # Everything install.sh needs travels with the plugin, so re-running it from
  # the plugin directory works without the original clone still being around.
  for dir in bin hooks systemd hypr tools; do
    [ -d "$SELF_DIR/$dir" ] && cp -r "$SELF_DIR/$dir" "$STAGE/"
  done
  chmod +x "$STAGE/install.sh" "$STAGE/uninstall.sh" "$STAGE/bin/"* 2>/dev/null || true
  if [ -d "$PLUGIN_DIR" ]; then mv "$PLUGIN_DIR" "$PLUGIN_DIR.old"; fi
  mv "$STAGE" "$PLUGIN_DIR"
  rm -rf "$PLUGIN_DIR.old"
  echo "     copied into $PLUGIN_DIR"
fi

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
  # Linked here rather than in step 5, so --no-system still leaves this unit a
  # binary to run. USB alerts only need the notification path, not the CLI.
  ln -sfn "$PLUGIN_DIR/bin/omarchy-device-alert" "$ALERT_BIN"
  install -m644 "$SELF_DIR/systemd/omarchy-device-alert.service" "$ALERT_UNIT"
  systemctl --user daemon-reload
  systemctl --user enable --now omarchy-device-alert.service >/dev/null
  systemctl --user restart omarchy-device-alert.service >/dev/null 2>&1
  echo "     systemd user unit: omarchy-device-alert.service (enabled)"
else
  echo "     skipped (--no-usb)"
fi

say "5/7 link the omarchy-sound CLI, hooks and event watchers"
if [ "$SYSTEM" = 1 ]; then
  mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"

  # Symlinks, not copies, and this is the whole trick to painless updates:
  # `omarchy plugin update` only pulls into the plugin directory, and knows
  # nothing about ~/.local/bin or the hook directories. Copying would leave a
  # stale CLI behind every update, with no warning and no obvious symptom.
  # Pointing at the plugin directory instead means one `git merge --ff-only`
  # refreshes the CLI, the watcher, the device alert and all four hooks at once.
  for exe in omarchy-sound omarchy-sound-watch; do
    ln -sfn "$PLUGIN_DIR/bin/$exe" "$HOME/.local/bin/$exe"
  done
  for hook in post-boot/sound-desktop-login theme-set/sound-theme-changed \
              font-set/sound-font-changed post-update/sound-update-finished; do
    dir=${hook%%/*}; file=${hook##*/}
    mkdir -p "$HOME/.config/omarchy/hooks/$dir.d"
    # omarchy-hook runs anything in the .d directory with `bash <file>`, which
    # follows a symlink like any other path.
    ln -sfn "$PLUGIN_DIR/hooks/$dir/$file.hook" "$HOME/.config/omarchy/hooks/$dir.d/$file.hook"
  done

  # Never clobber a config the user has already tuned.
  [ -f "$HOME/.config/omarchy/sound-events.conf" ] ||
    install -m644 "$SELF_DIR/sound-events.conf" "$HOME/.config/omarchy/sound-events.conf"

  # Units are copied rather than linked: systemd caches unit contents until a
  # daemon-reload, so a linked unit that changed under it would be stale in a
  # way the symlink hides. Copying keeps "installed" and "loaded" in step, and
  # the reload below is what makes a changed unit take effect.
  install -m644 "$SELF_DIR/systemd/omarchy-sound-watch.service"   "$HOME/.config/systemd/user/omarchy-sound-watch.service"
  install -m644 "$SELF_DIR/systemd/omarchy-sound-session.service" "$HOME/.config/systemd/user/omarchy-sound-session.service"
  systemctl --user daemon-reload
  systemctl --user enable --now omarchy-sound-watch.service omarchy-sound-session.service >/dev/null 2>&1
  systemctl --user restart omarchy-sound-watch.service >/dev/null 2>&1
  echo "     CLI + hooks linked to the plugin, so 'omarchy plugin update' refreshes them"
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
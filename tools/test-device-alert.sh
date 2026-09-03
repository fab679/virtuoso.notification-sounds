#!/usr/bin/env bash
# Replays the real udev properties of every USB device currently attached
# through omarchy-device-alert's parser, and prints the notification it would
# raise. Uses live hardware data without needing root to fire a udev trigger.
set -uo pipefail

ALERT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/omarchy-device-alert"
ACTION="${1:-add}"

# Stub busctl so the toast is printed rather than sent.
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/busctl" <<'STUB'
#!/usr/bin/env bash
args=("$@")
for i in "${!args[@]}"; do
  if [ "${args[$i]}" = "susssasa{sv}i" ]; then
    icon="${args[$((i+3))]}"; summary="${args[$((i+4))]}"; body="${args[$((i+5))]}"
    cat="${args[$((i+10))]}"
    # notify() sends its own output to /dev/null, so report through a file.
    printf '  %-26s %-34s [%s, %s]\n' "$summary" "$body" "$cat" "$icon" >> "$TOASTS"
    exit 0
  fi
done
STUB
chmod +x "$TMP/busctl"

emit() {
  local syspath
  for syspath in /sys/bus/usb/devices/*; do
    [ -e "$syspath/idVendor" ] || continue
    echo "KERNEL[0.0] $ACTION $syspath (usb)"
    udevadm info -q property -p "$syspath" 2>/dev/null |
      grep -E '^(DEVTYPE|ID_VENDOR|ID_VENDOR_FROM_DATABASE|ID_MODEL|ID_MODEL_FROM_DATABASE|ID_USB_INTERFACES)='
    echo "ACTION=$ACTION"
    echo
  done
}

TOASTS="$TMP/toasts"; : > "$TOASTS"
echo "device-alert replay ($ACTION) -- every USB device currently attached:"
emit | TOASTS="$TOASTS" PATH="$TMP:$PATH" bash "$ALERT" -
cat "$TOASTS"
[ -s "$TOASTS" ] || { echo "  (nothing raised)"; exit 1; }

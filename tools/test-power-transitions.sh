#!/usr/bin/env bash
# Drives omarchy-sound-watch's power loop against a fake /sys/class/power_supply
# tree and asserts which sounds it decides to play. Covers the transitions that
# are otherwise only reachable by physically moving a power cable.
set -uo pipefail

WATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/omarchy-sound-watch"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
FAKE="$TMP/power"; LOG="$TMP/played"
mkdir -p "$FAKE/AC" "$FAKE/BAT0"
echo Mains > "$FAKE/AC/type"; echo Battery > "$FAKE/BAT0/type"

set_state() { echo "$1" > "$FAKE/AC/online"; echo "$2" > "$FAKE/BAT0/capacity"; echo "$3" > "$FAKE/BAT0/status"; }

# Stub the CLI so nothing is audible and every decision is recorded instead.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/omarchy-sound" <<'STUB'
#!/usr/bin/env bash
shift_to_name() { for a in "$@"; do case "$a" in play|notify) continue;; -*) continue;; *) echo "$a"; return;; esac; done; }
echo "$(shift_to_name "$@")" >> "$PLAYED"
STUB
chmod +x "$TMP/bin/omarchy-sound"

pass=0; fail=0
check() {
  local label="$1" want="$2" got
  got=$(tr '\n' ' ' < "$LOG" | sed 's/ *$//')
  if [ "$got" = "$want" ]; then printf '  ok   %-38s -> %s\n' "$label" "${got:-(silence)}"; pass=$((pass+1))
  else printf '  FAIL %-38s want [%s] got [%s]\n' "$label" "$want" "$got"; fail=$((fail+1)); fi
  : > "$LOG"
}

run() {
  : > "$LOG"
  PATH="$TMP/bin:$PATH" PLAYED="$LOG" POWER_SUPPLY_ROOT="$FAKE" \
    OMARCHY_SOUND_CONF=/dev/null SOUND_NETWORK=0 SOUND_BLUETOOTH=0 \
    timeout 4 bash -c "source '$WATCH' 2>/dev/null" >/dev/null 2>&1 &
  sleep 3.2; kill %1 2>/dev/null; wait 2>/dev/null
}

echo "power transitions"

# Each case starts the loop at one state, then flips the fake tree underneath it.
# POLL_SECONDS=1 makes the safety poll do the work, no udev needed.
scenario() {
  local label="$1" a1=$2 c1=$3 s1=$4 a2=$5 c2=$6 s2=$7 want=$8
  set_state "$a1" "$c1" "$s1"
  : > "$LOG"
  (
    export PATH="$TMP/bin:$PATH" PLAYED="$LOG" POWER_SUPPLY_ROOT="$FAKE"
    export OMARCHY_SOUND_CONF=/dev/null POLL_SECONDS=1 SOUND_NETWORK=0 SOUND_BLUETOOTH=0
    timeout 4 "$WATCH"
  ) >/dev/null 2>&1 &
  local pid=$!
  sleep 1.4
  set_state "$a2" "$c2" "$s2"
  sleep 2.2
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  check "$label" "$want"
}

scenario "AC unplugged"            1 80 Charging     0 80 Discharging  "power-unplug"
scenario "AC plugged in"           0 80 Discharging  1 80 Charging     "power-plug"
scenario "battery reaches full"    1 97 Charging     1 100 Full        "battery-full"
scenario "battery goes critical"   0 40 Discharging  0 4  Discharging  "battery-caution"
scenario "steady state, no change" 1 80 Charging     1 80 Charging     ""

echo
echo "$pass passed, $fail failed"
exit $((fail > 0))

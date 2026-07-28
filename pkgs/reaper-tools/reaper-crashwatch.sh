#!/usr/bin/env bash
# reaper-crashwatch — follows the journal for core dumps of REAPER, wine or
# yabridge processes and automatically saves a diagnostic bundle to
# ~/reaper-crashlogs/. Runs as the reaper-crashwatch systemd user service.
#
# Managed in ~/.nixos (home/apps/reaper-tools.nix packages this file).

set -u

LOGROOT="$HOME/reaper-crashlogs"
RUNDIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "reaper-crashwatch" "$1" || true; }

collect() {
  local pid="$1" comm="$2" exe ts out
  # coredumpctl needs a moment to register the entry
  sleep 3
  exe="$(coredumpctl info "$pid" 2>/dev/null | sed -n 's/^ *Executable: //p' | head -1)"
  # Ignore Steam/Proton wine crashes — only care about the DAW stack.
  case "$exe" in
    *Steam*|*steamapps*|*compatibilitytools*) return ;;
  esac
  case "$exe" in
    */REAPER/*|*yabridge*|*wine*) ;;
    *) return ;;
  esac

  ts="$(date +%Y-%m-%d_%H%M%S)"
  out="$LOGROOT/$ts-crash-$comm"
  mkdir -p "$out"

  coredumpctl info "$pid" > "$out/coredump-info.txt" 2>&1
  journalctl -q --no-pager --user --since '-15 min' > "$out/journal-user.txt" 2>&1
  journalctl -q --no-pager --since '-15 min' -t systemd-coredump > "$out/journal-coredump.txt" 2>&1
  ls -lt "$RUNDIR" 2>/dev/null | grep yabridge > "$out/yabridge-sessions.txt"
  pgrep -af 'yabridge-host|bin/reaper' > "$out/still-running.txt" 2>&1
  # newest session logs from reaper-logged (REAPER output + yabridge/Wine output)
  if [ -d "$LOGROOT/sessions" ]; then
    ls -1t "$LOGROOT/sessions" 2>/dev/null | head -2 | while IFS= read -r f; do
      cp "$LOGROOT/sessions/$f" "$out/" 2>/dev/null
    done
  fi

  {
    echo "Crash of $comm (pid $pid) at $ts"
    echo "Executable: $exe"
    echo
    echo "To get a backtrace from the stored core:"
    echo "  coredumpctl debug $pid --debugger-arguments='-batch -ex \"thread apply all bt\"'"
  } > "$out/SUMMARY.txt"

  notify "Crash bundle saved: $out"
}

# systemd-coredump logs lines like:
#   Process 1234 (reaper) of user 1000 dumped core.
journalctl -f -q --no-pager -o cat -t systemd-coredump --since now |
while IFS= read -r line; do
  case "$line" in
    *"dumped core"*) ;;
    *) continue ;;
  esac
  pid="$(sed -n 's/.*Process \([0-9]\+\) .*/\1/p' <<<"$line")"
  comm="$(sed -n 's/.*Process [0-9]\+ (\([^)]*\)).*/\1/p' <<<"$line")"
  [ -n "$pid" ] || continue
  collect "$pid" "$comm"
done

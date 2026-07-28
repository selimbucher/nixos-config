#!/usr/bin/env bash
# reaper-rescue — run this when REAPER is frozen.
#
# Captures diagnostics (thread states, which yabridge plugin host is stuck,
# session logs, journal excerpt), triggers a core dump of REAPER via SIGABRT so
# systemd-coredump stores it, then kills everything and cleans up wine/yabridge
# leftovers so the next start is fast.
#
# Managed in ~/.nixos (home/apps/reaper-tools.nix packages this file).
#
# Usage:
#   reaper-rescue                capture diagnostics, kill frozen REAPER, clean up
#   reaper-rescue --cleanup-only only clean wine/yabridge leftovers (REAPER must not be running)

set -u

LOGROOT="$HOME/reaper-crashlogs"
RUNDIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
TS="$(date +%Y-%m-%d_%H%M%S)"
START="$(date '+%Y-%m-%d %H:%M:%S')"

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "reaper-rescue" "$1" || true; }

# REAPER's cmdline is just the nix profile wrapper path, so identify it by the
# executable: /nix/store/...-reaper-*/opt/REAPER/.reaper-wrapped
find_reaper() {
  local p exe
  for p in /proc/[0-9]*; do
    exe="$(readlink "$p/exe" 2>/dev/null)" || continue
    case "$exe" in
      */opt/REAPER/*) basename "$p" ;;
    esac
  done
}

# yabridge hosts run as wine-preloader with "yabridge-host.exe.so ..." cmdline.
# Require both the cmdline match and a wine/yabridge executable so shells that
# merely mention the pattern are never matched.
find_hosts() {
  local pid exe
  for pid in $(pgrep -f 'yabridge-host' 2>/dev/null); do
    exe="$(readlink "/proc/$pid/exe" 2>/dev/null)" || continue
    case "$exe" in
      *wine*|*yabridge*) echo "$pid" ;;
    esac
  done
}

# Plugin wine prefixes all live under ~/.wine* (.wine, .wine-ni, .wine-roli,
# .wine-xln, and any future ones).
prefixes() { ls -d "$HOME"/.wine* 2>/dev/null; }

plugin_of_host() {
  # host cmdline contains the socket endpoint path, whose directory name
  # embeds the plugin name: .../yabridge-<Plugin Name>-<random>
  tr '\0' '\n' < "/proc/$1/cmdline" 2>/dev/null \
    | sed -n 's#.*/yabridge-\(.*\)-[A-Za-z0-9]\{8,\}.*#\1#p' | head -1
}

cleanup_wine() {
  local hosts h p
  hosts="$(find_hosts)"
  if [ -n "$hosts" ]; then
    echo "Stopping yabridge host processes:"
    for h in $hosts; do echo "  $h ($(plugin_of_host "$h"))"; done
    kill $hosts 2>/dev/null
    sleep 2
    hosts="$(find_hosts)"
    [ -n "$hosts" ] && kill -9 $hosts 2>/dev/null
  fi
  # wineserver-yabridge (media.nix) is yabridge's pinned wine — the interactive
  # `wineserver` (wine-staging) must never touch the plugin prefixes.
  while IFS= read -r p; do
    WINEPREFIX="$p" wineserver-yabridge -k 2>/dev/null
  done < <(prefixes)
  sleep 1
  while IFS= read -r p; do
    WINEPREFIX="$p" wineserver-yabridge -k9 2>/dev/null
  done < <(prefixes)
  find "$RUNDIR" -maxdepth 1 -name 'yabridge-*' -exec rm -rf {} + 2>/dev/null
  echo "Wine/yabridge leftovers cleaned (prefixes: $(prefixes | tr '\n' ' '))."
}

if [ "${1:-}" = "--cleanup-only" ]; then
  if [ -n "$(find_reaper)" ]; then
    echo "REAPER is running — refusing --cleanup-only. Run without flags to rescue a frozen REAPER." >&2
    exit 1
  fi
  cleanup_wine
  exit 0
fi

RPID="$(find_reaper | head -1)"
if [ -z "$RPID" ]; then
  echo "No running REAPER found. Use --cleanup-only to just clean wine/yabridge leftovers." >&2
  exit 1
fi

OUT="$LOGROOT/$TS-freeze"
mkdir -p "$OUT"
echo "Collecting diagnostics into $OUT ..."

{ date; echo "reaper pid: $RPID"; readlink "/proc/$RPID/exe"; uname -a; } > "$OUT/meta.txt"

# Thread states of REAPER itself. In a plugin-induced freeze the main thread
# is typically blocked in poll/futex waiting on a yabridge socket.
ps -L -o pid,tid,stat,pcpu,wchan:32,comm -p "$RPID" > "$OUT/reaper-threads.txt" 2>&1
cat "/proc/$RPID/status" > "$OUT/reaper-status.txt" 2>/dev/null

# Per-host diagnostics: plugin name, CPU, thread states. A host with a
# D-state thread or one spinning at ~100% CPU is the prime suspect.
HOSTS="$(find_hosts)"
: > "$OUT/hosts.txt"
for h in $HOSTS; do
  {
    echo "=== pid $h — plugin: $(plugin_of_host "$h") ==="
    tr '\0' ' ' < "/proc/$h/cmdline" 2>/dev/null; echo
    ps -L -o pid,tid,stat,pcpu,wchan:32,comm -p "$h" 2>&1
    echo
  } >> "$OUT/hosts.txt"
done

# Suspect ranking by CPU + D-state threads
{
  echo "yabridge hosts ranked by CPU (top = most likely culprit if spinning):"
  for h in $HOSTS; do
    printf '%6.1f%%  pid %-8s D-threads:%-3s %s\n' \
      "$(ps -o pcpu= -p "$h" 2>/dev/null || echo 0)" \
      "$h" \
      "$(ps -L -o stat= -p "$h" 2>/dev/null | grep -c '^D' || true)" \
      "$(plugin_of_host "$h")"
  done | sort -rn
} > "$OUT/suspects.txt" 2>&1

ls -lt "$RUNDIR" 2>/dev/null | grep yabridge > "$OUT/yabridge-sessions.txt"

# Session logs written by reaper-logged: REAPER's stdout/stderr and the
# yabridge/plugin/Wine output (YABRIDGE_DEBUG_FILE). Copy the newest session.
if [ -d "$LOGROOT/sessions" ]; then
  ls -1t "$LOGROOT/sessions" 2>/dev/null | head -2 | while IFS= read -r f; do
    cp "$LOGROOT/sessions/$f" "$OUT/" 2>/dev/null
  done
fi

journalctl -q --no-pager --user --since '-15 min' > "$OUT/journal-user.txt" 2>&1
journalctl -q --no-pager --since '-15 min' -t systemd-coredump > "$OUT/journal-coredump.txt" 2>&1

# Live backtrace of the frozen process (gdb is installed via reaper-tools.nix).
if command -v gdb >/dev/null 2>&1; then
  timeout 30 gdb -batch -p "$RPID" -ex 'thread apply all bt' \
    > "$OUT/reaper-backtrace.txt" 2>&1
fi

echo "Sending SIGABRT to REAPER (pid $RPID) so systemd-coredump saves a core ..."
kill -ABRT "$RPID" 2>/dev/null
for _ in $(seq 1 15); do
  kill -0 "$RPID" 2>/dev/null || break
  sleep 1
done
if kill -0 "$RPID" 2>/dev/null; then
  echo "REAPER did not exit on SIGABRT, sending SIGKILL (no core for this one)."
  kill -9 "$RPID" 2>/dev/null
  sleep 1
fi

cleanup_wine

sleep 2
coredumpctl list --no-pager --since "$START" > "$OUT/coredumps.txt" 2>&1

{
  echo "Freeze rescue bundle from $START"
  echo
  echo "Suspect ranking (see suspects.txt / hosts.txt for details):"
  cat "$OUT/suspects.txt"
  echo
  echo "Core dumps recorded during rescue (see coredumps.txt):"
  tail -n +1 "$OUT/coredumps.txt"
  echo
  echo "To get a backtrace from the core later:"
  echo "  coredumpctl debug <PID> --debugger-arguments='-batch -ex \"thread apply all bt\"'"
} > "$OUT/SUMMARY.txt"

echo
cat "$OUT/SUMMARY.txt"
notify "REAPER rescued — diagnostics in $OUT"
echo
echo "Done. REAPER is safe to restart; wine leftovers were cleaned so it should start fast."
echo "Recovered autosaves (if any): check '$HOME/Documents/REAPER Media/Backups/'"

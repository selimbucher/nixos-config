#!/usr/bin/env bash
# reaper-rescue — run this when REAPER is frozen.
#
# Captures diagnostics (thread states, which yabridge plugin host is stuck,
# socket peers, backtraces of REAPER *and* of every Wine host/wineserver,
# session logs, journal excerpt), triggers a core dump of REAPER via SIGABRT so
# systemd-coredump stores it, then kills everything and cleans up wine/yabridge
# leftovers so the next start is fast.
#
# Managed in ~/.nixos (home/apps/reaper-tools.nix packages this file).
#
# Usage:
#   reaper-rescue                capture diagnostics, kill frozen REAPER, clean up
#   reaper-rescue --capture-only capture diagnostics only, kill NOTHING (REAPER keeps
#                                running; used by the crashwatch wedge watchdog)
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

prefix_of_host() {
  tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null | sed -n 's/^WINEPREFIX=//p' | head -1
}

# The DAW wineservers run yabridge's pinned wine (store path contains
# "yabridge"); Steam/Proton wineservers live elsewhere and are never matched.
find_yabridge_wineservers() {
  local pid exe
  for pid in $(pgrep -x wineserver 2>/dev/null); do
    exe="$(readlink "/proc/$pid/exe" 2>/dev/null)" || continue
    case "$exe" in *yabridge*) echo "$pid" ;; esac
  done
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

CAPTURE_ONLY=0
[ "${1:-}" = "--capture-only" ] && CAPTURE_ONLY=1

RPID="$(find_reaper | head -1)"
if [ -z "$RPID" ]; then
  echo "No running REAPER found. Use --cleanup-only to just clean wine/yabridge leftovers." >&2
  exit 1
fi

SUFFIX=freeze; [ "$CAPTURE_ONLY" = 1 ] && SUFFIX=wedge
OUT="$LOGROOT/$TS-$SUFFIX"
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
    echo "=== pid $h — plugin: $(plugin_of_host "$h") — prefix: $(prefix_of_host "$h") ==="
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

# --- wedge fingerprint ------------------------------------------------------
# The most decisive artifact in the bundle, and the cheapest: for REAPER's main
# (GUI) thread and every host's MAIN thread, how much CPU it burned over a 3s
# window and what it is blocked in.
#
# In a bridged-plugin wedge REAPER's main thread shows 0 ticks parked in a
# futex/socket wait, and exactly ONE host's main thread sits in a non-idle
# wchan while every other host idles in do_epoll_wait — that host is the one
# still holding the synchronous call, i.e. the culprit.
#
# Why this exists: on 2026-08-25 this table named Kontakt 8 in a single line,
# while the gdb stacks were unsymbolised Wine addresses, no
# RtlpWaitForCriticalSection warning was ever logged, and the CPU ranking
# pointed at the wrong plugin (Kontakt's *audio* threads were still running
# happily — only its main thread was stuck).
main_ticks() { # pid -> utime+stime jiffies of the main thread (tid == pid)
  local s
  s="$(cat "/proc/$1/task/$1/stat" 2>/dev/null)" || return 1
  s="${s##*) }" # drop "pid (comm) "; comm can contain spaces
  # remaining fields start at state, so utime/stime are 12 and 13
  # shellcheck disable=SC2086
  set -- $s
  echo $(( ${12} + ${13} ))
}
main_wchan() { cat "/proc/$1/task/$1/wchan" 2>/dev/null || echo '?'; }

{
  declare -A T0
  T0[$RPID]="$(main_ticks "$RPID")"
  for h in $HOSTS; do T0[$h]="$(main_ticks "$h")"; done
  sleep 3
  echo "Main-thread activity over a 3s window (ticks = CPU jiffies burned)."
  echo
  echo "REAPER main thread at 0 ticks in a non-poll wait  => the UI is frozen."
  echo "The ONE host whose main thread is not in do_epoll_wait is the plugin"
  echo "still holding the call REAPER is blocked on. Host audio threads keep"
  echo "running during a wedge, so overall host CPU is a misleading suspect."
  echo
  printf '%-26s %-8s %-9s %s\n' PROCESS PID 'TICKS/3s' WCHAN
  printf '%-26s %-8s %-9s %s\n' 'REAPER (main/GUI)' "$RPID" \
    "$(( $(main_ticks "$RPID") - ${T0[$RPID]} ))" "$(main_wchan "$RPID")"
  for h in $HOSTS; do
    printf '%-26s %-8s %-9s %s\n' "$(plugin_of_host "$h")" "$h" \
      "$(( $(main_ticks "$h") - ${T0[$h]} ))" "$(main_wchan "$h")"
  done
} > "$OUT/wedge-fingerprint.txt" 2>&1

ls -lt "$RUNDIR" 2>/dev/null | grep yabridge > "$OUT/yabridge-sessions.txt"

# A REAPER autosave that was in flight when the freeze hit leaves a zero-byte
# *.rpp-bak-NEWTEMP behind — it dates the freeze to the second and tells you
# which backup is the newest complete one to recover from.
{
  awk -F= '/^autosavedir=/{print $2}' "$HOME/.config/REAPER/reaper.ini" 2>/dev/null
  echo "$HOME/Documents/REAPER Media/Backups"
} | while IFS= read -r d; do
  # reaper.ini's autosavedir and the default are usually the same directory
  # written two ways (trailing slash) — resolve before deduplicating.
  [ -n "$d" ] && [ -d "$d" ] && realpath "$d" 2>/dev/null
done | sort -u | while IFS= read -r d; do
  echo "=== $d"
  ls -lt "$d" 2>/dev/null | head -8
  echo
done > "$OUT/autosave-state.txt" 2>&1

# Session logs written by reaper-logged: REAPER's stdout/stderr and the
# yabridge/plugin/Wine output (YABRIDGE_DEBUG_FILE). Take the newest of EACH
# kind and skip the current-* symlinks — "head -2 across all files" once
# shipped a bundle containing the current-reaper.log symlink and no real
# reaper.log at all (2026-08-25 wedge bundle).
if [ -d "$LOGROOT/sessions" ]; then
  for pat in '-reaper\.log$' '-yabridge\.log$'; do
    ls -1t "$LOGROOT/sessions" 2>/dev/null | grep -v '^current-' | grep -e "$pat" \
      | head -1 | while IFS= read -r f; do
      cp "$LOGROOT/sessions/$f" "$OUT/" 2>/dev/null
    done
  done
fi

journalctl -q --no-pager --user --since '-15 min' > "$OUT/journal-user.txt" 2>&1
journalctl -q --no-pager --since '-15 min' -t systemd-coredump > "$OUT/journal-coredump.txt" 2>&1

# Unix-socket peer map: shows exactly which host (or wineserver) each blocked
# yabridge socket in REAPER is connected to — names the hang source directly.
command -v ss >/dev/null 2>&1 && ss -xp > "$OUT/unix-sockets.txt" 2>&1

# Live backtrace of the frozen process (gdb is installed via reaper-tools.nix).
if command -v gdb >/dev/null 2>&1; then
  timeout 30 gdb -batch -p "$RPID" -ex 'thread apply all bt' \
    > "$OUT/reaper-backtrace.txt" 2>&1

  # Backtraces of the Wine hosts and wineservers, captured while still alive.
  # The REAPER-side core only proves a host stopped answering; the host-side
  # stack shows why (X11/clipboard stall, internal deadlock, wineserver wait).
  echo "Capturing backtraces of $(echo "$HOSTS" | wc -w) Wine hosts (can take a minute) ..."
  : > "$OUT/host-backtraces.txt"
  for h in $HOSTS; do
    {
      echo "=== host $h — plugin: $(plugin_of_host "$h") — prefix: $(prefix_of_host "$h") ==="
      timeout 20 gdb -batch -p "$h" -ex 'thread apply all bt' 2>&1
      echo
    } >> "$OUT/host-backtraces.txt"
  done
  for w in $(find_yabridge_wineservers); do
    {
      echo "=== wineserver $w ==="
      timeout 10 gdb -batch -p "$w" -ex 'thread apply all bt' 2>&1
      echo
    } >> "$OUT/host-backtraces.txt"
  done
fi

if [ "$CAPTURE_ONLY" = 1 ]; then
  {
    echo "Wedge capture bundle from $START — nothing was killed, REAPER left running."
    echo
    echo "READ THIS FIRST — wedge fingerprint (wedge-fingerprint.txt):"
    cat "$OUT/wedge-fingerprint.txt"
    echo
    echo "Suspect ranking by total CPU (details: suspects.txt / hosts.txt;"
    echo "host-side stacks: host-backtraces.txt; socket peer map:"
    echo "unix-sockets.txt; autosave state: autosave-state.txt):"
    cat "$OUT/suspects.txt"
  } > "$OUT/SUMMARY.txt"
  echo
  cat "$OUT/SUMMARY.txt"
  notify "Wedge diagnostics captured in $OUT (REAPER left running)"
  exit 0
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
  echo "Suspect ranking (details: suspects.txt / hosts.txt; host-side stacks:"
  echo "host-backtraces.txt; socket peer map: unix-sockets.txt):"
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

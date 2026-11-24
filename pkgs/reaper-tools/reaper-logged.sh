#!/usr/bin/env bash
# reaper-logged — launches REAPER with full log capture. This is what the
# desktop entry runs (and what reaper-launch forwards to).
#
#   - cleans wine/yabridge leftovers from a previous kill BEFORE starting,
#     but only when no other REAPER instance is running
#   - sets YABRIDGE_DEBUG_FILE so all yabridge/plugin/Wine output is kept
#   - captures REAPER's own stdout/stderr
#
# Logs land in ~/.local/state/reaper/sessions/ (XDG_STATE_HOME); the newest 10
# sessions are kept, and an earlier log over 100 MB is cut to its last 50 MB.
# reaper-rescue pulls these logs into its bundles.
#
# Managed in ~/.nixos (home/apps/reaper-tools.nix packages this file).

set -u

SESSIONS="${XDG_STATE_HOME:-$HOME/.local/state}/reaper/sessions"
mkdir -p "$SESSIONS"
TS="$(date +%Y-%m-%d_%H%M%S)"
LOG="$SESSIONS/$TS-reaper.log"

# keep the newest 10 sessions (2 files each; current-* symlinks are kept)
ls -1t "$SESSIONS" 2>/dev/null | grep -v '^current-' | tail -n +21 | while IFS= read -r f; do
  rm -f "$SESSIONS/$f"
done
# a Wine server with tracing on once wrote 5.6 GB into a session's log
find "$SESSIONS" -maxdepth 1 -type f -name '*.log' -size +100M | while IFS= read -r f; do
  tail -c 50M "$f" > "$f.cut" && mv "$f.cut" "$f"
done

# Boot every yabridge plugin prefix (the ~/.wine* prefixes yabridgectl syncs
# plugins from) in parallel while REAPER starts. REAPER loads a project's FX
# one at a time, and the first plugin from a cold prefix waits for its
# wineserver, wineboot and services to start: 2-3s per prefix, all of it in
# series with the rest of the project (measured on track3.RPP: 52.7s -> 47.8s
# with only this). The warm-up is a GUI-less rundll32 call, which also builds
# the prefix's font cache; -p60 keeps the server and services up for a minute
# after it so REAPER's hosts find them running. Prefixes the project doesn't
# use shut down again by themselves.
prewarm_prefixes() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/yabridgectl/config.toml" p
  [ -f "$cfg" ] || return 0
  sed -n "s#^[[:space:]]*['\"]\(/.*\)/drive_c/.*#\1#p" "$cfg" | sort -u |
  while IFS= read -r p; do
    [ -f "$p/system.reg" ] || continue
    ( WINEPREFIX="$p" wineserver-yabridge -p60
      WINEPREFIX="$p" wine-yabridge rundll32.exe user32.dll,GetDesktopWindow ) </dev/null &
  done
}

# reaper-rescue itself refuses cleanup while a REAPER instance is running
# (then the prefixes are in use and nothing needs warming).
if reaper-rescue --cleanup-only >>"$LOG" 2>&1; then
  prewarm_prefixes >>"$LOG" 2>&1
fi

# All yabridge debug output plus everything the plugins and Wine print.
# Bump YABRIDGE_DEBUG_LEVEL to 1 or 2 here when hunting a specific bug.
export YABRIDGE_DEBUG_FILE="$SESSIONS/$TS-yabridge.log"

# Stable names for the current session's logs.
ln -sfn "$TS-yabridge.log" "$SESSIONS/current-yabridge.log"
ln -sfn "$TS-reaper.log" "$SESSIONS/current-reaper.log"

# pw-jack only matters if REAPER's audio system is set to JACK (it routes the
# JACK API to PipeWire); with the current ALSA backend it is a no-op but kept
# so a backend switch keeps working.
exec pw-jack reaper "$@" >>"$LOG" 2>&1

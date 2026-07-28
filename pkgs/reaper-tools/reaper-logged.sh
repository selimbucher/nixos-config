#!/usr/bin/env bash
# reaper-logged — launches REAPER with full log capture. This is what the
# desktop entry runs (and what reaper-launch forwards to).
#
#   - cleans wine/yabridge leftovers from a previous kill BEFORE starting,
#     but only when no other REAPER instance is running
#   - sets YABRIDGE_DEBUG_FILE so all yabridge/plugin/Wine output is kept
#   - captures REAPER's own stdout/stderr
#
# Logs land in ~/reaper-crashlogs/sessions/, newest 20 sessions are kept.
# reaper-rescue and reaper-crashwatch pull these logs into crash bundles.
#
# Managed in ~/.nixos (home/apps/reaper-tools.nix packages this file).

set -u

SESSIONS="$HOME/reaper-crashlogs/sessions"
mkdir -p "$SESSIONS"
TS="$(date +%Y-%m-%d_%H%M%S)"
LOG="$SESSIONS/$TS-reaper.log"

# keep the newest 20 sessions (2 files each)
ls -1t "$SESSIONS" 2>/dev/null | tail -n +41 | while IFS= read -r f; do
  rm -f "$SESSIONS/$f"
done

# reaper-rescue itself refuses cleanup while a REAPER instance is running,
# so this is safe to call unconditionally.
reaper-rescue --cleanup-only >>"$LOG" 2>&1

# All yabridge debug output plus everything the plugins and Wine print.
# Bump YABRIDGE_DEBUG_LEVEL to 1 or 2 here when hunting a specific bug.
export YABRIDGE_DEBUG_FILE="$SESSIONS/$TS-yabridge.log"

# pw-jack only matters if REAPER's audio system is set to JACK (it routes the
# JACK API to PipeWire); with the current ALSA backend it is a no-op but kept
# so a backend switch keeps working.
exec pw-jack reaper "$@" >>"$LOG" 2>&1

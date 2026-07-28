#!/usr/bin/env bash
# reaper-autosave-fix — converges REAPER autosave settings in reaper.ini.
#
# reaper.ini must stay writable (REAPER rewrites the whole file on every clean
# exit), so it cannot be a read-only home-manager file. Instead this script
# enforces just the autosave keys and home-manager re-runs it on every
# activation, so the settings converge without freezing the rest of the file.
#
# Enforced:
#   autosavemode=2       autosave any time (incl. during playback/recording)
#   saveopts bit &8      "save to timestamped file in additional directory"
#   autosaveint          present (default 2 min; a custom interval is kept)
#   autosavedir          set (default Backups dir; a custom dir is kept)
#
# Key semantics documented in mespotine/ultraschall-and-reaper-docs.
# Managed in ~/.nixos (home/apps/reaper-tools.nix packages this file).

set -eu

ini="$HOME/.config/REAPER/reaper.ini"
[ -f "$ini" ] || exit 0

# If REAPER is running it would overwrite the edit on exit — skip; the next
# activation converges. (REAPER's cmdline is a wrapper path; check /proc exe.)
for p in /proc/[0-9]*; do
  case "$(readlink "$p/exe" 2>/dev/null)" in
    */opt/REAPER/*)
      echo "reaper-autosave-fix: REAPER is running, skipping (applies on next activation)"
      exit 0
      ;;
  esac
done

tmp="$(mktemp)"
awk -v dir="$HOME/Documents/REAPER Media/Backups/" '
  function flush_missing() {
    if (!seen_mode) print "autosavemode=2"
    if (!seen_int)  print "autosaveint=2"
    if (!seen_dir)  print "autosavedir=" dir
  }
  /^\[/ {
    if (in_reaper) { flush_missing(); in_reaper = 0 }
    if (tolower($0) == "[reaper]") in_reaper = 1
    print; next
  }
  in_reaper && /^autosavemode=/ { print "autosavemode=2"; seen_mode = 1; next }
  in_reaper && /^autosaveint=/  { seen_int = 1; print; next }
  in_reaper && /^autosavedir=/  {
    seen_dir = 1
    if ($0 == "autosavedir=") print "autosavedir=" dir; else print
    next
  }
  in_reaper && /^saveopts=/ {
    v = substr($0, index($0, "=") + 1) + 0
    if (int(v / 8) % 2 == 0) v += 8
    print "saveopts=" v
    next
  }
  { print }
  END { if (in_reaper) flush_missing() }
' "$ini" > "$tmp"

if ! cmp -s "$ini" "$tmp"; then
  cp "$ini" "$ini.pre-autosave-fix"
  mv "$tmp" "$ini"
  echo "reaper-autosave-fix: updated $ini (backup at $ini.pre-autosave-fix)"
else
  rm -f "$tmp"
fi

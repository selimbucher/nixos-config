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
  # newest session logs from reaper-logged (REAPER output + yabridge/Wine
  # output). Take the newest of EACH kind — "head -2 across all files" once
  # bundled two reaper.logs and skipped the yabridge log entirely when a new
  # session had just started (2026-08-16 16:45 crash bundle).
  if [ -d "$LOGROOT/sessions" ]; then
    for pat in '-reaper\.log$' '-yabridge\.log$'; do
      ls -1t "$LOGROOT/sessions" 2>/dev/null | grep -e "$pat" | head -2 | while IFS= read -r f; do
        cp "$LOGROOT/sessions/$f" "$out/" 2>/dev/null
      done
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

# --- wedge watchdog ---------------------------------------------------------
# A deadlocked Wine plugin host announces itself in the live session log as
#   err:sync:RtlpWaitForCriticalSection ... retrying (60 sec)
# minutes before REAPER visibly freezes (the next plugin-state save then
# blocks forever). Capture host-side stacks immediately, while everything is
# still alive, and warn the user. One capture per plugin per session.
# Polling (not tail -F): the signature line repeats every 60s and persists in
# the file, so a 30s grep can't miss it — and tail -F does not reliably
# notice the current-* symlink being retargeted at session start.
watch_wedges() {
  local link="$LOGROOT/sessions/current-yabridge.log" cur="" seen="" tgt plugin
  while :; do
    sleep 30
    tgt="$(readlink -f "$link" 2>/dev/null)" || continue
    [ -f "$tgt" ] || continue
    [ "$tgt" = "$cur" ] || { cur="$tgt"; seen=""; }
    while IFS= read -r plugin; do
      [ -n "$plugin" ] || plugin=unknown
      case " $seen " in *" $plugin "*) continue ;; esac
      seen="$seen $plugin"
      command -v notify-send >/dev/null 2>&1 && notify-send -u critical "reaper-crashwatch" \
        "Wine host for '$plugin' deadlocked — capturing stacks now. REAPER will freeze at the next save/autosave; run reaper-rescue then." || true
      reaper-rescue --capture-only >/dev/null 2>&1 || true
    done < <(grep 'RtlpWaitForCriticalSection' "$tgt" 2>/dev/null \
             | sed -n 's/^[0-9:]*[[:space:]]*\[\(.*\)-[A-Za-z0-9]\{8,\}\].*/\1/p' | sort -u)
  done
}
watch_wedges &

# --- GUI-stall watchdog -----------------------------------------------------
# The log-signature watchdog above only fires on the ONE failure mode that
# announces itself (a Wine critical-section deadlock). The 2026-08-25 freeze
# produced zero such lines: REAPER's main thread was parked in a futex inside
# Vst3PluginProxyImpl::getState() with Kontakt 8's host main thread blocked on
# the other side, and nothing was ever written to the log. Nothing was
# captured, because nothing knew to look.
#
# So detect the symptom instead of a cause: REAPER's main (GUI) thread burning
# ZERO CPU while parked in a blocking wait. A live REAPER always burns some
# main-thread CPU on its UI timers, and a normal idle UI waits in poll/epoll —
# so 0 ticks for STALL_STRIKES*10s in a futex/socket/pipe wait means the UI is
# wedged, whatever the cause. Fires once per stall episode; resets when the
# main thread ticks again or REAPER restarts.
STALL_STRIKES=3 # x10s sample interval => ~30s of a hard-stalled GUI

# utime+stime of a process's MAIN thread (tid == pid). "pid (comm) " is
# stripped first because comm can contain spaces; the remaining fields start
# at state, putting utime/stime at 12 and 13.
main_ticks() {
  local s
  s="$(cat "/proc/$1/task/$1/stat" 2>/dev/null)" || return 1
  s="${s##*) }"
  # shellcheck disable=SC2086
  set -- $s
  echo $(( ${12} + ${13} ))
}

watch_gui_stall() {
  local rpid prev_pid="" prev_ticks="" ticks wchan strikes=0 fired=0
  while :; do
    sleep 10
    rpid="$(pgrep -x .reaper-wrapped 2>/dev/null | head -1)"
    if [ -z "$rpid" ]; then
      prev_pid=""; prev_ticks=""; strikes=0; fired=0; continue
    fi
    if [ "$rpid" != "$prev_pid" ]; then
      prev_pid="$rpid"; prev_ticks="$(main_ticks "$rpid")"
      strikes=0; fired=0; continue
    fi
    ticks="$(main_ticks "$rpid")" || continue
    wchan="$(cat "/proc/$rpid/task/$rpid/wchan" 2>/dev/null)"

    # A blocking wait, as opposed to the poll/epoll/select an idle UI sits in.
    case "$wchan" in
      futex*|unix_stream*|pipe_read|sk_wait*|*rwsem*|*mutex*|do_wait) ;;
      *) strikes=0; fired=0; prev_ticks="$ticks"; continue ;;
    esac

    if [ "$ticks" = "$prev_ticks" ]; then
      strikes=$(( strikes + 1 ))
    else
      strikes=0; fired=0
    fi
    prev_ticks="$ticks"

    if [ "$strikes" -ge "$STALL_STRIKES" ] && [ "$fired" = 0 ]; then
      fired=1
      command -v notify-send >/dev/null 2>&1 && notify-send -u critical "reaper-crashwatch" \
        "REAPER's UI is frozen (main thread stalled in $wchan) — capturing diagnostics. See wedge-fingerprint.txt for the guilty plugin." || true
      reaper-rescue --capture-only >/dev/null 2>&1 || true
    fi
  done
}
watch_gui_stall &

# --- host-death watchdog ----------------------------------------------------
# Wine hosts killed by fatal X11 errors exit() cleanly — no core, no
# systemd-coredump entry — so the only evidence is their stderr in the live
# session log. REAPER itself only crashes later, IF a call was in flight.
# Capture a mini-bundle the moment any host vanishes while REAPER is alive,
# so every death can be root-caused individually.
watch_host_deaths() {
  declare -A name
  local prev="" cur pid plugin ts out tgt n vanished
  while :; do
    sleep 2
    cur=""
    for pid in $(pgrep -f 'yabridge-host.exe.so' 2>/dev/null | sort); do
      # pgrep -f also matches unrelated processes that merely mention the
      # binary on their command line (shells, greps) — require the real comm.
      if [ -z "${name[$pid]:-}" ]; then
        [ "$(cat "/proc/$pid/comm" 2>/dev/null)" = "yabridge-host.e" ] || continue
        plugin="$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | sed -n 3p)"
        plugin="${plugin##*/}"; plugin="${plugin%.vst3}"; plugin="${plugin%.clap}"
        name[$pid]="${plugin:-unknown}"
      fi
      cur="$cur$pid"$'\n'
    done
    if [ -n "$prev" ] && pgrep -x .reaper-wrapped >/dev/null 2>&1; then
      vanished="$(comm -23 <(printf '%s' "$prev") <(printf '%s' "$cur"))"
      n="$(printf '%s' "$vanished" | grep -c . || true)"
      if [ "$n" -ge 1 ] && [ "$n" -le 3 ]; then
        tgt="$(readlink -f "$LOGROOT/sessions/current-yabridge.log" 2>/dev/null)"
        for pid in $vanished; do
          plugin="${name[$pid]:-unknown}"
          ts="$(date +%Y-%m-%d_%H%M%S)"
          out="$LOGROOT/$ts-hostdeath-$plugin"
          mkdir -p "$out"
          {
            echo "yabridge host for '$plugin' (pid $pid) died at $ts"
            echo "while REAPER kept running. Its last stderr lines are in"
            echo "instance-log.txt; the surrounding session log in session-tail.txt."
          } > "$out/SUMMARY.txt"
          if [ -n "$tgt" ] && [ -f "$tgt" ]; then
            grep -F "[$plugin-" "$tgt" 2>/dev/null | tail -100 > "$out/instance-log.txt"
            tail -60 "$tgt" > "$out/session-tail.txt" 2>/dev/null
          fi
          journalctl -q --no-pager --user --since '-3 min' > "$out/journal-user.txt" 2>&1
          journalctl -q --no-pager -k --since '-3 min' > "$out/journal-kernel.txt" 2>&1
          pgrep -af 'yabridge-host|bin/reaper' > "$out/survivors.txt" 2>&1
          notify "Wine host for '$plugin' died (REAPER still up) — bundle: $out"
          unset "name[$pid]"
        done
      fi
    fi
    prev="$cur"
  done
}
watch_host_deaths &

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

# tardis — one command for the AIC remote desktop: ensures a VNC desktop is
# running on a Tardis machine, opens the SSH tunnel in the background, starts
# the viewer, and tears the tunnel down when the viewer closes. Needs the VPN
# off campus (`ethvpn`). Uses the `tardis-*` block in ~/.ssh/config, so one
# login covers all SSH calls.
{ writeShellApplication
, openssh
, tigervnc
, jq
, gawk
}:
writeShellApplication {
  name = "tardis";
  runtimeInputs = [ openssh tigervnc jq gawk ];
  text = ''
    conf=''${XDG_CONFIG_HOME:-$HOME/.config}/tardis
    mkdir -p "$conf"

    print_help() {
      cat <<'EOF'
    tardis — AIC remote desktop on the Tardis lab machines

    Usage:
      tardis [MACHINE]       open the desktop (MACHINE e.g. b11; default: last used, else b18)
      tardis off [MACHINE]   stop the desktop on the machine
      tardis user NAME       set the AIC course username
      tardis scale FACTOR    desktop scale, e.g. 1.75 (default: local monitor scale)
      tardis -h              this help

    Inside the desktop: Alt+F1 opens the applications menu, Ctrl+Esc the
    desktop menu (Super stays with Hyprland). The viewer sends key positions,
    so the remote layout must match the physical keyboard: Swiss German by
    default, Alt+Shift toggles to US. The desktop scale follows the local
    monitor or `tardis scale`; on the lab side `~/.local/bin/scale FACTOR`
    switches it by hand.

    Optional:
      ssh-copy-id USER@tardis-b11           # no SSH password prompts afterwards
      vncpasswd ~/.config/tardis/vncpasswd  # no VNC password prompt afterwards
    EOF
    }

    user_file=$conf/user
    host_file=$conf/host
    pw_file=$conf/vncpasswd

    get_user() {
      if [ ! -s "$user_file" ]; then
        read -rp 'AIC course username: ' u </dev/tty
        printf '%s' "$u" > "$user_file"
      fi
      cat "$user_file"
    }

    target() {
      local m=''${1:-}
      if [ -z "$m" ] && [ -s "$host_file" ]; then m=$(cat "$host_file"); fi
      m=''${m:-b18}
      m=''${m#tardis-}
      printf '%s' "$m" > "$host_file"
      echo "$(get_user)@tardis-$m"
    }

    # first display number of a running desktop, empty if none
    display() {
      ssh "$1" 'vncserver -list 2>/dev/null' | { grep -oE '^:[0-9]+' || true; } | head -1 | tr -d :
    }

    do_open() {
      local host disp port
      host=$(target "''${1:-}")
      if ! ssh -o ConnectTimeout=10 "$host" true; then
        echo "cannot reach $host (ethvpn? try another machine number)" >&2
        return 1
      fi
      disp=$(display "$host")
      if [ -z "$disp" ]; then
        # first time: vncpasswd needs a tty. The server itself must start
        # without one, or its desktop session dies with the SSH session.
        ssh "$host" 'test -s ~/.vnc/passwd' || ssh -t "$host" vncpasswd
        ssh "$host" 'vncserver </dev/null >/dev/null 2>&1'
        disp=$(display "$host")
      fi
      if [ -z "$disp" ]; then
        echo "no VNC desktop found on $host" >&2
        ssh -O exit "$host" 2>/dev/null || true
        return 1
      fi
      port=$((5900 + disp))
      # shellcheck disable=SC2029
      ssh "$host" "DISPLAY=:$disp setxkbmap -layout ch,us -variant de, -option grp:alt_shift_toggle" 2>/dev/null || true
      # desktop scale: ~/.config/tardis/scale (e.g. 1.75), else the local monitor
      # scale. GTK's window scale is integer on X11, so fractions go via font DPI.
      local scale gdk dpi cur
      if [ -s "$conf/scale" ]; then
        scale=$(cat "$conf/scale")
      elif command -v hyprctl >/dev/null; then
        scale=$(hyprctl monitors -j 2>/dev/null | jq -r '[.[] | select(.focused)][0].scale // 1' || echo 1)
      else
        scale=1
      fi
      gdk=1; case "$scale" in 2|2.*|3*) gdk=2 ;; esac
      dpi=$(awk "BEGIN{printf \"%d\", 96*$scale}")
      cur=$(awk "BEGIN{printf \"%d\", 24*$scale}")
      # shellcheck disable=SC2029
      # Qt apps (Virtuoso) read QT_SCALE_FACTOR at start: ~/.xsessionrc is
      # sourced by the lab's Xsession, so it applies to the next desktop session.
      ssh "$host" "export DISPLAY=:$disp
        xfconf-query -c xsettings -p /Gdk/WindowScalingFactor -n -t int -s $gdk
        xfconf-query -c xsettings -p /Xft/DPI -n -t int -s $dpi
        xfconf-query -c xsettings -p /Gtk/CursorThemeSize -n -t int -s $cur
        printf 'export QT_SCALE_FACTOR=%s\\nexport QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough\\n' $scale > ~/.xsessionrc" 2>/dev/null || true
      ssh -f -N -o ExitOnForwardFailure=yes -L "$port:localhost:$port" "$host"
      echo "$host display :$disp, tunnel on $port"
      if [ -s "$pw_file" ]; then
        vncviewer -passwd "$pw_file" "localhost:$disp" || true
      else
        vncviewer "localhost:$disp" || true
      fi
      ssh -O exit "$host" 2>/dev/null || true
    }

    do_off() {
      local host disp
      host=$(target "''${1:-}")
      disp=$(display "$host")
      if [ -n "$disp" ]; then
        # shellcheck disable=SC2029
        ssh "$host" "vncserver -kill :$disp"
      else
        echo "no desktop running on $host"
      fi
      ssh -O exit "$host" 2>/dev/null || true
    }

    case "''${1:-}" in
      -h|--help|help) print_help ;;
      user) printf '%s' "''${2:?username}" > "$user_file"; echo "user set to $2" ;;
      scale) printf '%s' "''${2:?factor}" > "$conf/scale"; echo "scale set to $2 (applies on next connect)" ;;
      off|kill|stop) do_off "''${2:-}" ;;
      *) do_open "''${1:-}" ;;
    esac
  '';
}

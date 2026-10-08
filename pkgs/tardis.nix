# tardis — one command for the AIC remote desktop: ensures a VNC desktop is
# running on a Tardis machine, opens the SSH tunnel in the background, starts
# the viewer, and tears the tunnel down when the viewer closes. Needs the VPN
# off campus (`ethvpn`). Uses the `tardis-*` block in ~/.ssh/config, so one
# login covers all SSH calls.
{ writeShellApplication
, openssh
, tigervnc
}:
writeShellApplication {
  name = "tardis";
  runtimeInputs = [ openssh tigervnc ];
  text = ''
    conf=''${XDG_CONFIG_HOME:-$HOME/.config}/tardis
    mkdir -p "$conf"

    print_help() {
      cat <<'EOF'
    tardis — AIC remote desktop on the Tardis lab machines

    Usage:
      tardis [MACHINE]       open the desktop (MACHINE e.g. b11; default: last used, else b11)
      tardis off [MACHINE]   stop the desktop on the machine
      tardis user NAME       set the AIC course username
      tardis -h              this help

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
      m=''${m:-b11}
      m=''${m#tardis-}
      printf '%s' "$m" > "$host_file"
      echo "$(get_user)@tardis-$m"
    }

    # first display number of a running desktop, empty if none
    display() {
      ssh "$1" 'vncserver -list 2>/dev/null' | grep -oE '^:[0-9]+' | head -1 | tr -d :
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
        ssh -t "$host" vncserver
        disp=$(display "$host")
      fi
      if [ -z "$disp" ]; then
        echo "no VNC desktop found on $host" >&2
        ssh -O exit "$host" 2>/dev/null || true
        return 1
      fi
      port=$((5900 + disp))
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
      off|kill|stop) do_off "''${2:-}" ;;
      *) do_open "''${1:-}" ;;
    esac
  '';
}

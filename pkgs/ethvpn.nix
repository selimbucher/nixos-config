# ethvpn — ETH VPN (sslvpn.ethz.ch) without a terminal to keep alive.
# Credentials live in the GNOME keyring; openconnect detaches after
# connecting. The ETH OTP is generated locally when a TOTP secret is stored.
{ writeShellApplication
, openconnect
, libsecret
, libnotify
, iproute2
}:
writeShellApplication {
  name = "ethvpn";
  runtimeInputs = [ openconnect libsecret libnotify iproute2 ];
  text = ''
    svc=eth-vpn
    iface=ethvpn
    pidfile=/run/eth-vpn.pid
    gateway=sslvpn.ethz.ch
    runtime=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}

    print_help() {
      cat <<'EOF'
    ethvpn — ETH VPN

    Usage:
      ethvpn            connect, then return to the shell
      ethvpn off        disconnect
      ethvpn status     show state and address
      ethvpn setup      store login, network password and (optionally) the TOTP secret
      ethvpn -h         this help

    Setup:
      ethvpn setup
        login:           nethz login, without @...
        realm:           student or staff
        password:        ETH *network* password (Netzwerkpasswort), not the main one
        TOTP secret:     the base32 secret behind the QR code when enrolling the
                         ETH authenticator app (re-enrol at https://password.ethz.ch
                         to see it). Leave empty to type the OTP on every connect.
    EOF
    }

    get() { secret-tool lookup service "$svc" key "$1" 2>/dev/null || true; }
    put() { secret-tool store --label="ETH VPN $1" service "$svc" key "$1"; }

    up() { ip link show "$iface" >/dev/null 2>&1; }

    do_status() {
      if up; then
        echo "connected: $(ip -4 -o addr show "$iface" | awk '{print $4}')"
      else
        echo "disconnected"
        return 1
      fi
    }

    do_setup() {
      local login realm pass totp
      read -rp 'nethz login: ' login
      read -rp 'realm (student/staff) [student]: ' realm
      realm=''${realm:-student}
      read -rsp 'ETH network password: ' pass; echo
      read -rp 'TOTP secret (optional): ' totp
      printf '%s' "$login@$realm-net.ethz.ch" | put user
      printf '%s' "$pass" | put password
      totp=$(printf '%s' "$totp" | tr -d ' -' | tr '[:lower:]' '[:upper:]')
      if [ -n "$totp" ]; then
        printf '%s' "$totp" | put totp
      else
        secret-tool clear service "$svc" key totp 2>/dev/null || true
      fi
      echo "stored for $login@$realm-net.ethz.ch"
    }

    do_connect() {
      local user pass totp group cfg otp=""
      if up; then do_status; return 0; fi
      user=$(get user); pass=$(get password); totp=$(get totp)
      if [ -z "$user" ] || [ -z "$pass" ]; then
        echo "no credentials stored, run: ethvpn setup" >&2
        return 1
      fi
      group=''${user#*@}; group=''${group%%.*}

      cfg=$runtime/eth-vpn.conf
      ( umask 077; cat > "$cfg" <<EOF
    user=$user
    authgroup=$group
    useragent=AnyConnect
    no-external-auth
    passwd-on-stdin
    interface=$iface
    pid-file=$pidfile
    background
    syslog
    EOF
      )
      if [ -n "$totp" ]; then
        printf 'token-mode=totp\ntoken-secret=base32:%s\n' "$totp" >> "$cfg"
      else
        read -rsp 'ETH OTP: ' otp </dev/tty; echo
      fi

      if printf '%s\n%s\n' "$pass" "$otp" | sudo openconnect --config="$cfg" "$gateway"; then
        rm -f "$cfg"
        notify-send -a ethvpn 'ETH VPN' 'connected'
        do_status
      else
        rm -f "$cfg"
        echo "connect failed (journalctl -t openconnect)" >&2
        return 1
      fi
    }

    do_off() {
      if ! up; then echo "not connected"; return 0; fi
      sudo sh -c "kill -INT \$(cat $pidfile 2>/dev/null) 2>/dev/null || pkill -INT -x openconnect"
      for _ in $(seq 1 50); do up || break; sleep 0.1; done
      notify-send -a ethvpn 'ETH VPN' 'disconnected'
      do_status || true
    }

    case "''${1:-}" in
      "")           do_connect ;;
      off|down|stop) do_off ;;
      status)       do_status ;;
      setup)        do_setup ;;
      -h|--help|help) print_help ;;
      *) echo "unknown command: $1" >&2; print_help >&2; exit 2 ;;
    esac
  '';
}

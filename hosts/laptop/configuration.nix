{ pkgs, ... }:

{
  imports = [
    ../../options.nix
    ./hardware-configuration.nix
    ../../common.nix
  ];

  networking.hostName = "laptop";

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    # Passwords only from the home LAN (rsync); keys everywhere else
    extraConfig = ''
      Match Address 192.168.88.0/24
        PasswordAuthentication yes
    '';
  };
  users.users.selim.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK2hjST+3bGWZhN7UOZshtJRFEr2hRHUUUh69W8tnana selim@desktop"
  ];
  networking.hosts."100.64.0.1" = [ "desktop" ];

  # Builds the Pi's SD image (~/.pi). Its vendor kernel comes from
  # nixos-raspberrypi's cache: `nix build --extra-substituters <url>`.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  nix.settings.extra-trusted-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [
    "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
  ];

  # amdgpu must load in initrd: Plymouth ignores the firmware's simpledrm
  # device until a real GPU driver appears, so the LUKS prompt (luks.nix)
  # would otherwise go to a splash that is not drawn yet. VA-API needs
  # nothing here, Mesa ships radeonsi's VA driver itself.
  boot.initrd.kernelModules = [ "amdgpu" ];

  deviceConfig = {
    monitor = [
      # The panel's EDID claims HDR, so Hyprland's auto-HDR switched it to HDR
      # for fullscreen video: a modeset (black for a second), then a washed-out
      # picture. Marked SDR, it stays in sRGB.
      { output = "eDP-1";    mode = "2880x1920@120"; position = "0x0";        scale = "2"; bitdepth = 10; supports_hdr = -1; }
      # the Acer, whichever port it is on (it came up as DP-1 and DP-2 on
      # different boots). Native 2560x1440; a 3840x2160@30 entry gave "input
      # not supported" on a cold boot. Over HDMI the closest refresh is used.
      # scale 1 for the apps' room; kiwi sizes itself for it (1.25)
      { output = "desc:Acer Technologies KG271U TATEE0028511"; mode = "2560x1440@70"; position = "-560x-1440"; scale = "1"; }
    ];
    # WhiteSur renders header bars and sidebars at 96% opacity; without blur
    # behind them that reads as a muddy wallpaper tint rather than vibrancy.
    blur = true;
    shadow = true;
    scale = 2.0;
    jackBufferSize = 128;
    # LUKS2 root (nvme0n1p2), opened by its passphrase on the login-style
    # splash; that prompt is the login (luks.nix logs straight in after
    # it). No YubiKey: lock screen and TTY take the account password.
    luksRoot = "ece86617-82dd-4178-9e4f-97d9495e003f";
    battery = true;
    # the desktop's MX Master 3 at 1000 DPI with acceleration off, scaled for
    # the Zenbook's panel (127.7 logical ppi at scale 2 vs 108.8 ppi on its 27" 1440p)
    mouseDpi = 1200;
    # true = patched wine + yabridge like the desktop (~1h local build per nixpkgs bump)
    wineFork = true;
  };
}
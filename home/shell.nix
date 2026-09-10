{ inputs, config, pkgs, hostName, ... }:
{
  home.shellAliases = {
    rebuild = "sudo SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild switch --flake ${config.home.homeDirectory}/.nixos#${hostName}";
    rb      = "sudo SSH_AUTH_SOCK=$SSH_AUTH_SOCK nixos-rebuild switch --flake ${config.home.homeDirectory}/.nixos#${hostName}";
    nu      = "nix flake update";
    update  = "nix flake update --flake ${config.home.homeDirectory}/.nixos";
    u       = "nix flake update --flake ${config.home.homeDirectory}/.nixos";
    c       = "cd ~/Documents/Code";
    gp      = "git pull";
    gs      = "git status";
    ga      = "git add .";
    gc      = "git commit";
    gcl     = "git clone";
    gpsh    = "git push";
    rebuild-hetzner = "nixos-rebuild switch --flake ${config.home.homeDirectory}/.hetzner --target-host hetzner";
    rbh             = "nixos-rebuild switch --flake ${config.home.homeDirectory}/.hetzner --target-host hetzner";
    update-hetzner  = "nix flake update --flake ${config.home.homeDirectory}/.hetzner";
    uh              = "nix flake update --flake ${config.home.homeDirectory}/.hetzner";
  };

  # fired into a running REAPER by bs()/sr() via `reaper -nonewinst`
  home.file.".config/REAPER/Scripts/pw-audio-reset.lua".text = ''
    reaper.Audio_Quit()
    reaper.Audio_Init()
  '';

  # `trk`: toggle master FX with >=256 samples PDC (lookahead limiter, soothe) for
  # low-latency tracking; remembers which ones it disabled in project ext state.
  home.file.".config/REAPER/Scripts/pw-tracking-mode.lua".source =
    ../pkgs/reaper-tools/pw-tracking-mode.lua;

  home.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "qt6ct";
    LD_LIBRARY_PATH = "${pkgs.yabridge}/lib:$LD_LIBRARY_PATH";
  };

  programs.ssh = {
    enable = true;
    matchBlocks."hetzner" = {
      hostname = inputs.secrets.hetznerIp;
      user = "root";
      extraOptions = {
        SetEnv = "TERM=xterm-256color";
      };
    };
};

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      PS1='❯ '
      unsetopt PROMPT_CR PROMPT_SP
      precmd() { printf '\r\e[K' }
      # pipewire quantum/rate overrides (live, affects pw-jack REAPER); no arg = release.
      # Bridged lookahead plugins (Pro-L 2 etc.) wedge on a live buffer-size change, so
      # if a real REAPER is running, re-init its audio device afterwards — same
      # renegotiation as a restart, without losing the session.
      _reaper_audio_reset() {
        for p in $(pgrep -x reaper; pgrep -x .reaper-wrapped); do
          if readlink -f /proc/$p/exe 2>/dev/null | grep -q "/REAPER/"; then
            reaper -nonewinst ~/.config/REAPER/Scripts/pw-audio-reset.lua >/dev/null 2>&1
            return
          fi
        done
      }
      bs() { pw-metadata -n settings 0 clock.force-quantum "''${1:-0}" >/dev/null && _reaper_audio_reset }
      sr() { pw-metadata -n settings 0 clock.force-rate "''${1:-0}" >/dev/null && _reaper_audio_reset }
      trk() { reaper -nonewinst ~/.config/REAPER/Scripts/pw-tracking-mode.lua >/dev/null 2>&1 }
    '';
    dotDir = "${config.xdg.configHome}/zsh";
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
}
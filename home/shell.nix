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
    ssh-hetzner     = "ssh root@${inputs.secrets.hetznerIp}";
    rebuild-hetzner = "nixos-rebuild switch --flake ${config.home.homeDirectory}/.hetzner --target-host root@${inputs.secrets.hetznerIp}";
    rbh             = "nixos-rebuild switch --flake ${config.home.homeDirectory}/.hetzner --target-host root@${inputs.secrets.hetznerIp}";
  };

  home.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "qt6ct";
    LD_LIBRARY_PATH = "${pkgs.yabridge}/lib:$LD_LIBRARY_PATH";
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      PS1='❯ '
      unsetopt PROMPT_CR PROMPT_SP
      precmd() { printf '\r\e[K' }
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

{ pkgs, ... }:
let
  src = ../../pkgs/emacs;
  # the traffic lights' hover glyphs, shared with hyprbars and the GTK themes
  glyphs = pkgs.callPackage ../../pkgs/titlebutton-glyphs.nix { };
in
{
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk;
    extraPackages = epkgs: with epkgs; [
      treemacs
      vterm
      treesit-auto
      nix-ts-mode
      markdown-mode
      treesit-grammars.with-all-grammars
      vertico
      vertico-posframe
      orderless
      marginalia
      consult
    ];
  };

  # C-S-f searches the project with it
  home.packages = [ pkgs.ripgrep ];

  xdg.configFile = {
    "emacs/early-init.el".source = "${src}/early-init.el";
    "emacs/init.el".source = "${src}/init.el";
    "emacs/look.el".source = "${src}/look.el";
    "emacs/explorer.el".source = "${src}/explorer.el";
    "emacs/popups.el".source = "${src}/popups.el";
    "emacs/glyphs".source = glyphs;
  };
}

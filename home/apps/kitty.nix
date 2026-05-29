{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    settings = {
      # General behavior
      confirm_os_window_close = 0;
      
      # Fonts
      font_family      = "JetBrains Mono";
      bold_font        = "auto";
      italic_font      = "auto";
      bold_italic_font = "auto";
      font_size        = "11.0";

      # Background and Opacity
      background_opacity = "1.0";
      dynamic_background_opacity = "yes";
      window_padding_width = 10;

      # Colors (Your custom theme)
      background = "#000000";
      foreground = "#ffffff";
      cursor = "#ffffff";
      selection_background = "#b4d5ff";
      selection_foreground = "#000000";

      # Terminal Colors (0-15)
      color0 = "#868686";
      color8 = "#545454";
      color1 = "#ff6600";
      color9 = "#ff0000";
      color2 = "#ccff04";
      color10 = "#00ff00";
      color3 = "#ffcc00";
      color11 = "#ffff00";
      color4 = "#44b3cc";
      color12 = "#0000ff";
      color5 = "#9933cc";
      color13 = "#ff00ff";
      color6 = "#44b3cc";
      color14 = "#00ffff";
      color7 = "#f4f4f4";
      color15 = "#e5e5e5";
    };
    
    # This handles the custom include line from your original config
    extraConfig = ''
      include ./theme.conf
    '';
  };
}
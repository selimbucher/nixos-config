{ config, pkgs, ... }:

{
  # Ensure Hyprlock program is enabled
  programs.hyprlock.enable = true;

  programs.hyprlock.settings = {
    general = {
      hide_cursor = false;
    };

    animations = {
      enabled = true;
      bezier = [
        "linear, 1, 1, 0, 0"
      ];
      animation = [
        "fadeIn, 1, 5, linear"
        "fadeOut, 1, 5, linear"
        "inputFieldDots, 1, 2, linear"
      ];
    };

    background = [{
      monitor = "";
      path = "screenshot";
      blur_passes = 3;
      noise = 0.05;
      brightness=0.75;
      contrast=1.2;
    }];

    "input-field" = [{
      monitor = "";
      size = "70%, 14%";
      outline_thickness = 0;
      inner_color = "rgba(0, 0, 0, 0.0)";

      # --- Add these lines to force transparency in all states ---
      check_color = "rgba(0, 0, 0, 0.0)";
      fail_color = "rgba(0, 0, 0, 0.0)";    # This overrides your orange/pink gradient
      clear_color = "rgba(0, 0, 0, 0.0)";
      capslock_color = "rgba(0, 0, 0, 0.0)";
      # ---------------------------------------------------------

      font_color = "rgb(255, 255, 255)";
      fade_on_empty = false;
      rounding = 50;

      font_family = "Rubik";
      placeholder_text = "";
      fail_text = "";

      dots_text_format = "*";
      dots_size = 1;
      dots_spacing = 0.15;

      position = "0.5%, -5%";
      halign = "center";
      valign = "center";
    }];

    label = [
      # TIME
      {
        monitor = "";
        # Since we removed the $font variable, we hardcode the font name
        text = "$TIME";
        font_family = "Quicksand"; 
        font_size = 140;
        position = "0, -140";
        halign = "center";
        valign = "top";
      }
      # DATE
      {
        monitor = "";
        text = "cmd[update:60000] date +\"%A, %d %B %Y\"";
        font_size = 25;
        font_family = "Quicksand"; # Hardcoded font name
        
        position = "-35, 50";
        halign = "right";
        valign = "bottom";
      }
    ];
  };
}
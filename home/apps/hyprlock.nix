{ config, pkgs, ... }:

{
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
      size = "20%, 5%";
      outline_thickness = 0;
      inner_color = "rgba(255, 255, 255, 0.1)";
      check_color = "rgba(0, 0, 0, 0.0)";
      fail_color = "rgba(0, 0, 0, 0.0)";
      clear_color = "rgba(0, 0, 0, 0.0)";
      capslock_color = "rgba(255, 255, 255, 0.1)";

      font_color = "rgb(255, 255, 255)";
      fade_on_empty = true;
      rounding = 100;

      font_family = "Quicksand";
      placeholder_text = "Enter Password";
      fail_text = "Enter Password";

      dots_size = 0.3;
      dots_spacing = 0.35;

      position = "0.5%, -2%";
      halign = "center";
      valign = "center";
    }];

    label = [
      # TIME
      {
        monitor = "";
        text = "$TIME";
        font_family = "Quicksand ExtraBold"; 
        font_size = 148;
        position = "0, -11%";
        halign = "center";
        valign = "top";
      }
      # DATE
      {
        monitor = "";
        text = "cmd[update:60000] date +\"%A, %d %B\"";
        font_size = 32;
        font_family = "Quicksand SemiBold";
        position = "0, -10%";
        halign = "center";
        valign = "top";
      }
    ];
  };
}
{ config, lib, pkgs, osConfig, ... }:

let
  # deviceConfig.passwordLock = false (hosts/laptop/yubikey.nix): key only,
  # so no input field at all, just the instruction where the pill would be.
  # With a password the pill stays and switches to the key instruction while
  # PAM waits for the touch (check_text shows once the buffer is submitted).
  passwordLock = osConfig.deviceConfig.passwordLock;
  keyPrompt = "Insert security key to unlock";
in
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

    "input-field" = lib.optional passwordLock {
      monitor = "";
      size = "20%, 5%";
      outline_thickness = 0;
      inner_color = "rgba(255, 255, 255, 0.1)";
      # with no outline hyprlock paints check_color as the field itself while
      # PAM runs (the key wait); keep it the field colour, the text stays white
      check_color = "rgba(255, 255, 255, 0.1)";
      fail_color = "rgba(0, 0, 0, 0.0)";
      clear_color = "rgba(0, 0, 0, 0.0)";
      capslock_color = "rgba(255, 255, 255, 0.1)";

      font_color = "rgb(255, 255, 255)";
      fade_on_empty = true;
      rounding = 100;

      font_family = "Quicksand";
      placeholder_text = "Enter Password";
      fail_text = "Enter Password";
      check_text = keyPrompt;

      dots_size = 0.3;
      dots_spacing = 0.35;

      position = "0.5%, -2%";
      halign = "center";
      valign = "center";
    };

    label = lib.optional (!passwordLock) {
      monitor = "";
      text = keyPrompt;
      font_family = "Quicksand Medium";
      font_size = 22;
      color = "rgb(255, 255, 255)";
      position = "0.5%, -2%";
      halign = "center";
      valign = "center";
    } ++ [
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
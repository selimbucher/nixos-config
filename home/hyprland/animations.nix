{ inputs, lib, pkgs, osConfig, ... }:

let
  # hyprlang `bezier = name,x1,y1,x2,y2` -> hl.curve(name, { type = "bezier", points = ... })
  bezier = name: x1: y1: x2: y2: {
    _args = [ name { type = "bezier"; points = [ [ x1 y1 ] [ x2 y2 ] ]; } ];
  };

  # hyprlang `animation = leaf, on/off, speed, curve[, style]`
  anim = leaf: speed: curve: { inherit leaf speed; enabled = true; bezier = curve; };
  animStyled = leaf: speed: curve: style: (anim leaf speed curve) // { inherit style; };
in
{
  wayland.windowManager.hyprland.settings = {
    config.animations.enabled = true;

    # home-manager sorts `curve` ahead of the other hl.* calls (it is in
    # importantPrefixes), so every animation below can name one safely.
    curve = [
      (bezier "easeOutQuint" 0.23 1.0 0.32 1.0)
      (bezier "easeInOutCubic" 0.65 0.05 0.36 1.0)
      (bezier "linear" 0.0 0.0 1.0 1.0)
      (bezier "almostLinear" 0.5 0.5 0.75 1.0)
      (bezier "quick" 0.15 0.0 0.1 1.0)
    ];

    animation = [
      (anim "global" 10 "default")
      (anim "border" 1 "almostLinear")
      (anim "windows" 4.79 "easeOutQuint")
      (animStyled "windowsIn" 4.1 "easeOutQuint" "popin 87%")
      (animStyled "windowsOut" 1.49 "linear" "popin 87%")
      (anim "fadeIn" 1.73 "almostLinear")
      (anim "fadeOut" 1.46 "almostLinear")
      (anim "fade" 3.03 "quick")
      (anim "layers" 3.81 "easeOutQuint")
      (animStyled "layersIn" 4 "easeOutQuint" "fade")
      (animStyled "layersOut" 1.5 "linear" "fade")
      (anim "fadeLayersIn" 1.79 "almostLinear")
      (anim "fadeLayersOut" 1.39 "almostLinear")
      (animStyled "workspaces" 6 "easeOutQuint" "slide")
      (animStyled "workspacesIn" 5 "easeOutQuint" "slidefade")
      (animStyled "workspacesOut" 4 "easeInOutCubic" "slidefade")
    ];
  };
}

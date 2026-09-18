# Floating windows open where the app's window was last left, remembered per
# app across restarts, the way apps on macOS and Windows restore their own
# windows. Wayland apps may not position their own windows, so without this
# Hyprland centres every window at the app's default size each time. See the
# header of main.cpp.
{ lib, mkHyprlandPlugin }:

mkHyprlandPlugin {
  pluginName = "window-memory";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = ./main.cpp;
  };

  buildPhase = ''
    runHook preBuild
    $CXX -shared -fPIC -std=c++23 -O2 $(pkg-config --cflags hyprland) main.cpp -o libwindow-memory.so
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 libwindow-memory.so $out/lib/libwindow-memory.so
    runHook postInstall
  '';

  meta = {
    description = "Hyprland plugin: floating windows open where the app's window was last left";
    platforms = lib.platforms.linux;
  };
}

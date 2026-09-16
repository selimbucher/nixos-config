# Makes the minimize button in client-side decorations actually do something.
#
# Hyprland has no minimize concept. The request does arrive — xdg_toplevel's
# set_minimized lands in XDGShell.cpp and is carried up as
# SBackendStateRequest.minimized — but CWindow::onUpdateState forwards only
# fullscreen/maximized and drops it, so nothing reaches a dispatcher, the IPC
# socket, or hl.on() (whose event list has no minimize). The GTK traffic light
# is therefore a dead button, and some toolkits freeze waiting for a reply.
#
# This plugin listens to the toplevel's stateChanged signal from inside the
# compositor, reads requestsMinimize, and runs a configurable command — no
# patched Hyprland needed. It also answers XWayland clients with
# setMinimized(false) so they don't hang.
#
# Configured in home/hyprland/hyprland.nix to move the window to
# special:minimized, which is where kiwi-shell's dock already looks for it.
{
  lib,
  mkHyprlandPlugin,
  fetchFromGitHub,
}:

mkHyprlandPlugin (finalAttrs: {
  pluginName = "csd-minimize";
  version = "0-unstable-2026-08-04";

  src = fetchFromGitHub {
    owner = "ar-Raqmi";
    repo = "hyprland-csd-minimize";
    rev = "641b2765a778b97caf362b194f46cd81c4010b37";
    hash = "sha256-Y+KJ95bEyMNUmAZ6eM844e+WGPnqrru2jc+YkNhBQPI=";
  };

  # Without this the plugin is inert for GTK apps: Hyprland only advertises
  # FULLSCREEN and MAXIMIZE in xdg_toplevel.wm_capabilities (XDGShell.cpp, the
  # array around line 165), so libadwaita greys the minimize button out and
  # never sends set_minimized at all. The patch re-sends the capability array
  # with MINIMIZE included, per toplevel, from inside the plugin -- which is why
  # it needs `#define private public` to reach m_resource, the same trick
  # hyprbars uses for InputManager.
  patches = [ ./csd-minimize-advertise-minimize.patch ];

  # The upstream default sends the window to workspace "special"; kiwi-shell's
  # dock watches "special:minimized", which is also where the hyprbars minimize
  # button puts it. Patching the default instead of setting
  # plugin:csd-minimize:command from hyprland.lua avoids an ordering problem:
  # plugins are dlopen()ed only after the lua config chunk has run, so on the
  # first pass the config key does not exist yet and Hyprland records a config
  # error (the red overlay) even though a pcall keeps the file running.
  postPatch = ''
    substituteInPlace main.cpp \
      --replace-fail 'workspace = \"special\"' 'workspace = \"special:minimized\"'
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    mv csd-minimize.so $out/lib/libcsd-minimize.so

    runHook postInstall
  '';

  meta = {
    description = "Configurable client-side-decoration minimize button handler for Hyprland";
    homepage = "https://github.com/ar-Raqmi/hyprland-csd-minimize";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})

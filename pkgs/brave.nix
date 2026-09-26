# Brave with the prefs the traffic lights depend on pinned in every profile
# (home/theme.nix styles the GTK frame Chromium draws into its tab strip):
# - extensions.theme.system_theme = 1 (Appearance -> Theme -> GTK). Chromium
#   defaults it by desktop environment (ui/linux/linux_ui_factory.cc,
#   GetDefaultSystemTheme): GNOME/Xfce/Cinnamon get GTK, KDE/LXQt Qt, and
#   anything it doesn't know, Hyprland included, Classic.
# - browser.custom_chrome_frame = true ("Use system title bar and borders"
#   off), so the buttons are Chromium's own and not a hyprbars bar.
# No policy or flag sets either, so the wrapper writes them into each
# profile's Preferences before a cold start; a running Brave rewrites that
# file on exit, so it is left alone while one holds the profile. Neither pref
# is MAC-tracked (chrome_pref_service_factory.cc), so the edit sticks.
{
  lib,
  writeShellScript,
  jq,
  brave,
}:

let
  pinPrefs = writeShellScript "brave-pin-prefs" ''
    dir=''${XDG_CONFIG_HOME:-$HOME/.config}/BraveSoftware/Brave-Browser
    # SingletonLock -> "<host>-<pid>" while a Brave holds the profile
    lock=$(readlink "$dir/SingletonLock" 2>/dev/null) &&
      kill -0 "''${lock##*-}" 2>/dev/null && exit 0

    want='.extensions.theme.system_theme = 1 | .browser.custom_chrome_frame = true'
    for prefs in "$dir"/*/Preferences; do
      [ -f "$prefs" ] || continue
      ${jq}/bin/jq -e '.extensions.theme.system_theme == 1 and .browser.custom_chrome_frame == true' 2>/dev/null \
        "$prefs" >/dev/null && continue
      tmp=$(mktemp "$prefs.XXXXXX") || continue
      if ${jq}/bin/jq -c "$want" "$prefs" >"$tmp"; then
        mv "$tmp" "$prefs"
      else
        rm -f "$tmp"
      fi
    done
  '';
in
brave.overrideAttrs (old: {
  # the wrapper runs under bash -e: a failure here must not stop Brave starting
  preFixup = old.preFixup + ''
    gappsWrapperArgs+=(--run ${lib.escapeShellArg "${pinPrefs} || true"})
  '';
})

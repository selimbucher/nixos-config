# Thunderbird add-on: a unified toolbar button that opens Settings. The unified
# toolbar has no built-in Settings item, and only an experiment API can reach
# openPreferencesTab(). Unsigned is fine: Thunderbird doesn't require signing
# and allows experiments by default. Installed by home/apps/thunderbird.nix.
{ runCommand, zip }:
runCommand "thunderbird-settings-button.xpi" { nativeBuildInputs = [ zip ]; } ''
  cd ${./src}
  zip -qrX "$TMPDIR/addon.xpi" .
  mv "$TMPDIR/addon.xpi" "$out"
''

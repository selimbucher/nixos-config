# Thunderbird add-on behind mail-look.css: sender badges and short dates in the
# message list, logos in the message header, one search field, and the toolbar
# for each layout. The CSS itself ships through userChrome.css (see
# home/apps/thunderbird.nix) so it can be live-edited in the Developer Toolbox.
{ runCommand, zip }:
runCommand "thunderbird-mail-look.xpi" { nativeBuildInputs = [ zip ]; } ''
  cd ${./src}
  zip -qrX "$TMPDIR/addon.xpi" .
  mv "$TMPDIR/addon.xpi" "$out"
''

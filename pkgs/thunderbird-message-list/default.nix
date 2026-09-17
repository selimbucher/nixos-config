# Thunderbird add-on for the cards message list: sender logo/initials badges,
# time-only today and date-only otherwise, and row heights that follow
# message-list.css. The CSS itself ships through userChrome.css (see
# home/apps/thunderbird.nix) so it can be live-edited in the Developer Toolbox.
{ runCommand, zip }:
runCommand "thunderbird-message-list.xpi" { nativeBuildInputs = [ zip ]; } ''
  cd ${./src}
  zip -qrX "$TMPDIR/addon.xpi" .
  mv "$TMPDIR/addon.xpi" "$out"
''

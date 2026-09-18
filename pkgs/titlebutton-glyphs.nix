# The traffic-light hover glyphs as files, for every toolkit that loads them
# by path: GTK header bars (1x/2x PNGs, since GTK rasterises an SVG background
# at its intrinsic size and blurs on a 2x screen), hyprbars (the SVGs, loaded
# at the exact pixel size) and Thunderbird (the SVGs). Source: ./titlebutton-glyphs-svg.nix.
{
  lib,
  runCommand,
  writeText,
  librsvg,
}:

let
  svgs = import ./titlebutton-glyphs-svg.nix;
in
runCommand "titlebutton-glyphs" { nativeBuildInputs = [ librsvg ]; } ''
  mkdir -p $out
  ${lib.concatStrings (
    lib.mapAttrsToList (name: text: ''
      cp ${writeText "${name}.svg" text} $out/${name}.svg
      rsvg-convert -w 14 -h 14 $out/${name}.svg -o $out/${name}.png
      rsvg-convert -w 28 -h 28 $out/${name}.svg -o $out/${name}@2.png
    '') svgs
  )}
''

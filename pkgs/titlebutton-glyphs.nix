# The hover glyphs of the traffic lights, as three SVGs that both window-control
# families draw from, so a GTK header bar and a hyprbars bar show the very same
# × − and zoom arrows. Path data is WhiteSur's own hover artwork
# (other/firefox/common/titlebuttons/titlebutton-*-hover.svg): there the disc is
# 14px across, centred in a 16px canvas, and the glyph is black at 50% opacity.
# Cropping the viewBox to that disc makes each file exactly one 14px button.
{ runCommand, librsvg }:

let
  svg = body: ''
    <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="1 1 14 14">${body}</svg>
  '';
in
# GTK rasterises an SVG background at its intrinsic size, which blurs on a 2x
# screen, so 1x/2x PNGs are rendered from the same SVGs for -gtk-scaled().
# hyprbars loads the SVGs directly at the exact pixel size.
runCommand "titlebutton-glyphs" { nativeBuildInputs = [ librsvg ]; } ''
  mkdir -p $out
  cat > $out/close.svg <<'SVG'
  ${svg ''<path fill="#000" fill-opacity=".5" d="M5.169 5.091a1 1 0 0 0 0 1.414L6.583 7.92 5.169 9.334a1 1 0 0 0 0 1.414 1 1 0 0 0 1.414 0l1.414-1.414 1.414 1.414a1 1 0 0 0 1.414 0 1 1 0 0 0 0-1.414L9.411 7.92l1.414-1.415a1 1 0 0 0 0-1.414 1 1 0 0 0-1.414 0L7.997 6.505 6.583 5.091a1 1 0 0 0-1.414 0"/>''}
  SVG
  cat > $out/minimize.svg <<'SVG'
  ${svg ''<rect fill="#000" fill-opacity=".5" x="4" y="7" width="8" height="2" rx="1"/>''}
  SVG
  cat > $out/maximize.svg <<'SVG'
  ${svg ''<path fill="#000" fill-opacity=".5" d="m6.41 4.98 4.587 4.585V5.98c0-.415-.585-1-1-1zM4.998 6.392V9.98c0 .416.584 1 1 1h3.586z"/>''}
  SVG
  for name in close minimize maximize; do
    rsvg-convert -w 14 -h 14 $out/$name.svg -o $out/$name.png
    rsvg-convert -w 28 -h 28 $out/$name.svg -o $out/$name@2.png
  done
''

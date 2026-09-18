# SVG source of the traffic-light hover glyphs: WhiteSur's own hover artwork
# (other/firefox/common/titlebuttons/titlebutton-*-hover.svg). There the disc is
# 14px across, centred in a 16px canvas, and the glyph is black at 50% opacity;
# cropping the viewBox to the disc makes each one exactly one 14px button.
# Plain Nix so pages that inline them (Obsidian) need no build step.
let
  svg = body: ''<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="1 1 14 14">${body}</svg>'';
in
{
  close = svg ''<path fill="#000" fill-opacity=".5" d="M5.169 5.091a1 1 0 0 0 0 1.414L6.583 7.92 5.169 9.334a1 1 0 0 0 0 1.414 1 1 0 0 0 1.414 0l1.414-1.414 1.414 1.414a1 1 0 0 0 1.414 0 1 1 0 0 0 0-1.414L9.411 7.92l1.414-1.415a1 1 0 0 0 0-1.414 1 1 0 0 0-1.414 0L7.997 6.505 6.583 5.091a1 1 0 0 0-1.414 0"/>'';
  minimize = svg ''<rect fill="#000" fill-opacity=".5" x="4" y="7" width="8" height="2" rx="1"/>'';
  maximize = svg ''<path fill="#000" fill-opacity=".5" d="m6.41 4.98 4.587 4.585V5.98c0-.415-.585-1-1-1zM4.998 6.392V9.98c0 .416.584 1 1 1h3.586z"/>'';
}

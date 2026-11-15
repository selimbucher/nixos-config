#!/usr/bin/env bash
# gen.sh <wallpaper>: draws the theme's images at exact pixel sizes for each scale step, so the script never resizes them.
# Each shape is drawn 4x too large and reduced, which gives clean edges. Sizes are in units of a
# 1080-line display; a scale step of 175 means 1.75 device pixels per unit.
set -euo pipefail
cd "$(dirname "$0")"; rm -rf assets; mkdir assets
px() { python3 -c "print(max(1, round($1 * $2 / 100)))"; }
for step in 100 125 150 175 200 225 250; do
  # field: 280 x 44 units, fully rounded, faint fill, hairline border
  w=$(px 280 $step); h=$(px 44 $step); b=$(python3 -c "print(1 if $step < 200 else 2)")
  W=$((w * 4)); H=$((h * 4)); B=$((b * 4)); R=$((H / 2))
  magick -size ${W}x${H} xc:none \
    -fill "rgba(255,255,255,0.30)" -draw "roundrectangle 0,0 $((W - 1)),$((H - 1)) $R,$R" \
    \( -size ${W}x${H} xc:none -fill white -draw "roundrectangle $B,$B $((W - 1 - B)),$((H - 1 - B)) $((R - B)),$((R - B))" \) \
    -compose DstOut -composite \
    \( -size ${W}x${H} xc:none -fill "rgba(255,255,255,0.11)" -draw "roundrectangle $B,$B $((W - 1 - B)),$((H - 1 - B)) $((R - B)),$((R - B))" \) \
    -compose Over -composite -filter Lanczos -resize ${w}x${h}! PNG32:assets/field-$step.png
  # dot: 8 units
  d=$(px 8 $step); D=$((d * 8))
  magick -size ${D}x${D} xc:none -fill white -draw "circle $((D / 2)),$((D / 2)) $((D / 2)),1" -filter Lanczos -resize ${d}x${d}! PNG32:assets/dot-$step.png
  # spinner: 24 units, a faint ring with a bright quarter arc and round ends
  s=$(px 24 $step); S=$((s * 4)); T=$(python3 -c "print(max(6, round(2.2 * $step / 100 * 4)))"); M=$((T + 2))
  magick -size ${S}x${S} xc:none -fill none -strokewidth $T \
    -stroke "rgba(255,255,255,0.16)" -draw "circle $((S / 2)),$((S / 2)) $((S / 2)),$M" \
    -stroke white -draw "stroke-linecap round arc $M,$M $((S - M)),$((S - M)) 270,360" \
    -filter Lanczos -resize ${s}x${s}! PNG32:assets/spinner-$step.png
done
# background: the wallpaper blurred and darkened; small, because a blur survives any enlargement,
# with a little grain so the dark gradients do not band
magick "${1:?the wallpaper to blur}" -resize 1440x960^ -gravity center -extent 1440x960 -blur 0x22 -fill black -colorize 42% \
  \( +clone -fill "gray(50%)" -colorize 100 -attenuate 0.35 +noise Gaussian -colorspace Gray \) -compose Overlay -define compose:args=6 -composite \
  PNG24:assets/bg.png
ls assets | wc -l; du -sh assets | cut -f1; ls -l assets/bg.png assets/field-175.png | awk '{print $5, $NF}'; magick identify assets/field-175.png assets/dot-175.png assets/spinner-175.png | cut -c1-50

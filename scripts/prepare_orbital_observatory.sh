#!/usr/bin/env bash
set -euo pipefail

# Rebuild runtime wallpapers from the original two-panel provider image.
# Requires ImageMagick. Keep the source atlas outside the runtime asset bundle.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
atlas_path="${1:-$repo_root/.artifacts/orbital-observatory/source/orbital-earth-stars-day-night-atlas.png}"
asset_dir="$repo_root/assets/skins/orbital_observatory"
read -r atlas_width atlas_height < <(magick identify -format '%w %h\n' "$atlas_path")
if (( atlas_width % 2 != 0 || atlas_width != atlas_height )); then
  echo "Expected a square atlas with two equal portrait panels." >&2
  exit 1
fi
panel_width=$((atlas_width / 2))
if (( panel_width != 627 || atlas_height != 1254 )); then
  echo "This scene's aurora mask and Rive mesh require 627x1254 panels; update both for a different source size." >&2
  exit 1
fi
mkdir -p "$asset_dir"
for mode in light dark; do
  panel_offset=0
  if [[ "$mode" == dark ]]; then
    panel_offset=$panel_width
  fi
  magick "$atlas_path" -crop "${panel_width}x${atlas_height}+${panel_offset}+0" +repage \
    -strip -sampling-factor 4:4:4 -quality 93 "$asset_dir/wallpaper_${mode}.jpg"
done
# Extract the photographed aurora with a green-excess alpha mask. The mask
# excludes stars, blue atmosphere, cloud textures and warm city lights.
source_dir="$repo_root/.artifacts/orbital-observatory/source"
mkdir -p "$source_dir"
aurora_mask='max(0,min(1,min(u.g-1.1*u.r-0.004,u.g-0.65*u.b-0.005)*40))*max(0,min(1,(1254*(0.259+0.025*i/627+0.075*(i/627)^2)-12-j)/14))*max(0,min(1,(j-1254*(0.259+0.025*i/627+0.075*(i/627)^2)+180)/25))'
magick "$asset_dir/wallpaper_dark.jpg" -alpha on -channel A \
  -fx "$aurora_mask" +channel -channel RGB -evaluate Multiply 1.55 +channel -crop 627x380+0+100 +repage \
  -channel A -morphology Open Disk:1 -blur 0x1.2 +channel -strip "$source_dir/aurora-layer.png"
# Overlapping, cross-faded strips preserve photographic soft edges when moved.
for strip_index in 0 1 2; do
  strip_offset=$((strip_index * 180))
  strip_width=270
  if (( strip_index == 2 )); then strip_width=$((627 - strip_offset)); fi
  strip_mask='u.a'
  if (( strip_index > 0 )); then strip_mask="$strip_mask*min(1,i/90)"; fi
  if (( strip_index < 2 )); then strip_mask="$strip_mask*min(1,(w-i)/90)"; fi
  magick "$source_dir/aurora-layer.png" -crop "${strip_width}x380+${strip_offset}+0" +repage \
    -channel A -fx "$strip_mask" +channel -strip "$source_dir/aurora-layer-${strip_index}.png"
done
# Keep a complete static aurora while reserving headroom for the moving layer.
magick "$asset_dir/wallpaper_dark.jpg" -channel RGB \
  -fx "u*(1-0.65*($aurora_mask))" \
  +channel -strip -sampling-factor 4:4:4 -quality 93 "$asset_dir/wallpaper_dark.jpg"
# A soft photographic cloud veil for the daytime foreground. Feather every
# crop edge so it can drift over the stable planet without a visible rectangle.
cloud_mask='max(0,min(0.7,(min(u.r,min(u.g,u.b))-0.26)*1.8))*max(0,min(1,i/65))*max(0,min(1,(627-i)/65))*max(0,min(1,(j-500)/65))*max(0,min(1,(1000-j)/65))'
magick "$asset_dir/wallpaper_light.jpg" -alpha on -channel A \
  -fx "$cloud_mask" +channel -crop 627x500+0+500 +repage \
  -strip "$source_dir/cloud-layer.png"
magick identify "$asset_dir/wallpaper_light.jpg" "$asset_dir/wallpaper_dark.jpg"
shasum -a 256 "$atlas_path" "$asset_dir/wallpaper_light.jpg" "$asset_dir/wallpaper_dark.jpg"

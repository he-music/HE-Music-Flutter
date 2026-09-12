#!/usr/bin/env bash
set -euo pipefail

# iOS launch screens load native assets before Flutter starts.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_image="$repo_root/assets/icons/logo.png"
output_dir="$repo_root/ios/Runner/Assets.xcassets/LaunchImage.imageset"

if ! command -v sips >/dev/null 2>&1; then
  echo "错误：需要 macOS 自带的 sips 来生成 iOS 启动图。" >&2
  exit 1
fi

for scale in 1 2 3; do
  filename="LaunchImage.png"
  if [[ "$scale" != 1 ]]; then
    filename="LaunchImage@${scale}x.png"
  fi
  size=$((168 * scale))
  sips -z "$size" "$size" "$source_image" --out "$output_dir/$filename" >/dev/null
done

echo "已从 assets/icons/logo.png 同步 iOS 启动图（168pt，1x / 2x / 3x）。"

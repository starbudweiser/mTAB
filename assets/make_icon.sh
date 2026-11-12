#!/bin/zsh
# Génère assets/mTAB.icns (et le PNG 1024) à partir de make_icon.swift.
set -euo pipefail
cd "$(dirname "$0")"
swiftc -O make_icon.swift -o /tmp/mtab_make_icon && /tmp/mtab_make_icon mTAB_1024.png
rm -rf mTAB.iconset && mkdir mTAB.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s mTAB_1024.png --out mTAB.iconset/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) mTAB_1024.png --out mTAB.iconset/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns mTAB.iconset -o mTAB.icns && rm -rf mTAB.iconset

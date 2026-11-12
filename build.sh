#!/bin/zsh
# Compile mTAB une fois, puis produit : (1) la version de dev « mTAB Dev.app » (fr.stephan.mtab.dev, dans ./build)
# et (2) MA version locale « mTAB.app » (fr.stephan.mtab) dans ~/Applications/Applications Personnelles. Signature locale.
# Ni notarisation ni GitHub ici (voir release.sh, à écrire au moment de publier).
set -euo pipefail
cd "$(dirname "$0")"
SIGN="/Volumes/SKYRIM/TOOLS/MAC/_TOOLS/sign_app.sh"
mkdir -p build
swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos14 -F /System/Library/PrivateFrameworks -framework SkyLight -o build/mTAB Sources/*.swift

make_app() { # nom, bundle id, destination
  local APP="$3/$1.app"
  rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  cp build/mTAB "$APP/Contents/MacOS/mTAB"
  sed -e "s/__NAME__/$1/g" -e "s/__BUNDLEID__/$2/g" Resources/Info.plist > "$APP/Contents/Info.plist"
  cp assets/mTAB.icns "$APP/Contents/Resources/AppIcon.icns"
  for l in fr en es it; do mkdir -p "$APP/Contents/Resources/$l.lproj"; done
  if [ -x "$SIGN" ]; then "$SIGN" "$APP"; else codesign --force --deep -s - "$APP"; fi
  echo "OK : $APP"
}
make_app "mTAB Dev" "fr.stephan.mtab.dev" "$PWD/build"
if [ -z "${DEV_ONLY:-}" ]; then
  DEST="$HOME/Applications/Applications Personnelles"; mkdir -p "$DEST"
  make_app "mTAB" "fr.stephan.mtab" "$DEST"
fi

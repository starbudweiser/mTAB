#!/bin/zsh
# Publie une version : compile, notarise (Apple), zippe puis crée la release GitHub.
# Usage : ./release.sh [--notes "texte"]   — la version vient de CFBundleShortVersionString (Resources/Info.plist).
set -euo pipefail
cd "$(dirname "$0")"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
TAG="v$VERSION"
DIST="$PWD/dist"
NOTES=""
[ "${1:-}" = "--notes" ] && NOTES="${2:-}"
git diff --quiet && git diff --cached --quiet || { echo "Modifications non commitées : commiter avant la release." >&2; exit 1; }
! git rev-parse "$TAG" >/dev/null 2>&1 || { echo "La version $TAG existe déjà." >&2; exit 1; }
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "Pas synchronisé avec origin/main (push manquant)." >&2; exit 1; }

# Compilation et assemblage de mTAB.app (la signature Developer ID est posée par notarize_app.sh)
STAGE="$PWD/build/release"
rm -rf "$STAGE"; mkdir -p "$STAGE"
swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos14 -F /System/Library/PrivateFrameworks -framework SkyLight -o "$STAGE/mTAB.bin" Sources/*.swift
APP="$STAGE/mTAB.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv "$STAGE/mTAB.bin" "$APP/Contents/MacOS/mTAB"
sed -e "s/__NAME__/mTAB/g" -e "s/__BUNDLEID__/fr.stephan.mtab/g" Resources/Info.plist > "$APP/Contents/Info.plist"
cp assets/mTAB.icns "$APP/Contents/Resources/AppIcon.icns"
for l in fr en es it; do mkdir -p "$APP/Contents/Resources/$l.lproj"; done

rm -rf "$DIST"
DIST="$DIST" /Volumes/SKYRIM/TOOLS/MAC/_tools/notarize_app.sh "$APP"
ASSET="mTAB-$VERSION-macOS.zip"
mv "$DIST/mTAB.zip" "$DIST/$ASSET"
(cd "$DIST" && shasum -a 256 "$ASSET" > "$ASSET.sha256")

if [ -z "$NOTES" ]; then
  NOTES_FILE="$DIST/notes.md"
  cat > "$NOTES_FILE" <<NOTES_EOF
<!-- notes:fr -->
## $VERSION
- Fenêtre « À propos » : mention de la collection DESKTOP MAC TOOLKIT, licence MIT. README et licence ajoutés.
<!-- notes:en -->
## $VERSION
- About window now mentions the DESKTOP MAC TOOLKIT collection and the MIT license. README and license added.
<!-- notes:es -->
## $VERSION
- La ventana «Acerca de» menciona ahora la colección DESKTOP MAC TOOLKIT y la licencia MIT. README y licencia añadidos.
<!-- notes:it -->
## $VERSION
- La finestra «Informazioni» menziona ora la collezione DESKTOP MAC TOOLKIT e la licenza MIT. README e licenza aggiunti.
NOTES_EOF
  NOTES_ARGS=(--notes-file "$NOTES_FILE")
else NOTES_ARGS=(--notes "$NOTES"); fi

git tag "$TAG" && git push -q origin "$TAG"
gh release create "$TAG" "$DIST/$ASSET" "$DIST/$ASSET.sha256" --title "mTAB $VERSION" "${NOTES_ARGS[@]}"
echo "✓ https://github.com/starbudweiser/mTAB/releases/tag/$TAG"

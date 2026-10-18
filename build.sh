#!/bin/zsh
# Compile, assemble le bundle, signe (Developer ID) et installe dans /Applications.
# Usage : ./build.sh [--notarize] [--no-install]
set -euo pipefail
cd "$(dirname "$0")"

IDENTITY="${SIGN_IDENTITY:-F6E6688B309BBCACF52B3D5AB1C5061B68D0D0E7}" # Developer ID Application: IACHI Dimitri Fabien (G2, 2031)
APP=build/MacAppLauncher.app

swift build -c release
BIN=$(swift build -c release --show-bin-path)/MacAppLauncher

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacAppLauncher"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

if [[ " $* " == *" --notarize "* ]]; then
  # Profil créé une fois : xcrun notarytool store-credentials notary --apple-id … --team-id 5D6QHL72QC
  ditto -c -k --keepParent "$APP" build/MacAppLauncher.zip
  xcrun notarytool submit build/MacAppLauncher.zip --keychain-profile notary --wait --timeout 30m
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
fi

if [[ " $* " != *" --no-install "* ]]; then
  pkill -x MacAppLauncher && sleep 1 || true
  rm -rf /Applications/MacAppLauncher.app
  cp -R "$APP" /Applications/
  open /Applications/MacAppLauncher.app
  echo "Installé et lancé : /Applications/MacAppLauncher.app"
fi

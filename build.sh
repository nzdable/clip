#!/bin/sh
# Builds Clip.app (with the `clip` CLI inside), installs it, and zips it
# into build/Clip.zip for a GitHub release. Safe to re-run.
set -e
cd "$(dirname "$0")"
VERSION=1.1.0
APP=~/Applications/Clip.app

# Universal binary (Apple silicon + Intel) for macOS 13+, matching
# LSMinimumSystemVersion so newer-only APIs fail the build.
build() { # build <source.swift> <output>
  for a in arm64 x86_64; do
    swiftc -O -swift-version 5 -target $a-apple-macos13 "$1" -o "$2.$a"
  done
  lipo -create "$2.arm64" "$2.x86_64" -output "$2"
  rm "$2.arm64" "$2.x86_64"
}

mkdir -p build "$APP/Contents/MacOS" "$APP/Contents/Resources" ~/.local/bin
build clip.swift build/clip-cli
build ClipApp.swift build/Clip

# Terminal command. Clip.app uses its own copy, so this is optional.
cp build/clip-cli ~/.local/bin/clip.new && mv ~/.local/bin/clip.new ~/.local/bin/clip

# Older versions ran `clip watch` as a LaunchAgent. Clip.app runs it now,
# so remove the old one or two watchers would fight over the history file.
OLD=~/Library/LaunchAgents/com.nzdable.clip.plist
if [ -f "$OLD" ]; then
  launchctl bootout gui/$(id -u)/com.nzdable.clip 2>/dev/null || true
  rm "$OLD"
fi

# App bundle. The CLI is named clip-cli because Clip and clip would
# collide on macOS's case-insensitive disk.
cp build/Clip build/clip-cli "$APP/Contents/MacOS/"
[ -f snip.wav ] || python3 make_snip.py
cp snip.wav menubar.png "$APP/Contents/Resources/"

# App icon: icon.png -> Clip.icns (all sizes macOS wants).
SET=$(mktemp -d)/Clip.iconset; mkdir -p "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s icon.png --out "$SET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) icon.png --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$APP/Contents/Resources/Clip.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.nzdable.clip-app</string>
  <key>CFBundleName</key><string>Clip</string>
  <key>CFBundleExecutable</key><string>Clip</string>
  <key>CFBundleIconFile</key><string>Clip</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF

# Ad-hoc signature so macOS remembers the Screen Recording permission.
# Sign the inner CLI first, then the app that seals it.
codesign --force --sign - "$APP/Contents/MacOS/clip-cli"
codesign --force --sign - "$APP"

# Release zip (ditto keeps the signature intact).
rm -f build/Clip.zip
ditto -c -k --keepParent "$APP" build/Clip.zip

# Restart the app so the new build (and its watcher) is running.
pkill -x Clip 2>/dev/null && sleep 1 || true
open "$APP"
echo "Built $APP (v$VERSION) and build/Clip.zip"

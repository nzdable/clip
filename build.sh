#!/bin/sh
# Builds the `clip` CLI and Clip.app. Safe to re-run.
set -e
cd "$(dirname "$0")"

swiftc -O clip.swift -o clip.new && mv clip.new ~/.local/bin/clip

APP=~/Applications/Clip.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
[ -f snip.wav ] || python3 make_snip.py
cp snip.wav menubar.png "$APP/Contents/Resources/"

# App icon: icon.png -> Clip.icns (all sizes macOS wants).
SET=$(mktemp -d)/Clip.iconset; mkdir -p "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s icon.png --out "$SET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) icon.png --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$APP/Contents/Resources/Clip.icns"
swiftc -O -swift-version 5 ClipApp.swift -o "$APP/Contents/MacOS/Clip"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.nzdable.clip-app</string>
  <key>CFBundleName</key><string>Clip</string>
  <key>CFBundleExecutable</key><string>Clip</string>
  <key>CFBundleIconFile</key><string>Clip</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
# Ad-hoc signature so macOS remembers the Screen Recording permission.
codesign --force --sign - "$APP"
echo "Built $APP"

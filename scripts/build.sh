#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="build/Classic FM.app"
helper="build/Toggle Classic FM.app"
mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/Info.plist"
xcrun swiftc -swift-version 5 -O -target "$(uname -m)-apple-macos13.0" Sources/*.swift -o "$app/Contents/MacOS/ClassicFM"
codesign --force --sign - "$app"
osacompile -o "$helper" -e 'do shell script "/usr/bin/open -g -b com.robmarkcole.classic-fm-menubar classicfmradio://toggle"'
plutil -replace LSUIElement -bool YES "$helper/Contents/Info.plist"
codesign --force --sign - "$helper"

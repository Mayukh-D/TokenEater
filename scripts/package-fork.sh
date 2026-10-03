#!/usr/bin/env bash
# Builds the unofficial multi-account fork and packages it as a DMG for
# GitHub Releases. Ad-hoc signed (no Apple Developer account), so it is not
# notarized: users open it once via System Settings > Privacy & Security.
#
# Usage: scripts/package-fork.sh [version-label]   e.g. 6.0.0-multi.1
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL="${1:-$(grep -E '^\s*MARKETING_VERSION' project.yml | head -1 | sed -E 's/.*"(.*)".*/\1/')-multi}"
OUT="dist"
APP="build/Build/Products/Release/TokenEater.app"
DMG="$OUT/TokenEater-MultiAccount-$LABEL.dmg"

echo "== generate and build (Release, ad-hoc signed)"
xcodegen generate >/dev/null
xcodebuild -project TokenEater.xcodeproj -scheme TokenEaterApp -configuration Release \
  -derivedDataPath build DEVELOPMENT_TEAM="" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" \
  build 2>&1 | tail -1

echo "== verify"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = "com.mayukhd.tokeneater-multi" ] \
  || { echo "wrong bundle identifier: refusing to package the official identity"; exit 1; }
[ -f "$APP/Contents/Resources/LICENSE" ] || { echo "LICENSE missing from the app (MIT requires it)"; exit 1; }
codesign --verify --deep --strict "$APP"
codesign -d --entitlements - "$APP"/Contents/PlugIns/*.appex 2>/dev/null | grep -q app-sandbox \
  || { echo "widget lost its sandbox entitlement; WidgetKit would refuse it"; exit 1; }
echo "identity, licence, signatures and widget sandbox ok"

echo "== package"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/TokenEater.app"
ln -s /Applications "$STAGE/Applications"
cp LICENSE "$STAGE/LICENSE.txt"
cat > "$STAGE/READ ME FIRST.txt" <<'TXT'
TokenEater, multi-account fork (unofficial)

This is an unofficial build of TokenEater by Adrien Thevon
(github.com/AThevon/TokenEater, MIT licence, see LICENSE.txt), with support
for a second Claude Code account added by Mayukh Das
(github.com/Mayukh-D/TokenEater). It is not made or endorsed by the original
author or by Anthropic.

Install
1. Drag TokenEater.app onto the Applications folder.
   It replaces the official TokenEater if you have it; don't run both.
2. Open TokenEater. macOS will say it cannot check it for malware, because
   this build is not notarized by Apple. Choose Done, then open
   System Settings > Privacy & Security, scroll down, and click Open Anyway.
3. When asked, allow access to the "Claude Code-credentials" Keychain item.

Second account: log it in with its own config dir, e.g.
   CLAUDE_CONFIG_DIR=~/.claude-work claude
then see Settings > Providers > Other Claude accounts.

Updates: github.com/Mayukh-D/TokenEater/releases (the app does not
auto-update, so it can never be replaced by the official build).
TXT

mkdir -p "$OUT"
rm -f "$DMG"
hdiutil create -volname "TokenEater Multi-Account" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "== done: $DMG"

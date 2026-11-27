#!/usr/bin/env bash
# Build a Developer ID signed, notarized and stapled NailBiteMenu.dmg in dist/.
#
# One-time setup (needs your Apple account, so you run these yourself):
#   1. Xcode > Settings > Accounts > your team > Manage Certificates > + > Developer ID Application
#   2. xcrun notarytool store-credentials nailbite-notary --apple-id <you@example.com> --team-id 62S97QW86G
#      (asks for an app-specific password from account.apple.com > Sign-In and Security)
#
# Usage: scripts/release.sh            (profile name defaults to nailbite-notary)
#        NOTARY_PROFILE=other scripts/release.sh
set -euo pipefail

TEAM_ID="62S97QW86G"
PROFILE="${NOTARY_PROFILE:-nailbite-notary}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/release"
DIST="$ROOT/dist"
APP="$BUILD/dd/Build/Products/Release/NailBiteMenu.app"
DMG="$DIST/NailBiteMenu.dmg"

step() { printf '\n==> %s\n' "$*"; }

# Submit to Apple and stop unless the result is Accepted (notarytool exits 0 even when Invalid).
notarize() {
  local out id
  out=$(xcrun notarytool submit "$1" --keychain-profile "$PROFILE" --wait 2>&1) || true
  echo "$out"
  id=$(echo "$out" | awk '/^  id:/{print $2; exit}')
  if ! echo "$out" | grep -q "status: Accepted"; then
    echo "Notarization was not accepted. Apple's log:" >&2
    [ -n "$id" ] && xcrun notarytool log "$id" --keychain-profile "$PROFILE" >&2
    exit 1
  fi
}

step "Checking signing identity and notary credentials"
IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | grep "($TEAM_ID)" | head -1 | sed -E 's/.*"(.*)"/\1/' || true)
if [ -z "$IDENTITY" ]; then
  echo "No 'Developer ID Application' certificate for team $TEAM_ID in the keychain. See the setup steps at the top of this script." >&2
  exit 1
fi
xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 || {
  echo "No notary credentials stored as '$PROFILE'. See the setup steps at the top of this script." >&2
  exit 1
}
echo "Signing as: $IDENTITY"

step "Building Universal Release (arm64 + x86_64)"
rm -rf "$BUILD" && mkdir -p "$BUILD" "$DIST"
xcodebuild -project "$ROOT/app/NailBiteMenu.xcodeproj" -scheme NailBiteMenu -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$BUILD/dd" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS="--timestamp" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  clean build | grep -E "error:|BUILD (SUCCEEDED|FAILED)"

step "Verifying the app signature"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dvv "$APP" 2>&1 | grep -E "Authority=Developer ID Application|flags=.*runtime|Timestamp="
ENTITLEMENTS=$(codesign -d --entitlements - "$APP" 2>&1)
if echo "$ENTITLEMENTS" | grep -q "get-task-allow"; then
  echo "The app has the get-task-allow entitlement; Apple will reject it." >&2; exit 1
fi
for e in com.apple.security.app-sandbox com.apple.security.device.camera; do
  echo "$ENTITLEMENTS" | grep -q "$e" || { echo "Missing entitlement $e (camera or sandbox would break)." >&2; exit 1; }
done
echo "Entitlements: app-sandbox, device.camera"
lipo -archs "$APP/Contents/MacOS/NailBiteMenu"
VERSION=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)
echo "Version $VERSION"

step "Notarizing the app"
ditto -c -k --keepParent "$APP" "$BUILD/NailBiteMenu.zip"
notarize "$BUILD/NailBiteMenu.zip"
xcrun stapler staple "$APP"

step "Creating and signing the DMG"
STAGE="$BUILD/stage"
mkdir -p "$STAGE" && ditto "$APP" "$STAGE/NailBiteMenu.app" && ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "NailBiteMenu" -srcfolder "$STAGE" -ov -format UDZO -fs HFS+ "$DMG" >/dev/null
codesign --sign "$IDENTITY" --timestamp "$DMG"

step "Notarizing the DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"

step "Gatekeeper checks"
spctl --assess --type execute --verbose=2 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
xcrun stapler validate "$DMG"

step "Done"
ls -lh "$DMG"
shasum -a 256 "$DMG"
echo "NailBiteMenu $VERSION is ready to upload."

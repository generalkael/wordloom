#!/usr/bin/env bash
# Build Wordloom-<version>-<arch>.dmg from a release build.
#
# Needs: Rust, the Xcode command-line tools, and Qt 6 for macOS with
# macdeployqt on PATH (or QT_ROOT_DIR set, as jurplel/install-qt-action does).
# The DMG is for the architecture this Mac builds for (arm64 on Apple Silicon).
#
# Signing: by default the app is signed ad hoc, which Apple Silicon requires
# to run at all; people opening it get Gatekeeper's "unidentified developer"
# prompt. With a Developer ID, set MACOS_SIGN_IDENTITY (e.g. "Developer ID
# Application: Name (TEAMID)") to sign with the hardened runtime, and also
# MACOS_NOTARY_PROFILE (a `xcrun notarytool store-credentials` profile) to
# notarize and staple the DMG.
#
# Run from the repository root:  packaging/macos/build-dmg.sh
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
here="$root/packaging/macos"
work="$root/target/dmg"
app="$work/Wordloom.app"

version=$(sed -n 's/^version *= *"\([^"]*\)".*/\1/p' Cargo.toml | head -1)
arch=$(uname -m)

macdeployqt=$(command -v macdeployqt || true)
if [ -z "$macdeployqt" ] && [ -n "${QT_ROOT_DIR:-}" ]; then
    macdeployqt="$QT_ROOT_DIR/bin/macdeployqt"
fi
[ -x "$macdeployqt" ] || { echo "macdeployqt not found: put Qt's bin on PATH or set QT_ROOT_DIR." >&2; exit 1; }

# The oldest macOS Qt 6.10 supports; without this the build targets the
# runner's own macOS and the app won't open on anything older.
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
# Qt 6.10's qyieldcpu.h calls __yield() without including <arm_acle.h>,
# which newer Apple clang rejects.
if [ "$arch" = arm64 ]; then
    export CXXFLAGS="${CXXFLAGS:-} -include arm_acle.h"
fi

cargo build --release -p wordloom

rm -rf "$work"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp target/release/wordloom "$app/Contents/MacOS/Wordloom"
sed "s/@VERSION@/$version/g" "$here/Info.plist" > "$app/Contents/Info.plist"
cp "$here/Wordloom.icns" "$app/Contents/Resources/Wordloom.icns"

sign=()
if [ -n "${MACOS_SIGN_IDENTITY:-}" ]; then
    sign=(-codesign="$MACOS_SIGN_IDENTITY" -hardened-runtime -timestamp)
fi
# Copies Qt's frameworks, plugins and the QML modules our sources import
# into the bundle.
"$macdeployqt" "$app" -qmldir="$root/crates/wordloom-app/qml" -always-overwrite ${sign[@]+"${sign[@]}"}
if [ -z "${MACOS_SIGN_IDENTITY:-}" ]; then
    codesign --force --deep --sign - "$app"
fi
codesign --verify --deep --strict "$app"

# The disk image: the app next to a link to /Applications to drag it onto.
out="$root/Wordloom-$version-$arch.dmg"
mkdir -p "$work/image"
mv "$app" "$work/image/"
ln -s /Applications "$work/image/Applications"
rm -f "$out"
hdiutil create -volname "Wordloom $version" -srcfolder "$work/image" -fs HFS+ \
    -format UDZO -ov "$out"

if [ -n "${MACOS_SIGN_IDENTITY:-}" ]; then
    codesign --sign "$MACOS_SIGN_IDENTITY" --timestamp "$out"
    if [ -n "${MACOS_NOTARY_PROFILE:-}" ]; then
        xcrun notarytool submit "$out" --keychain-profile "$MACOS_NOTARY_PROFILE" --wait
        xcrun stapler staple "$out"
    fi
fi
echo "Built $out"

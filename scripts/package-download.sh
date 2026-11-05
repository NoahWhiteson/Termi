#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

app_path="$PWD/build/Termi.app"
dmg_path="$PWD/build/Termi-mac-arm64.dmg"
[[ -d "$app_path" ]] || { print -u2 "Build Termi.app with scripts/build.sh first."; exit 1; }
codesign --verify --deep --strict "$app_path"
[[ "$(lipo -archs "$app_path/Contents/MacOS/Termi")" == "arm64" ]] || {
    print -u2 "This download must be built for Apple silicon (arm64)."
    exit 1
}
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
minimum_macos="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$app_path/Contents/Info.plist")"
stage_dir="$(mktemp -d "${TMPDIR:-/tmp/}termi-dmg.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
ditto "$app_path" "$stage_dir/Termi.app"
ln -s /Applications "$stage_dir/Applications"
hdiutil create -volname Termi -srcfolder "$stage_dir" -format UDZO -ov "$dmg_path"
hdiutil verify "$dmg_path"
(cd build && shasum -a 256 Termi-mac-arm64.dmg > Termi-mac-arm64.dmg.sha256)

cp packaging/Termi.iconset/icon_256x256@2x.png website/public/icon.png
cp packaging/Termi.iconset/icon_32x32@2x.png website/public/favicon.png
node --input-type=module - "$version" "$minimum_macos" <<'JS'
import fs from 'node:fs';
import crypto from 'node:crypto';
const data = fs.readFileSync('build/Termi-mac-arm64.dmg');
const release = {
  version: process.argv[2],
  architecture: 'arm64',
  minimumMacOS: process.argv[3],
  sizeBytes: data.length,
  sha256: crypto.createHash('sha256').update(data).digest('hex'),
  downloadURL: 'https://github.com/NoahWhiteson/Termi/releases/latest/download/Termi-mac-arm64.dmg'
};
fs.writeFileSync('website/public/release.json', JSON.stringify(release, null, 2) + '\n');
JS
print "Packaged $dmg_path (v$version)"

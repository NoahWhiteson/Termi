#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
configuration="${1:-release}"
swift build --build-system native -c "$configuration"
bin_path="$(swift build --build-system native -c "$configuration" --show-bin-path)"
app_path="$PWD/build/Termi.app"
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/Termi" "$app_path/Contents/MacOS/Termi"
for resource in "$bin_path"/*.bundle(N); do
    cp -R "$resource" "$app_path/Contents/Resources/"
done
cp packaging/Info.plist "$app_path/Contents/Info.plist"
if [[ -f packaging/Termi.icns ]]; then cp packaging/Termi.icns "$app_path/Contents/Resources/"; fi
codesign --force --deep --sign - "$app_path"
print "Built $app_path"

#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
sample_dir=$(cd "$script_dir/.." && pwd)
package_dir=$(cd "$sample_dir/../.." && pwd)
godot_project="$sample_dir/GodotProject"
app_resources="$sample_dir/Resources"
package_resources="$package_dir/Sources/TrivialSample"
godot_app="${GODOT_APP:-/Applications/Godot-47.app}"
godot_binary="$godot_app/Contents/MacOS/Godot"

if [[ ! -x "$godot_binary" ]]; then
    echo "Godot executable not found: $godot_binary" >&2
    exit 1
fi

mkdir -p "$app_resources" "$package_resources"

"$godot_binary" --headless --editor --path "$godot_project" --import --quit
"$godot_binary" --headless --path "$godot_project" --export-pack PCK "$app_resources/main.pck"
cp "$app_resources/main.pck" "$package_resources/main.pck"
cp "$godot_project/LICENSE" "$package_resources/AxolotlDemo-LICENSE.txt"
cp "$godot_project/THIRD_PARTY.md" "$package_resources/THIRD_PARTY.md"
sed -i '' 's#fonts/LICENSE.txt#Xolonium-OFL.txt#g' "$package_resources/THIRD_PARTY.md"
cp "$godot_project/fonts/LICENSE.txt" "$package_resources/Xolonium-OFL.txt"

echo "Created $app_resources/main.pck"
echo "Copied the pack to $package_resources/main.pck"
echo "Copied the asset notices to $package_resources"

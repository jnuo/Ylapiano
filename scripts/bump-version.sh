#!/usr/bin/env bash
# Single source of truth for Ylapiano's version is `version.json`.
# This script bumps build (and optionally major/minor/patch) and syncs the
# value into `Ylapiano.xcodeproj/project.pbxproj`'s MARKETING_VERSION and
# CURRENT_PROJECT_VERSION fields.
#
# Convention (mandatory): version's last component == build. So bumping build
# from N to N+1 always sets version to MAJOR.MINOR.(N+1).
#
# Usage:
#   ./scripts/bump-version.sh            # build bump only
#   ./scripts/bump-version.sh --minor    # bump minor + build
#   ./scripts/bump-version.sh --major    # bump major + build

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT/version.json"
PBXPROJ="$ROOT/Ylapiano.xcodeproj/project.pbxproj"

[ -f "$VERSION_FILE" ] || { echo "version.json missing"; exit 1; }
[ -f "$PBXPROJ" ]      || { echo "project.pbxproj missing"; exit 1; }

current_version="$(python3 -c "import json; print(json.load(open('$VERSION_FILE'))['version'])")"
current_build="$(python3 -c "import json; print(json.load(open('$VERSION_FILE'))['build'])")"

IFS='.' read -r major minor patch <<< "$current_version"
new_build=$((current_build + 1))

case "${1:-}" in
  --major) major=$((major + 1)); minor=0 ;;
  --minor) minor=$((minor + 1)) ;;
  --patch|"") : ;;  # build-only bump
  *) echo "Unknown flag: $1"; exit 1 ;;
esac

# Patch component must equal build (enforced convention).
new_version="${major}.${minor}.${new_build}"

# Write version.json
python3 -c "
import json
with open('$VERSION_FILE','w') as f:
    json.dump({'version': '$new_version', 'build': $new_build}, f, indent=2)
    f.write('\n')
"

# Sync pbxproj — both MARKETING_VERSION and CURRENT_PROJECT_VERSION appear
# multiple times (Debug + Release configs). Replace all.
sed -i '' "s|MARKETING_VERSION = [^;]*;|MARKETING_VERSION = ${new_version};|g" "$PBXPROJ"
sed -i '' "s|CURRENT_PROJECT_VERSION = [^;]*;|CURRENT_PROJECT_VERSION = ${new_build};|g" "$PBXPROJ"

echo "Bumped to ${new_version} (build ${new_build})"

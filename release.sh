#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="Peek"

# Get current version from latest git tag, default to 1.0
CURRENT=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)
CURRENT=${CURRENT:-1.0}
# Bump minor: 1.0 -> 1.1
MAJOR=${CURRENT%.*}
MINOR=${CURRENT##*.}
NEW="$MAJOR.$((MINOR + 1))"

echo "==> $CURRENT -> $NEW"

# Update version in Info.plist
plutil -replace CFBundleShortVersionString -string "$NEW" Info.plist
plutil -replace CFBundleVersion -string "$NEW" Info.plist

# Build
make clean
make build

# Commit, tag, push
git add -A
git commit -m "v$NEW" || true
git push

# Zip and release
rm -f /tmp/$APP_NAME.zip
ditto -c -k --sequesterRsrc --keepParent "build/$APP_NAME.app" /tmp/$APP_NAME.zip
gh release create "v$NEW" /tmp/$APP_NAME.zip --title "v$NEW" --notes ""
echo "==> Released v$NEW"

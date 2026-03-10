#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="Peek"
APP_DIR="/tmp/$APP_NAME.app"

rm -rf "$APP_DIR" build
make build

rm -rf "/Applications/$APP_NAME.app"
cp -r build/$APP_NAME.app /Applications/
open "/Applications/$APP_NAME.app"
echo "==> Installed $APP_NAME.app"

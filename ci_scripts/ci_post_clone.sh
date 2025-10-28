#!/bin/bash
set -euo pipefail

echo "[ci_post_clone] Setting up Flutter and dependencies"

REPO_ROOT="$(pwd)"
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_SDK_DIR="$REPO_ROOT/flutter"

if [ ! -d "$FLUTTER_SDK_DIR" ]; then
  echo "[ci_post_clone] Cloning Flutter SDK ($FLUTTER_CHANNEL)"
  git clone --depth 1 -b "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_SDK_DIR"
fi

export PATH="$FLUTTER_SDK_DIR/bin:$PATH"
flutter --version

# CocoaPods
if ! command -v pod >/dev/null 2>&1; then
  echo "[ci_post_clone] Installing CocoaPods"
  if command -v sudo >/dev/null 2>&1; then
    sudo gem install cocoapods
  else
    gem install --user-install cocoapods
    export GEM_HOME="${GEM_HOME:-$HOME/.gem}"
    export PATH="$GEM_HOME/bin:$PATH"
  fi
fi
pod --version

# Flutter prep
flutter config --no-analytics || true
flutter precache --ios

# Get packages and generate iOS configs (Generated.xcconfig)
flutter pub get

echo "[ci_post_clone] Done"

#!/bin/bash
set -euo pipefail

echo "[ci_pre_xcodebuild] Preparing Flutter iOS build environment"

REPO_ROOT="$(pwd)"
FLUTTER_SDK_DIR="$REPO_ROOT/flutter"

# Ensure Flutter is in PATH (cloned in ci_post_clone)
if [ -d "$FLUTTER_SDK_DIR" ]; then
  export PATH="$FLUTTER_SDK_DIR/bin:$PATH"
fi

flutter --version

# Ensure Flutter iOS artifacts and Generated.xcconfig exist
flutter clean
flutter pub get
flutter precache --ios
flutter build ios --release --no-codesign

# Ensure CocoaPods dependencies are installed and filelists are generated
pushd ios
pod install --repo-update
popd

echo "[ci_pre_xcodebuild] Done"

#!/bin/bash
set -euo pipefail
set -x

echo "[ci_pre_xcodebuild] Preparing Flutter iOS build environment"

REPO_ROOT="$(pwd)"
FLUTTER_SDK_DIR="$REPO_ROOT/flutter"

# Ensure Flutter is in PATH (cloned in ci_post_clone)
if [ -d "$FLUTTER_SDK_DIR" ]; then
  export PATH="$FLUTTER_SDK_DIR/bin:$PATH"
fi

flutter --version

# Ensure CocoaPods is available in this phase as well
if ! command -v pod >/dev/null 2>&1; then
  echo "[ci_pre_xcodebuild] CocoaPods not found, installing"
  if command -v sudo >/dev/null 2>&1; then
    sudo gem install cocoapods
  else
    gem install --user-install cocoapods
    export GEM_HOME="${GEM_HOME:-$HOME/.gem}"
    export PATH="$GEM_HOME/bin:$PATH"
  fi
fi
pod --version

# Ensure Flutter iOS artifacts and Generated.xcconfig exist
flutter clean
flutter pub get
flutter precache --ios
flutter build ios --release --no-codesign

# Ensure CocoaPods dependencies are installed and filelists are generated
pushd ios
pod install --repo-update
# Verify the problematic filelists exist (if CocoaPods still uses them)
ls -la "Pods/Target Support Files/Pods-Runner/" || true
if [ -f "Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Release-input-files.xcfilelist" ]; then
  echo "[ci_pre_xcodebuild] Found input filelist"
else
  echo "[ci_pre_xcodebuild] Input filelist missing (may be expected if filelists are disabled)"
  mkdir -p "Pods/Target Support Files/Pods-Runner/"
  : > "Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Release-input-files.xcfilelist"
fi
if [ -f "Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Release-output-files.xcfilelist" ]; then
  echo "[ci_pre_xcodebuild] Found output filelist"
else
  echo "[ci_pre_xcodebuild] Output filelist missing (may be expected if filelists are disabled)"
  mkdir -p "Pods/Target Support Files/Pods-Runner/"
  : > "Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Release-output-files.xcfilelist"
fi
  # Also prepare Debug variants just in case
for cfg in Debug; do
  in_file="Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-${cfg}-input-files.xcfilelist"
  out_file="Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-${cfg}-output-files.xcfilelist"
  [ -f "$in_file" ] || : > "$in_file"
  [ -f "$out_file" ] || : > "$out_file"
done
popd

echo "[ci_pre_xcodebuild] Done"

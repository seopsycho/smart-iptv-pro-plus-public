#!/bin/sh
set -e

echo "Installing CocoaPods..."
gem install cocoapods

cd $CI_WORKSPACE/ios
pod install --repo-update

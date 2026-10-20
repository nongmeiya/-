#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
rm -rf build
xcodebuild \
  -project HappyCapy.xcodeproj \
  -scheme HappyCapy \
  -configuration Release \
  -sdk iphoneos \
  -archivePath build/HappyCapy.xcarchive \
  archive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
mkdir -p build/Payload
cp -R build/HappyCapy.xcarchive/Products/Applications/HappyCapy.app build/Payload/
(cd build && zip -qry HappyCapy-unsigned.ipa Payload)
printf 'Created: %s\\n' "$PWD/build/HappyCapy-unsigned.ipa"

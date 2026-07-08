#!/usr/bin/env bash
set -euo pipefail

NAME="iphone"
if [ "$#" -gt 0 ]; then
  NAME="$1"
fi

echo '正在使用 Flutter 进行无签名构建'
flutter pub get
flutter build ios --release --no-codesign

rm -rf Payload "${NAME}.ipa" Payload.zip
mkdir -p Payload
cp -R build/ios/iphoneos/Runner.app Payload/

(
  cd Payload/..
  zip -r -y "${NAME}.ipa" Payload
)

rm -rf Payload

echo "已生成 ${NAME}.ipa"

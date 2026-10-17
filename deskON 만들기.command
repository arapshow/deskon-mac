#!/bin/bash
# 더블클릭하면 deskON 앱을 만들어 응용 프로그램 폴더에 넣고 실행한다.
cd "$(dirname "$0")" || exit 1

pause() { echo; read -n 1 -s -r -p "아무 키나 누르면 이 창이 닫힙니다."; echo; }

if ! xcode-select -p >/dev/null 2>&1; then
  echo "애플 개발 도구가 필요합니다. 곧 뜨는 설치 창에서 [설치]를 눌러 주세요."
  echo "설치가 끝나면 이 파일을 다시 더블클릭하면 됩니다."
  xcode-select --install
  pause; exit 0
fi

echo "deskON을 만드는 중입니다…"
APP="build/deskON.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS"

for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13" Sources/*.swift -o "build/deskon-$arch" || { echo "만들기에 실패했습니다. 이 창 내용을 캡처해 Claude에게 보내 주세요."; pause; exit 1; }
done
lipo -create build/deskon-arm64 build/deskon-x86_64 -output "$APP/Contents/MacOS/deskon"
rm build/deskon-arm64 build/deskon-x86_64
cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP" >/dev/null 2>&1

# 다른 사람에게 줄 dmg(소개 페이지 deskon.arapshow.net에서 받는 파일)
dmg/make-dmg.sh || { echo "dmg 만들기에 실패했습니다. 이 창 내용을 캡처해 Claude에게 보내 주세요."; pause; exit 1; }
VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
# 소개 페이지 폴더(site/)가 있는 비공개 저장소에서만. 공개 사본에는 없다.
if [ -f site/index.html ]; then
  mkdir -p site/download
  rm -f site/download/deskON*
  cp "build/deskON-$VER.dmg" site/download/
  # 소개 페이지의 다운로드 링크·단추 글자·파일 크기를 새 버전에 맞춘다.
  SIZE=$(awk "BEGIN { printf \"%.1f\", $(stat -f %z "build/deskON-$VER.dmg") / 1000000 }")
  sed -i '' -E "s/deskON-[0-9.]+\.dmg/deskON-$VER.dmg/g; s/deskON [0-9.]+ 받기/deskON $VER 받기/; s/(deskON-$VER\.dmg · )[0-9.]+ MB/\1$SIZE MB/" site/index.html
fi

# 켜져 있던 deskON을 끄고 새 것으로 바꾼다.
pkill -x deskon 2>/dev/null
sleep 0.5
DEST="/Applications"
[ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }
rm -rf "$DEST/deskON.app"
ditto "$APP" "$DEST/deskON.app"
open "$DEST/deskON.app"

echo
echo "완료했습니다. deskON이 켜졌습니다($DEST/deskON.app)."
echo "다른 사람에게 줄 파일: $(pwd)/build/deskON-$VER.dmg"
pause

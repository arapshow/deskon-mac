#!/bin/bash
# build/deskON.app으로 build/deskON-버전.dmg를 만든다(버전은 Info.plist).
# 열면 deskON과 응용 프로그램 폴더가 나란히 있고, 배경에 끌어 놓으라는 화살표가 있다.
# 아래 가운데에는 소개 페이지(deskon.arapshow.net)로 가는 deskON Guide 바로가기.
# 쓰는 법: dmg/make-dmg.sh (저장소 맨 위에서, 'deskON 만들기.command'가 부른다)
set -e
cd "$(dirname "$0")/.."

APP="build/deskON.app"
VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
OUT="build/deskON-$VER.dmg"
VOL="deskON $VER"
STAGE=$(mktemp -d)
RW="$STAGE/rw.dmg"

mkdir -p "$STAGE/src/.background"
ditto "$APP" "$STAGE/src/deskON.app"
ln -s /Applications "$STAGE/src/Applications"
cat > "$STAGE/src/deskON Guide.webloc" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>URL</key>
	<string>https://deskon.arapshow.net/</string>
</dict>
</plist>
PLIST
cp dmg/background.tiff "$STAGE/src/.background/background.tiff"

hdiutil detach "/Volumes/$VOL" -quiet 2>/dev/null || true
hdiutil create -quiet -srcfolder "$STAGE/src" -volname "$VOL" -fs HFS+ -format UDRW -size 20m "$RW"
hdiutil attach -quiet -readwrite -noautoopen "$RW"

# 창 모양·아이콘 자리는 Finder가 정한다. Finder를 부릴 권한이 없으면 꾸미기 없이 그대로 만든다.
osascript <<EOF || echo "(창 꾸미기는 건너뜀: Finder 제어 권한 없음)"
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 740, 568}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 96
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "deskON.app" of container window to {140, 150}
    set position of item "Applications" of container window to {400, 150}
    set extension hidden of item "deskON Guide.webloc" to true
    set position of item "deskON Guide.webloc" of container window to {270, 345}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

sync
hdiutil detach -quiet "/Volumes/$VOL"
rm -f build/deskON*.dmg
hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT"
rm -rf "$STAGE"

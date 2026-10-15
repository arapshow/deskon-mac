#!/bin/bash
# 앱 아이콘(icon/AppIcon.icns)을 다시 만든다. 아이콘 그림을 바꿀 때만 실행한다.
cd "$(dirname "$0")" || exit 1
TMP=$(mktemp -d)
swiftc make-icon.swift -o "$TMP/make-icon" && "$TMP/make-icon" "$TMP/AppIcon.iconset" \
  && iconutil -c icns "$TMP/AppIcon.iconset" -o AppIcon.icns \
  && cp "$TMP/AppIcon.iconset/icon_512x512@2x.png" AppIcon-1024.png
rm -rf "$TMP"

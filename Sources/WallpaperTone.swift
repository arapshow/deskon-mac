import AppKit

// 바탕화면 그림에서 심볼이 놓이는 자리가 어두운지 잰다(Color: Auto).
// 권한이 필요 없는 '지금 바탕화면 그림 파일'만 본다. 구석을 덮은 앱 창은 모른다.
// 그림 파일이 아니거나(동영상 배경 등) 읽지 못하면 nil → 라이트/다크 모드를 따른다.
@MainActor
enum WallpaperTone {
    // 바탕화면 파일마다 작게 줄인 그림 하나(크기 슬라이더를 끌어도 큰 파일을 다시 읽지 않게).
    private static var thumbKey = ""
    private static var thumb: CGImage?
    // 자리별 밝기 결과
    private static var cache: [String: Bool] = [:]

    /// rect: 화면 좌표(전역, 아래가 0)의 심볼 자리.
    static func isDark(on screen: NSScreen, at rect: NSRect) -> Bool? {
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?
            .timeIntervalSince1970 ?? 0
        let fileKey = "\(url.path)|\(modified)"
        let key = "\(fileKey)|\(screen.frame)|\(rect)"
        if let hit = cache[key] { return hit }

        guard let image = thumbnail(url, key: fileKey) else { return nil }
        let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
        guard let crop = imageRect(for: rect, on: screen, image: image, options: options),
              let part = image.cropping(to: crop),
              let brightness = averageBrightness(part) else { return nil }

        let dark = brightness < 0.5
        if cache.count > 64 { cache.removeAll() }
        cache[key] = dark
        return dark
    }

    // 긴 변 1024픽셀로 줄인 그림. 밝기만 재므로 이 정도면 충분하다.
    private static func thumbnail(_ url: URL, key: String) -> CGImage? {
        if key == thumbKey { return thumb }
        thumbKey = key
        thumb = nil
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1024,
        ]
        thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        return thumb
    }

    // 화면의 자리 → 그림 픽셀 자리. 기본값인 '화면 채우기'(가운데 맞춰 넘치는 부분 자름)로 계산하고,
    // '화면에 맞추기'(잘리지 않게 줄임)도 따른다. 그 밖의 배치는 채우기와 비슷하게 본다.
    private static func imageRect(for rect: NSRect, on screen: NSScreen, image: CGImage,
                                  options: [NSWorkspace.DesktopImageOptionKey: Any]) -> CGRect? {
        let screenSize = screen.frame.size
        let imageSize = CGSize(width: image.width, height: image.height)
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }

        let allowClipping = (options[.allowClipping] as? NSNumber)?.boolValue ?? true
        let fit = !allowClipping
        let scale = fit ? min(screenSize.width / imageSize.width, screenSize.height / imageSize.height)
                        : max(screenSize.width / imageSize.width, screenSize.height / imageSize.height)
        let shown = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let offset = CGPoint(x: (screenSize.width - shown.width) / 2, y: (screenSize.height - shown.height) / 2)

        // 화면 안 좌표(위가 0)로 바꾼 뒤 그림 픽셀로.
        let local = CGRect(x: rect.minX - screen.frame.minX,
                           y: screenSize.height - (rect.maxY - screen.frame.minY),
                           width: rect.width, height: rect.height)
        let pixels = CGRect(x: (local.minX - offset.x) / scale, y: (local.minY - offset.y) / scale,
                            width: local.width / scale, height: local.height / scale)
            .intersection(CGRect(origin: .zero, size: imageSize))
        return pixels.isEmpty ? nil : pixels.integral
    }

    // 8x8로 줄여 그린 뒤 평균 밝기(0 어두움 ~ 1 밝음).
    private static func averageBrightness(_ image: CGImage) -> CGFloat? {
        let side = 8
        var data = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(data: &data, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        var total: CGFloat = 0
        for i in stride(from: 0, to: data.count, by: 4) {
            total += 0.299 * CGFloat(data[i]) + 0.587 * CGFloat(data[i + 1]) + 0.114 * CGFloat(data[i + 2])
        }
        return total / CGFloat(side * side) / 255
    }
}

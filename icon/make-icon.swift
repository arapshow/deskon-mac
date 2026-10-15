import AppKit

// deskON 앱 아이콘(=_# 얼굴)을 그려 iconset 폴더에 크기별로 저장한다.
// 쓰는 법: icon/make-icon.sh (AppIcon.icns를 다시 만든다)
// 1024 캔버스, 아이콘 몸통 824(가장자리 100), 모서리 반지름 185.

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
            blue: CGFloat(v & 0xff) / 255, alpha: 1)
}

// SymbolView와 같은 100x100 막대 정의.
let bars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(10, 35, 90, 35), (10, 65, 90, 65), (35, 10, 35, 90), (65, 10, 65, 90)]

func drawIcon(size: CGFloat) {
    let scale = size / 1024
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * scale, y: y * scale) }

    let body = NSRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185 * scale, yRadius: 185 * scale)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 20 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -8 * scale)
    shadow.set()
    NSGradient(starting: hex(0x5B6CF0), ending: hex(0x3A2FB8))!.draw(in: shape, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    // 왼쪽 눈 = (2번), 오른쪽 눈 # (4번), 아래 긴 입.
    let eye: CGFloat = 230
    let path = NSBezierPath()
    path.lineWidth = 34 * scale
    path.lineCapStyle = .round
    for (cx, count) in [(CGFloat(330), 2), (CGFloat(694), 4)] {
        let ox = cx - eye / 2, oy = 440 - eye / 2
        for b in bars.prefix(count) {
            path.move(to: p(ox + b.0 * eye / 100, oy + b.1 * eye / 100))
            path.line(to: p(ox + b.2 * eye / 100, oy + b.3 * eye / 100))
        }
    }
    path.move(to: p(512 - 210, 650))
    path.line(to: p(512 + 210, 650))
    NSColor.white.setStroke()
    path.stroke()
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let px = base * factor
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = ctx
        // 그림 좌표는 위가 0이다.
        ctx.cgContext.translateBy(x: 0, y: CGFloat(px))
        ctx.cgContext.scaleBy(x: 1, y: -1)
        drawIcon(size: CGFloat(px))
        NSGraphicsContext.restoreGraphicsState()
        let name = factor == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
    }
}

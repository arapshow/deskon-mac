import AppKit

// dmg 창 배경(540x420): 위 줄 왼쪽 deskON, 오른쪽 응용 프로그램, 사이에 화살표와 안내. 아래 가운데는 deskON Guide 바로가기 자리.
// 쓰는 법: swiftc make-background.swift -o /tmp/bg && /tmp/bg a.png a@2x.png && tiffutil -cathidpicheck a.png a@2x.png -out background.tiff

func render(scale: CGFloat, to path: String) {
    let size = NSSize(width: 540, height: 420)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    // 위가 0인 좌표로 그린다(Finder 아이콘 위치와 같은 기준).
    ctx.translateBy(x: 0, y: size.height)
    ctx.scaleBy(x: 1, y: -1)

    NSColor(srgbRed: 0.965, green: 0.965, blue: 0.973, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()

    // 화살표: 아이콘 중심 (140,150) → (400,150)
    let arrow = NSBezierPath()
    arrow.lineWidth = 3
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 218, y: 150))
    arrow.line(to: NSPoint(x: 318, y: 150))
    arrow.move(to: NSPoint(x: 304, y: 138))
    arrow.line(to: NSPoint(x: 320, y: 150))
    arrow.line(to: NSPoint(x: 304, y: 162))
    NSColor(srgbRed: 0.29, green: 0.29, blue: 0.84, alpha: 1).setStroke()
    arrow.stroke()

    NSColor(white: 0.85, alpha: 1).setFill()
    NSRect(x: 60, y: 296, width: 420, height: 1).fill()

    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let flipped = NSGraphicsContext(cgContext: ctx, flipped: true)
    NSGraphicsContext.current = flipped
    for (text, y, font, color) in [
        ("응용 프로그램 폴더로 끌어 놓으세요", CGFloat(236), NSFont.systemFont(ofSize: 14, weight: .medium), NSColor(white: 0.15, alpha: 1)),
        ("Drag deskON to Applications", CGFloat(258), NSFont.systemFont(ofSize: 12), NSColor(white: 0.45, alpha: 1)),
    ] {
        (text as NSString).draw(in: NSRect(x: 0, y: y, width: size.width, height: 20),
                                withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
    }
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

render(scale: 1, to: CommandLine.arguments[1])
render(scale: 2, to: CommandLine.arguments[2])

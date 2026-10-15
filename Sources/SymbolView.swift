import AppKit

// # 심볼. 좌표는 HANDOFF.md의 100x100 정의를 그대로 쓴다.
final class SymbolView: NSView {
    var space = 1 { didSet { if space != oldValue { needsDisplay = true } } }
    var onClick: ((NSEvent) -> Void)?
    // 구석 창에서만 쓴다. 심볼 둘레 여백과 심볼 투명도.
    var inset: CGFloat = 0 { didSet { needsDisplay = true } }
    var opacity: CGFloat = 1 { didSet { if opacity != oldValue { needsDisplay = true } } }
    // 정한 색(흰색·검정). nil이면 라이트/다크 모드를 따른다.
    var tint: NSColor? { didSet { if tint != oldValue { needsDisplay = true } } }

    // 5개 이상일 때 이스터에그 색. 어랍쇼 확정(2026-10-14): 주황.
    static let eggColor = NSColor.systemOrange

    private static let bars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (10, 35, 90, 35),   // 1: 가로 위
        (10, 65, 90, 65),   // 2: 가로 아래
        (35, 10, 35, 90),   // 3: 세로 왼쪽
        (65, 10, 65, 90),   // 4: 세로 오른쪽
    ]

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // 투명한 창은 칠해진 픽셀에서만 클릭을 받는다. 눈에 안 보이게 옅게 칠해 창 전체를 누를 수 있게 한다.
        if onClick != nil {
            NSColor(white: 0, alpha: 1.0 / 255).setFill()
            bounds.fill()
        }
        NSGraphicsContext.current?.cgContext.translateBy(x: inset, y: inset)
        let color: NSColor = tint ?? (isDark ? .white : .black)
        Self.draw(space: space, width: bounds.width - inset * 2, color: color.withAlphaComponent(opacity),
                  eggAlpha: opacity)
    }

    // 뒤집힌(위가 0인) 좌표에서 그린다. 5개 이상이면 color 대신 이스터에그 색.
    nonisolated static func draw(space: Int, width: CGFloat, color: NSColor, eggAlpha: CGFloat = 1) {
        let scale = width / 100
        let path = NSBezierPath()
        path.lineWidth = (width <= 24 ? 14 : 12) * scale
        path.lineCapStyle = .round
        for bar in bars.prefix(min(space, 4)) {
            path.move(to: NSPoint(x: bar.0 * scale, y: bar.1 * scale))
            path.line(to: NSPoint(x: bar.2 * scale, y: bar.3 * scale))
        }
        (space >= 5 ? eggColor.withAlphaComponent(eggAlpha) : color).setStroke()
        path.stroke()
    }

    // 메뉴에 넣을 작은 심볼 그림. 메뉴 글자색에 맞춰 칠해지도록 template으로 만든다.
    static func image(space: Int, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            draw(space: space, width: rect.width, color: .black)
            return true
        }
        image.isTemplate = space < 5
        return image
    }

    private var isDark: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    override func viewDidChangeEffectiveAppearance() { needsDisplay = true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick?(event) }
}

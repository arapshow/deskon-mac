import AppKit

// 화면 구석에 뜨는 심볼 창. 모든 Space·전체화면 앱 위에 보인다.
// 구석마다 창이 하나씩 있고, 설정에 따라 왼쪽·오른쪽·양쪽에 띄운다.
@MainActor
final class Overlay {
    private let left: CornerPanel
    private let right: CornerPanel
    // 구석에서 옆·위로 떨어뜨려, 심볼을 누르러 가다 마우스가 모서리까지 미끄러져 핫코너가 켜지지 않게 한다.
    private let sideMargin: CGFloat = 24
    private let bottomMargin: CGFloat = 12

    init(onClick: @escaping (NSEvent, NSView) -> Void) {
        left = CornerPanel(onClick: onClick)
        right = CornerPanel(onClick: onClick)
    }

    func update() {
        let settings = Settings.shared
        // 확장 모니터에서는 메뉴바가 있는 주 화면에만 표시. 미러링이면 주 화면이 모든 화면에 그대로 보인다.
        guard let screen = NSScreen.screens.first,
              let info = SpaceReader.read(for: screen),
              info.total > 1 || settings.showWhenSingle else {
            left.hide()
            right.hide()
            return
        }

        // Dock과 상관없이 화면 구석 기준.
        let frame = screen.frame
        let size = settings.size
        let alpha = 1 - settings.transparency
        let showLeft = settings.corner != .bottomRight
        let showRight = settings.corner != .bottomLeft

        if showLeft {
            let rect = NSRect(x: frame.minX + sideMargin, y: frame.minY + bottomMargin, width: size, height: size)
            left.show(space: info.current, alpha: alpha, tint: tint(settings.color, screen, rect), frame: rect)
        } else {
            left.hide()
        }
        if showRight {
            let rect = NSRect(x: frame.maxX - sideMargin - size, y: frame.minY + bottomMargin, width: size, height: size)
            right.show(space: info.current, alpha: alpha, tint: tint(settings.color, screen, rect), frame: rect)
        } else {
            right.hide()
        }
    }

    // nil이면 라이트/다크 모드를 따른다(Auto인데 바탕화면 그림을 못 읽을 때).
    private func tint(_ color: SymbolColor, _ screen: NSScreen, _ rect: NSRect) -> NSColor? {
        switch color {
        case .white: return .white
        case .black: return .black
        case .auto:
            guard let dark = WallpaperTone.isDark(on: screen, at: rect) else { return nil }
            return dark ? .white : .black
        }
    }
}

@MainActor
private final class CornerPanel {
    private let panel: NSPanel
    private let view = SymbolView()

    init(onClick: @escaping (NSEvent, NSView) -> Void) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 30, height: 30),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.contentView = view
        view.onClick = { [view] event in onClick(event, view) }
    }

    // 심볼 둘레로 이만큼 더 넓게 클릭을 받는다.
    private let hitPadding: CGFloat = 10

    func show(space: Int, alpha: CGFloat, tint: NSColor?, frame symbolFrame: NSRect) {
        view.space = space
        view.tint = tint
        view.inset = hitPadding
        // 투명도는 창이 아니라 심볼 색에 준다. 창 전체를 흐리게 하면 클릭 받는 옅은 바탕까지 사라진다.
        view.opacity = alpha
        let frame = symbolFrame.insetBy(dx: -hitPadding, dy: -hitPadding)
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
            view.needsDisplay = true
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func hide() {
        panel.orderOut(nil)
    }
}

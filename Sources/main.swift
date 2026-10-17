import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlay: Overlay!
    private lazy var settingsWindow = SettingsWindowController()
    private var timer: Timer?
    private var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay = Overlay { [weak self] event, view in self?.showMenu(event, from: view) }

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(refresh),
                              name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: Settings.changed, object: nil)

        // 데스크탑을 더하거나 뺄 때는 알림이 오지 않아서 2초마다 가볍게 확인한다.
        timer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(refresh),
                                     userInfo: nil, repeats: true)
        timer?.tolerance = 0.5   // 정확히 2초일 필요 없음, macOS가 다른 일과 묶어 깨우게(배터리)

        overlay.update()

        // 새 버전 확인: 켤 때 한 번, 켜 둔 채로 오래 쓰는 경우를 위해 6시간마다 '30일 지났나'만 본다.
        UpdateCheck.runIfDue()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in UpdateCheck.runIfDue() }
        }

        // 처음 실행할 때만 설정 창을 띄워 켜졌다는 걸 알린다.
        if !UserDefaults.standard.bool(forKey: "launchedBefore") {
            UserDefaults.standard.set(true, forKey: "launchedBefore")
            settingsWindow.show()
        }
    }

    @objc private func refresh() {
        overlay.update()
        settingsWindow.refresh()
    }

    // 이미 켜져 있을 때 deskON을 다시 실행하면 설정 창.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return false
    }

    // 구석 심볼을 누르면 메뉴가 위로 펼쳐진다. 누른 자리에서 가까운 순서로 설정 · 지금 데스크탑 · 종료.
    private func showMenu(_ event: NSEvent, from view: NSView) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit deskON", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        if let screen = NSScreen.screens.first, let info = SpaceReader.read(for: screen) {
            let current = NSMenuItem(title: "Desktop \(info.current)", action: nil, keyEquivalent: "")
            current.image = SymbolView.image(space: info.current, size: 16)
            current.isEnabled = false
            menu.addItem(current)
        }
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: "").target = self
        NSApp.activate(ignoringOtherApps: true)
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}

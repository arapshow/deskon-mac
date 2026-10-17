import AppKit
import ServiceManagement
import SwiftUI

// 설정 창. macOS 시스템 설정과 같은 모양(SwiftUI grouped Form)으로 그린다.
final class SettingsWindowController: NSWindowController {
    private let model = SettingsModel()

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "deskON Settings"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        let hosting = NSHostingController(rootView: SettingsView(model: model) { [weak window] in window?.close() })
        hosting.sizingOptions = .preferredContentSize
        window.contentViewController = hosting
        window.center()
    }

    func show() {
        model.reload()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // 데스크탑이 바뀌거나 더하고 뺄 때 아이콘 줄을 다시 그린다.
    func refresh() {
        guard window?.isVisible == true else { return }
        model.reloadSpaces()
        if model.updateAvailable != UpdateCheck.updateAvailable { model.updateAvailable = UpdateCheck.updateAvailable }
    }
}

@MainActor
final class SettingsModel: ObservableObject {
    @Published var spaces: SpaceInfo?
    @Published var corner = Settings.shared.corner
    @Published var size = Double(Settings.shared.size)
    @Published var transparency = Double(Settings.shared.transparency)
    @Published var showWhenSingle = Settings.shared.showWhenSingle
    @Published var color = Settings.shared.color
    @Published var launchAtLogin = false
    @Published var checkUpdates = Settings.shared.checkUpdates
    @Published var updateAvailable = UpdateCheck.updateAvailable

    func reload() {
        let settings = Settings.shared
        corner = settings.corner
        size = Double(settings.size)
        transparency = Double(settings.transparency)
        showWhenSingle = settings.showWhenSingle
        color = settings.color
        checkUpdates = settings.checkUpdates
        updateAvailable = UpdateCheck.updateAvailable
        launchAtLogin = SMAppService.mainApp.status == .enabled
        reloadSpaces()
    }

    func reloadSpaces() {
        guard let screen = NSScreen.screens.first else { return }
        let info = SpaceReader.read(for: screen)
        if info?.current != spaces?.current || info?.total != spaces?.total { spaces = info }
    }

    var showLeft: Bool { corner != .bottomRight }
    var showRight: Bool { corner != .bottomLeft }

    // 최소 한쪽은 켜 둔다. 마지막 하나를 끄려 하면 그대로 둔다.
    func set(left: Bool, right: Bool) {
        let new: Corner
        switch (left, right) {
        case (true, true): new = .both
        case (true, false): new = .bottomLeft
        case (false, true): new = .bottomRight
        case (false, false): return
        }
        corner = new
        Settings.shared.corner = new
    }

    func setSize(_ value: Double) {
        size = value
        Settings.shared.size = CGFloat(value.rounded())
    }

    func setTransparency(_ value: Double) {
        transparency = value
        Settings.shared.transparency = CGFloat(value)
    }

    func setColor(_ value: SymbolColor) {
        color = value
        Settings.shared.color = value
    }

    func setCheckUpdates(_ value: Bool) {
        checkUpdates = value
        Settings.shared.checkUpdates = value
        if value { UpdateCheck.runIfDue() }
    }

    func setShowWhenSingle(_ value: Bool) {
        showWhenSingle = value
        Settings.shared.showWhenSingle = value
    }

    // 자동 켜기는 macOS가 기억한다(시스템 설정 > 일반 > 로그인 항목).
    func setLaunchAtLogin(_ value: Bool) {
        var failure: Error?
        do {
            if value {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            failure = error
        }
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        guard value, status != .enabled else { return }

        // 시스템 설정 > 일반 > 로그인 항목에서 deskON이 꺼져 있으면 macOS가 허락을 기다린다. 그 화면을 바로 연다.
        if status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            alert("Allow deskON in Login Items",
                  "Turn on deskON in System Settings › General › Login Items, then try again.")
        } else {
            alert("Couldn't turn on Open at login", failure?.localizedDescription ?? "Please try again.")
        }
    }

    private func alert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    SpacesRow(spaces: model.spaces)
                }

                Section {
                    CornerPreview(left: model.showLeft, right: model.showRight) { side in
                        if side == .bottomLeft {
                            model.set(left: !model.showLeft, right: model.showRight)
                        } else {
                            model.set(left: model.showLeft, right: !model.showRight)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                } header: {
                    Text("Corner")
                        .padding(.top, -10)   // 위 Desktop 칸과의 빈 공간을 조금 줄임
                } footer: {
                    Text("Click a corner to turn it on or off.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("Appearance") {
                    Slider(value: Binding(get: { model.size }, set: { model.setSize($0) }), in: 16...64) {
                        Text("Size")
                    } minimumValueLabel: {
                        symbolIcon(10)
                    } maximumValueLabel: {
                        symbolIcon(18)
                    }
                    Slider(value: Binding(get: { model.transparency }, set: { model.setTransparency($0) }),
                           in: 0...0.85) {
                        Text("Transparency")
                    } minimumValueLabel: {
                        symbolIcon(14)
                    } maximumValueLabel: {
                        symbolIcon(14, opacity: 0.3)
                    }
                    // Auto: 바탕화면 그림의 구석 밝기에 맞춰 흰색·검정
                    Picker("Color", selection: Binding(get: { model.color }, set: { model.setColor($0) })) {
                        Text("Auto").tag(SymbolColor.auto)
                        Text("White").tag(SymbolColor.white)
                        Text("Black").tag(SymbolColor.black)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Show with only one desktop",
                           isOn: Binding(get: { model.showWhenSingle }, set: { model.setShowWhenSingle($0) }))
                    Toggle("Open at login",
                           isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                    Toggle("Check for updates",
                           isOn: Binding(get: { model.checkUpdates }, set: { model.setCheckUpdates($0) }))
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            // 버전과 소개 페이지(Guide) 링크
            HStack(spacing: 6) {
                Text("deskON \(Guide.version)  ·")
                    .foregroundColor(.secondary)
                // 새 버전이 있으면 Guide 대신 Update available(누르면 소개 페이지)
                Button(model.updateAvailable ? "Update available" : "Guide") { Guide.open() }
                    .buttonStyle(.link)
            }
            .font(.footnote)

            // 종료는 왼쪽, 닫기는 오른쪽(기본 단추, Return 키).
            HStack {
                Button("Quit deskON") { NSApp.terminate(nil) }
                Spacer()
                Button("Close", action: close)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func symbolIcon(_ size: CGFloat, opacity: Double = 1) -> some View {
        Image(nsImage: SymbolView.image(space: 4, size: size))
            .foregroundColor(.secondary)
            .opacity(opacity)
    }
}

// Desktop 이름 옆에 1~4, 5~ 심볼을 늘어놓는다. 이게 곧 설명서다.
private struct SpacesRow: View {
    let spaces: SpaceInfo?

    var body: some View {
        HStack(spacing: 14) {
            // 아이콘 자리는 그대로 두고, 글자만 왼쪽 빈 자리 가운데에 놓는다.
            HStack(spacing: 16) {
                Text("Desktop").hidden()
                Spacer(minLength: 0)
            }
            .overlay {
                Text("Desktop")
                    .foregroundColor(.secondary)
            }
            // 1~4와 5~(이스터에그 색)를 늘 보여 준다. 없는 데스크탑은 흐리게, 지금 데스크탑 번호만 색을 다르게.
            ForEach(1...5, id: \.self) { space in
                let total = spaces?.total ?? 0
                let current = min(spaces?.current ?? 0, 5)
                VStack(spacing: 6) {
                    Image(nsImage: SymbolView.image(space: space, size: 26))
                        .foregroundColor(.primary)
                        .opacity(space <= total ? 1 : 0.3)
                    Text(space == 5 ? "5~" : "\(space)")
                        .font(.callout.monospacedDigit().weight(space == current ? .bold : .regular))
                        .foregroundColor(space == current ? .accentColor : .secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.trailing, 28)
        .padding(.vertical, 6)
    }
}

// 선으로 그린 Dock 양옆에 심볼 자리. 켠 쪽은 진하게, 끈 쪽은 흐린 자리 표시. 왼쪽·오른쪽 절반을 누르면 그쪽을 켜고 끈다.
private struct CornerPreview: View {
    let left: Bool
    let right: Bool
    let toggle: (Corner) -> Void

    private let line: CGFloat = 1.2

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                mark(on: left)
                Spacer(minLength: 12)
                dock
                Spacer(minLength: 12)
                mark(on: right)
            }
            .padding(.horizontal, 4)
            Rectangle()
                .fill(Color.primary)
                .frame(height: line)
        }
        .frame(width: 260)
        .contentShape(Rectangle())
        .overlay {
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture { toggle(.bottomLeft) }
                Color.clear.contentShape(Rectangle()).onTapGesture { toggle(.bottomRight) }
            }
        }
    }

    private var dock: some View {
        HStack(spacing: 8) {
            Circle()
                .stroke(Color.primary, lineWidth: line)
                .frame(width: 16, height: 16)
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.primary, lineWidth: line)
                .frame(width: 13, height: 13)
                .rotationEffect(.degrees(15))
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.primary, lineWidth: line)
                .frame(width: 15, height: 15)
        }
        .padding(.horizontal, 12)
        .padding(.top, 9)
        .padding(.bottom, 7)
        .overlay(DockOutline().stroke(Color.primary, lineWidth: line))
    }

    @ViewBuilder
    private func mark(on: Bool) -> some View {
        if on {
            Image(nsImage: SymbolView.image(space: 4, size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 26, height: 26)
                .padding(.bottom, 4)
        } else {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: 24, height: 24)
                .padding(.bottom, 5)
        }
    }
}

// 위쪽 모서리만 둥글고 아래는 바닥선에 붙는 Dock 테두리.
private struct DockOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 6
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

import AppKit

enum Corner: Int {
    case bottomLeft = 0
    case bottomRight = 1
    case both = 2
}

// 심볼 색. Auto는 바탕화면 그림의 구석 밝기를 보고 흰색·검정을 고른다.
enum SymbolColor: Int {
    case auto = 0
    case white = 1
    case black = 2
}

// 설정: 구석, 크기, 투명도, 색, 하나일 때 보이기, 새 버전 확인.
final class Settings {
    static let shared = Settings()
    static let changed = Notification.Name("deskonSettingsChanged")

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            "corner": Corner.bottomRight.rawValue,
            "size": 30.0,
            "transparency": 0.4,
            "showWhenSingle": false,
            "color": SymbolColor.auto.rawValue,
            "checkUpdates": true,
        ])
    }

    var corner: Corner {
        get { Corner(rawValue: defaults.integer(forKey: "corner")) ?? .bottomRight }
        set { defaults.set(newValue.rawValue, forKey: "corner"); notify() }
    }

    var color: SymbolColor {
        get { SymbolColor(rawValue: defaults.integer(forKey: "color")) ?? .auto }
        set { defaults.set(newValue.rawValue, forKey: "color"); notify() }
    }

    var size: CGFloat {
        get { CGFloat(defaults.double(forKey: "size")) }
        set { defaults.set(Double(newValue), forKey: "size"); notify() }
    }

    // 0 = 불투명, 클수록 흐려진다.
    var transparency: CGFloat {
        get { CGFloat(defaults.double(forKey: "transparency")) }
        set { defaults.set(Double(newValue), forKey: "transparency"); notify() }
    }

    // 30일에 한 번 새 버전 번호 확인(UpdateCheck)
    var checkUpdates: Bool {
        get { defaults.bool(forKey: "checkUpdates") }
        set { defaults.set(newValue, forKey: "checkUpdates"); notify() }
    }

    var showWhenSingle: Bool {
        get { defaults.bool(forKey: "showWhenSingle") }
        set { defaults.set(newValue, forKey: "showWhenSingle"); notify() }
    }

    private func notify() {
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }
}

// 소개 페이지(설명서). 설정 창 맨 아래 Guide가 연다.
enum Guide {
    static let url = URL(string: "https://deskon.arapshow.net/")!
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
    static func open() { NSWorkspace.shared.open(url) }
}

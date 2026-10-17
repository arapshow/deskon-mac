import AppKit

// 새 버전 알림. 30일에 한 번 소개 페이지의 version.json에서 최신 버전 번호만 읽는다.
// 보내는 정보는 없고, 화면에 띄우지 않는다. 새 버전이 있으면 설정 창 맨 아래에만 Update available.
// 설정 창의 Check for updates를 끄면 아예 접속하지 않는다.
@MainActor
enum UpdateCheck {
    static let feed = URL(string: "https://deskon.arapshow.net/version.json")!
    private static let interval: TimeInterval = 30 * 24 * 60 * 60
    private static let defaults = UserDefaults.standard

    /// 마지막으로 확인한 최신 버전이 지금 버전보다 높으면 true.
    static var updateAvailable: Bool {
        guard let latest = defaults.string(forKey: "latestVersion") else { return false }
        return isNewer(latest, than: Guide.version)
    }

    /// 켜져 있고 30일이 지났으면 확인한다. 자주 불러도 된다.
    static func runIfDue() {
        guard Settings.shared.checkUpdates else { return }
        let last = defaults.object(forKey: "lastUpdateCheck") as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= interval else { return }

        var request = URLRequest(url: feed, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("deskON/\(Guide.version)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let latest = json["version"] as? String else { return }
            // 제대로 읽었을 때만 '확인함'으로 친다. 인터넷이 없으면 다음 기회(6시간 뒤)에 다시.
            Task { @MainActor in
                defaults.set(Date(), forKey: "lastUpdateCheck")
                defaults.set(latest, forKey: "latestVersion")
                NotificationCenter.default.post(name: Settings.changed, object: nil)
            }
        }.resume()
    }

    // "1.10" > "1.9"처럼 숫자 단위로 비교한다.
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}

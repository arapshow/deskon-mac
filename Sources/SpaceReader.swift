import AppKit

// 현재 Space 번호 읽기.
// Apple 공식 API가 아니다(WhichSpace·Spaceman과 같은 방식). macOS 업데이트로 깨지면 이 파일만 고친다.

@_silgen_name("_CGSDefaultConnection")
private func _CGSDefaultConnection() -> Int32

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray

struct SpaceInfo {
    let current: Int   // 1부터 센다. Mission Control 위쪽 줄 순서(전체화면 앱 포함).
    let total: Int
}

@MainActor
enum SpaceReader {
    static func read(for screen: NSScreen) -> SpaceInfo? {
        guard let displays = (CGSCopyManagedDisplaySpaces(_CGSDefaultConnection()) as NSArray) as? [[String: Any]],
              !displays.isEmpty else { return nil }

        // '디스플레이마다 별도의 Spaces'가 켜져 있으면 화면마다 목록이 따로 있다. 꺼져 있으면 "Main" 하나.
        let uuid = displayUUID(screen)
        let display = displays.first { id(of: $0)?.caseInsensitiveCompare(uuid ?? "") == .orderedSame }
            ?? displays.first { id(of: $0) == "Main" }
            ?? displays[0]

        guard let spaces = display["Spaces"] as? [[String: Any]],
              let currentSpace = display["Current Space"] as? [String: Any],
              let currentID = currentSpace["ManagedSpaceID"] as? Int else { return nil }

        let ids = spaces.compactMap { $0["ManagedSpaceID"] as? Int }
        guard let index = ids.firstIndex(of: currentID) else { return nil }
        return SpaceInfo(current: index + 1, total: ids.count)
    }

    private static func id(of display: [String: Any]) -> String? {
        display["Display Identifier"] as? String
    }

    private static func displayUUID(_ screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}

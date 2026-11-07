import Foundation
import XCTest
@testable import NXCore

final class GameVirtualClockTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1786786200)
    private let anchor = Date(timeIntervalSince1970: 1780000000)

    func testRestartReplacesOnlyClockKeys() {
        let original = "# game's settings\nDM_LANG=it\nDM_VCLOCK_MODE=continue\nDM_VCLOCK_START=10\nDM_VCLOCK_ANCHOR=20\nDM_AUDIO=1\n"
        let text = GameVirtualClock.replacing(original, mode: .restart, start: start, now: anchor)
        XCTAssertTrue(text.contains("DM_LANG=it\n"))
        XCTAssertTrue(text.contains("DM_AUDIO=1\n"))
        XCTAssertTrue(text.contains("# game's settings\n"))
        XCTAssertTrue(text.contains("DM_VCLOCK_MODE=restart\n"))
        XCTAssertTrue(text.contains("DM_VCLOCK_START=1786786200\n"))
        XCTAssertFalse(text.contains("DM_VCLOCK_ANCHOR="))
        XCTAssertEqual(text.components(separatedBy: "DM_VCLOCK_MODE=").count, 2)
    }

    func testContinueStoresAnchorAndOffRemovesOldValues() {
        let continued = GameVirtualClock.replacing("DM_AUDIO=1\n", mode: .continuous, start: start, now: anchor)
        let parsed = GameVirtualClock.parse(GameVirtualClock.values(in: continued), now: anchor)
        XCTAssertEqual(parsed.mode, .continuous)
        XCTAssertEqual(parsed.start, start)
        XCTAssertEqual(parsed.anchor, anchor)
        XCTAssertTrue(continued.contains("DM_VCLOCK_ANCHOR=1780000000\n"))

        let off = GameVirtualClock.replacing(continued, mode: .off, start: start, now: anchor)
        XCTAssertEqual(GameVirtualClock.values(in: off)["DM_VCLOCK_MODE"], "off")
        XCTAssertFalse(off.contains("DM_VCLOCK_START="))
        XCTAssertFalse(off.contains("DM_VCLOCK_ANCHOR="))
        XCTAssertTrue(off.contains("DM_AUDIO=1\n"))
    }

    func testPlayerSettingsRemainEditableOutsideSignedApp() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = GameVirtualClock(titleID: "0400A3A01EE4C000", support: root)
        try settings.save(mode: .continuous, start: start, now: anchor)
        XCTAssertTrue(FileManager.default.fileExists(atPath: settings.playerEnv.path))
        XCTAssertEqual(settings.load(now: anchor).mode, .continuous)
        XCTAssertEqual(settings.load(now: anchor).start, start)
        try settings.save(mode: .restart, start: start, now: anchor)
        XCTAssertEqual(settings.load(now: anchor).mode, .restart)
    }
}

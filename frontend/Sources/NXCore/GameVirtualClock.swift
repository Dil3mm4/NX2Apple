import Foundation

/// The game's optional wall-clock override, stored in its writable per-title env.txt.
/// The generated app reads that file before starting dmhost, including when opened from Finder.
package enum VirtualClockMode: String, CaseIterable, Identifiable {
    case off
    case restart
    case continuous = "continue"

    package var id: String { rawValue }
}

package struct VirtualClockConfiguration: Equatable {
    package var mode: VirtualClockMode
    package var start: Date
    package var anchor: Date

    package init(mode: VirtualClockMode = .off, start: Date = Date(), anchor: Date = Date()) {
        self.mode = mode
        self.start = start
        self.anchor = anchor
    }
}

/// Writes only DM_VCLOCK_* entries. Other game-specific env settings and comments are preserved.
package struct GameVirtualClock {
    package let titleID: String
    package let appPath: String
    package let support: URL

    package init(titleID: String, appPath: String = "", support: URL? = nil) {
        self.titleID = titleID
        self.appPath = appPath
        self.support = support ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    package var playerEnv: URL {
        support.appendingPathComponent("nxnative").appendingPathComponent(titleID).appendingPathComponent("env.txt")
    }

    package var bundledEnv: URL {
        URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Resources/dm/env.txt")
    }

    private static let keys: Set<String> = ["DM_VCLOCK_MODE", "DM_VCLOCK_START", "DM_VCLOCK_ANCHOR"]

    package static func values(in text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            guard let equal = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<equal])
            if keys.contains(key) { result[key] = String(line[line.index(after: equal)...]) }
        }
        return result
    }

    package static func parse(_ values: [String: String], now: Date = Date()) -> VirtualClockConfiguration {
        let mode = VirtualClockMode(rawValue: values["DM_VCLOCK_MODE"] ?? "") ?? .off
        func date(_ key: String) -> Date? {
            guard let string = values[key], let seconds = TimeInterval(string),
                  seconds >= 0, seconds <= 253402300799 else { return nil }
            return Date(timeIntervalSince1970: seconds)
        }
        return VirtualClockConfiguration(mode: mode, start: date("DM_VCLOCK_START") ?? now,
                                         anchor: date("DM_VCLOCK_ANCHOR") ?? now)
    }

    package func load(now: Date = Date()) -> VirtualClockConfiguration {
        let player = (try? String(contentsOf: playerEnv, encoding: .utf8)) ?? ""
        let bundled = appPath.isEmpty ? "" : ((try? String(contentsOf: bundledEnv, encoding: .utf8)) ?? "")
        // dm/mac/launcher.c uses process environment first, then player env, then app env.
        // For the settings UI, merge the two files with the same player-over-bundle precedence.
        let effective = Self.values(in: bundled).merging(Self.values(in: player)) { _, player in player }
        return Self.parse(effective, now: now)
    }

    package static func replacing(_ existing: String, mode: VirtualClockMode, start: Date, now: Date) -> String {
        var lines = existing.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        lines.removeAll { line in
            guard let equal = line.firstIndex(of: "=") else { return false }
            return keys.contains(String(line[..<equal]))
        }
        lines.append("DM_VCLOCK_MODE=\(mode.rawValue)")
        if mode != .off {
            // The DatePicker selects the local calendar time. Unix seconds keep the instant
            // unambiguous across daylight saving and time-zone transitions.
            lines.append("DM_VCLOCK_START=\(Int64(start.timeIntervalSince1970))")
            if mode == .continuous {
                lines.append("DM_VCLOCK_ANCHOR=\(Int64(now.timeIntervalSince1970))")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    package func save(mode: VirtualClockMode, start: Date, now: Date = Date()) throws {
        // Never overwrite an unreadable existing settings file with an empty one.
        let existing = FileManager.default.fileExists(atPath: playerEnv.path)
            ? try String(contentsOf: playerEnv, encoding: .utf8) : ""
        let updated = Self.replacing(existing, mode: mode, start: start, now: now)
        try FileManager.default.createDirectory(at: playerEnv.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(updated.utf8).write(to: playerEnv, options: .atomic)
    }
}

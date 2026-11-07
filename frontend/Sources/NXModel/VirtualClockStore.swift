import Combine
import Foundation
import NXCore

/// One game's virtual clock, edited from Launch options. Changes apply on the next app launch.
@MainActor package final class VirtualClockStore: ObservableObject {
    @Published package var mode: VirtualClockMode
    @Published package var start: Date
    @Published package private(set) var error: String?
    @Published package private(set) var saved = false

    private let settings: GameVirtualClock

    package init(titleID: String, appPath: String, support: URL? = nil, now: Date = Date()) {
        settings = GameVirtualClock(titleID: titleID, appPath: appPath, support: support)
        let initial = settings.load(now: now)
        mode = initial.mode
        start = initial.start
    }

    package func edited() { saved = false; error = nil }

    package func save(now: Date = Date()) {
        do {
            try settings.save(mode: mode, start: start, now: now)
            error = nil
            saved = true
        } catch {
            self.error = error.localizedDescription
            saved = false
        }
    }

    package func reload(now: Date = Date()) {
        let configuration = settings.load(now: now)
        mode = configuration.mode
        start = configuration.start
        saved = false
        error = nil
    }
}

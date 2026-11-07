import Foundation
import SwiftUI
import NXCore
import NXModel
import NXLauncher

/// Per-game simulated date and time. The game app reads its writable env.txt at startup,
/// so choices also apply when the game is opened directly from Finder or the Dock.
@MainActor struct VirtualClockCard: View {
    let game: LibraryGame
    @StateObject private var clock: VirtualClockStore
    @EnvironmentObject private var loc: Localizer

    init(game: LibraryGame) {
        self.game = game
        _clock = StateObject(wrappedValue: VirtualClockStore(titleID: game.titleID, appPath: game.appPath))
    }

    private var supported: Bool {
        let plist = URL(fileURLWithPath: game.appPath).appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let marker = info["DMVirtualClock"] as? NSNumber else { return false }
        return marker.intValue == 1
    }

    private var explanation: String {
        switch clock.mode {
        case .off: return loc.t("clock.note.off")
        case .restart: return loc.t("clock.note.restart")
        case .continuous: return loc.t("clock.note.continue")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc.t("clock.title"))
                .font(.manrope(15, .semibold)).foregroundStyle(.secondary).padding(.leading, 2)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) {
                    Text(loc.t("clock.mode")).font(.manrope(14, .medium))
                    Spacer(minLength: 12)
                    Picker(loc.t("clock.mode"), selection: $clock.mode) {
                        Text(loc.t("clock.off")).tag(VirtualClockMode.off)
                        Text(loc.t("clock.restart")).tag(VirtualClockMode.restart)
                        Text(loc.t("clock.continue")).tag(VirtualClockMode.continuous)
                    }
                    .labelsHidden().pickerStyle(.menu)
                    .frame(width: 225)
                    .disabled(!supported)
                    .onChange(of: clock.mode) { _ in clock.edited() }
                }
                .padding(.horizontal, 18).padding(.vertical, 13).frame(minHeight: 52)
                if clock.mode != .off {
                    Divider().opacity(0.25).padding(.leading, 18)
                    HStack(spacing: 16) {
                        Text(loc.t("clock.start")).font(.manrope(14, .medium))
                        Spacer(minLength: 8)
                        DatePicker(loc.t("clock.start"), selection: $clock.start,
                                   in: Date(timeIntervalSince1970: 0)...Date(timeIntervalSince1970: 253402300799),
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden().datePickerStyle(.compact)
                            .disabled(!supported)
                            .onChange(of: clock.start) { _ in clock.edited() }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 13).frame(minHeight: 52)
                }
                Divider().opacity(0.25).padding(.leading, 18)
                HStack(alignment: .center, spacing: 14) {
                    Text(explanation).font(.manrope(12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    Button(loc.t("clock.save")) { clock.save() }
                        .buttonStyle(LauncherSecondaryButtonStyle())
                        .disabled(!supported)
                        .padTarget("clock.save", scope: "launch") { if supported { clock.save() } }
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
            }
            .background(LauncherPalette.surface.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.06)))
            if !supported {
                note(loc.t("clock.rebuild"), problem: true)
            } else if let error = clock.error {
                note(String(format: loc.t("clock.failed"), error), problem: true)
            } else {
                note(loc.t(clock.saved ? "clock.saved" : "clock.applies"), problem: false)
            }
        }
    }

    private func note(_ value: String, problem: Bool) -> some View {
        Text(value).font(.manrope(12))
            .foregroundStyle(problem ? Color(red: 1, green: 0.78, blue: 0.24) : Color.secondary)
            .padding(.leading, 2).fixedSize(horizontal: false, vertical: true)
    }
}

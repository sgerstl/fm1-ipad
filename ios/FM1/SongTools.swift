import SloopKit
import SwiftUI

// The Song tab's tools in the top bar (Scott, 2026-11-10, board 47 direction b): everything above the pads in one row.
// Pads: Patterns, Launch at ⌄ (a menu, at the finger), Cancel N waiting. Timeline: Undo (while there's one), Patterns,
// zoom. Words while there's room; as the row narrows (a narrower window, the phone one day, larger text) they give way in
// a fixed order: the "Launch at" words, then Patterns to its icon, then Cancel to ✕ N. Cancel never goes.
// Under the row, the strip: a refusal (with its Stop key), a held scene Lupe hasn't seen, or the Timeline's lanes ending
// apart; it stays until what it says is dealt with.

struct SongTools: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(0); row(1); row(2); row(3)
        }
    }

    /// `level` 0 all words; 1 Launch at without its words; 2 Patterns its icon; 3 Cancel as ✕ N.
    @ViewBuilder private func row(_ level: Int) -> some View {
        HStack(spacing: 8) {
            if ui.songView == .pads && store.performs {
                patterns(icon: level >= 2)
                LaunchKey(session: session, store: store, ui: ui, words: level < 1)
                CancelWaitingKey(session: session, store: store, compact: level >= 3)
            } else {
                if !store.undoStack.isEmpty { undo(icon: level >= 2) }
                patterns(icon: level >= 2)
                TimelineZoom(store: store, ui: ui)
            }
        }
        .fixedSize()
    }

    private func patterns(icon: Bool) -> some View {
        Button { ui.poolOpen.toggle() } label: {
            Group {
                if icon { Image(systemName: "square.grid.2x2").font(.system(size: 17)).frame(width: 44) }
                else { Label("Patterns", systemImage: "square.grid.2x2").font(.lupe(15)).padding(.horizontal, 14) }
            }
            .frame(height: 44).raisedKey()
        }
        .buttonStyle(PressSink(latched: ui.poolOpen))
        .accessibilityLabel("Patterns")
        .accessibilityHint(ui.songView == .pads ? "The pattern pool: every pattern and which tracks use it" : "The pattern pool: drag a pattern into a lane")
    }

    private func undo(icon: Bool) -> some View {
        Button { Task { await store.undo() } } label: {
            Group {
                if icon { Image(systemName: "arrow.uturn.backward").font(.system(size: 17)).frame(width: 44) }
                else { Label("Undo", systemImage: "arrow.uturn.backward").font(.lupe(15)).padding(.horizontal, 14) }
            }
            .frame(height: 44).raisedKey()
        }
        .buttonStyle(PressSink())
        .keyboardShortcut("z", modifiers: .command)
        .disabled(store.busy || store.offline)
        .accessibilityLabel("Undo")
    }
}

/// Launch at: where a pad, a scene or a mute lands while playing, as one key ("Launch at Bar ⌄", or "Bar ⌄" when the row
/// is short) whose menu opens at the finger (Scott, 2026-11-10: a dropdown, not four segments).
struct LaunchKey: View {
    let session: DeviceSession
    let store: SkiffSongStore
    let ui: EditorUI
    var words = true
    @State private var frame: CGRect = .zero

    static let names = ["Loop", "Bar", "Beat", "Now"]
    static let meaning = ["at the end of each track's pass", "on the next bar", "on the next beat", "at once"]

    var body: some View {
        let launch = store.perform?.launch ?? session.launchMode
        Button {
            ui.menu = AppMenu(title: "Launch at", groups: {
                [SongPlayback.Launch.allCases.map { l in
                    MenuItem(title: "\(Self.names[l.rawValue]): \(Self.meaning[l.rawValue])", checked: l == launch) {
                        Task { if await store.performOp(.launch(l)) { session.adoptLaunch(l) } }
                    }
                }]
            }, at: CGPoint(x: frame.midX, y: frame.midY))
        } label: {
            HStack(spacing: 6) {
                if words { Text("Launch at").foregroundStyle(Theme.textSecondary) }
                Text(Self.names[launch.rawValue]).fontWeight(.semibold)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textSecondary)
            }
            .font(.lupe(15))
            .padding(.horizontal, 14).frame(height: 44).raisedKey()
            .contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .disabled(store.offline)
        .globalFrame($frame)
        .accessibilityLabel("Launch at")
        .accessibilityValue(Self.names[launch.rawValue])
        .accessibilityHint("Where a pad, a scene or a mute lands while playing: the end of the track's pass, the next bar, the next beat, or at once")
    }
}

/// Cancel N waiting: every launch and mute still waiting for the launch point, taken back. Never collapses away.
struct CancelWaitingKey: View {
    let session: DeviceSession
    let store: SkiffSongStore
    var compact = false

    var body: some View {
        let waiting = Self.count(session, store)
        Button { Task { await store.performOp(.cancel) } } label: {
            Group {
                if compact {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                        Text("\(waiting)").monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                } else {
                    Text(waiting > 0 ? "Cancel \(waiting) waiting" : "Cancel waiting").padding(.horizontal, 14)
                }
            }
            .font(.lupe(15)).frame(height: 44).raisedKey()
        }
        .buttonStyle(PressSink())
        .disabled(waiting == 0 || store.offline)
        .accessibilityLabel(waiting > 0 ? "Cancel \(waiting) waiting" : "Cancel waiting")
        .accessibilityHint("Takes back every launch and mute still waiting for the launch point")
    }

    /// Launches and mutes waiting for the launch point (the song's own next isn't one).
    @MainActor static func count(_ session: DeviceSession, _ store: SkiffSongStore) -> Int {
        let launches = session.trackIndices.filter { store.marks($0, launchIn: nil).queued != nil || (session.playing && store.launching[$0] != nil) }.count
        return launches + (store.perform?.staged.filter { $0 != .none }.count ?? 0)
    }
}

/// The Timeline's zoom: bars across the lanes.
struct TimelineZoom: View {
    let store: SkiffSongStore
    let ui: EditorUI

    var body: some View {
        let bars = SkiffArrangePage.bars(zoom: ui.timelineZoom, songBars: SkiffArrangePage.songBars(store))
        HStack(spacing: 4) {
            Button { ui.timelineZoom = min(128, bars * 2) } label: {
                Image(systemName: "minus").font(.system(size: 15, weight: .semibold)).frame(width: 44, height: 44).raisedKey()
            }
            .buttonStyle(PressSink()).accessibilityLabel("Zoom out")
            Text("\(bars) bars").font(.lupe(13)).foregroundStyle(Theme.textSecondary).frame(width: 64)
                .accessibilityHidden(true)
            Button { ui.timelineZoom = max(4, bars / 2) } label: {
                Image(systemName: "plus").font(.system(size: 15, weight: .semibold)).frame(width: 44, height: 44).raisedKey()
            }
            .buttonStyle(PressSink()).accessibilityLabel("Zoom in")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zoom, \(bars) bars across")
    }
}

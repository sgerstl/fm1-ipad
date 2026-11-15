import SloopKit
import SwiftUI

// The phone's sheets (vault decisions 28, 33, 34; Android's LupeSheet, MixPage, SoundsBrowser and ProjectsSheet): they
// rise from the foot over the page, which dims, in 300 ms ease-out and fall in 200 ms ease-in (Reduce Motion: a fade);
// a tap on the dimmed page or the close key sends them away. (The Mix pop-up went with decision 44: GLO's pages are the
// sound panel's now.) Sounds is the track's (or a pad's) sound browser, from the head's
// hold menu or SAVE on the FM-1; Projects is the FM-1's four slots. iPhone only.

/// A sheet's frame: the dim behind it, the surface rising from the foot, a fixed height.
struct PhoneSheetFrame<Content: View>: View {
    let open: Bool
    let height: CGFloat
    let label: String
    let close: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            if open {
                Color.black.opacity(0.45).ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
                    .accessibilityHidden(true)
                    .transition(.opacity)
                content()
                    .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 8)
                    .frame(maxWidth: .infinity).frame(height: height, alignment: .top)
                    .background {
                        UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 16)
                            .fill(Theme.panel).ignoresSafeArea(edges: [.bottom, .horizontal])
                            .shadow(color: .black.opacity(0.5), radius: 16, y: -4)
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(label)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape) { close() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : open ? .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.3) : .easeIn(duration: 0.2), value: open)
    }
}

/// The sheet's close key: a round ✕, 44 pt.
struct SheetClose: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36).background(Circle().fill(Theme.control))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(PressSink())
        .accessibilityLabel(label)
        .keyboardShortcut(.cancelAction)
    }
}

extension UserDefaults {
    func bool(forKey key: String, default d: Bool) -> Bool { object(forKey: key) == nil ? d : bool(forKey: key) }
}

// MARK: - Sounds

/// The track's sound browser (or one pad's, when a pad's hold menu chose it): the engines down the left, the presets
/// beside them; Done closes.
struct PhoneSoundsSheet: View {
    let session: DeviceSession
    let ui: EditorUI

    var body: some View {
        let t = session.selectedTrack
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TrackChip(track: t, size: 28)
                Text(ui.soundEntry.map { "T\(t + 1) · pad \(Entries.letter($0.ref.entry)) sound" }
                     ?? (session.isDrums(t) ? "T\(t + 1) kit" : "T\(t + 1) sound · \(Entries.trackName(t, session: session))"))
                    .font(.lupe(17, .semibold)).lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                SheetClose(label: "Close the sounds") { ui.presetsPanel = false }
            }
            HStack(alignment: .top, spacing: 8) {
                if !session.isDrums(t) { LibraryEngines(session: session, ui: ui).frame(width: 180) }
                LibraryPage(session: session, ui: ui, columns: 2)
            }
        }
    }
}

// MARK: - Projects: the FM-1's four slots

struct PhoneProjectsSheet: View {
    let session: DeviceSession
    let ui: EditorUI
    @State private var menu: AppMenu?
    @State private var prompt: TextPrompt?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Projects").font(.lupe(17, .semibold)).accessibilityAddTraits(.isHeader)
                Text("on the FM-1").font(.lupe(13)).foregroundStyle(Theme.textSecondaryRaised)
                Spacer(minLength: 0)
                SheetClose(label: "Close Projects") { ui.projectsOpen = false }
            }
            List { SkiffProjectSlots(session: session, menu: $menu, prompt: $prompt) }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
        }
        .overlay { AppMenuLayer(menu: $menu) }
        .overlay { TextPromptLayer(prompt: $prompt) }
    }
}

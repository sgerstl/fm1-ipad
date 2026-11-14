import SloopKit
import SwiftUI

// The phone's sheets (vault decisions 28, 33, 34; Android's LupeSheet, MixPage, SoundsBrowser and ProjectsSheet): they
// rise from the foot over the page, which dims, in 300 ms ease-out and fall in 200 ms ease-in (Reduce Motion: a fade);
// a tap on the dimmed page or the close key sends them away. Mix is the GLO pop-up of board 77: no title, its tabs in
// line with the close key, the room given to the page; Sounds is the track's (or a pad's) sound browser, from the head's
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

// MARK: - Mix: the GLO pop-up (board 77)

struct PhoneMixPopup: View {
    let session: DeviceSession
    let ui: EditorUI
    @State private var marks = ShapeMarks()
    @Namespace private var line
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shared = SoundPage.pages(session).filter { $0.family == .glo }
        let tab = ui.mixerSection
        VStack(alignment: .leading, spacing: 8) {
            // the tabs in line with the close key (decision 31): words with the white underline, as the header's
            HStack(spacing: 20) {
                ForEach(SkiffButtonMap.MixerTab.allCases) { t in
                    let on = tab == t
                    Button { show(t) } label: {
                        Text(t.title).font(.lupe(15, .semibold))
                            .foregroundStyle(on ? Theme.text : Theme.textSecondary)
                            .frame(height: 44)
                            .overlay(alignment: .bottom) {
                                if on { Rectangle().fill(Theme.text).frame(height: 3).padding(.bottom, 4).matchedGeometryEffect(id: "mixline", in: line) }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
                Spacer(minLength: 0)
                SheetClose(label: "Close Mix") { ui.mixPopup = false }
            }
            .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.2), value: tab)
            Group {
                if tab == .mixer || shared.isEmpty {
                    PhoneMixerRows(session: session, ui: ui, touched: { show(.mixer) })
                } else if let p = shared.first(where: { $0.title == tab.pageTitle }) {
                    // board 77: the four dials two by two at the left, the picture at the right in the FM-1's 1.7 : 1, in the
                    // global greys (decision 34: a shared page sets every track; PageGraph draws scope 1 in grey)
                    HStack(alignment: .top, spacing: 14) {
                        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                            GridRow { cell(p, 0); cell(p, 1) }
                            GridRow { cell(p, 2); cell(p, 3) }
                        }
                        .frame(maxWidth: .infinity)
                        if showGraphics, FM1Picture.titles.contains(p.title) {
                            FM1Picture(session: session, page: p)
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.well))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if showGraphics, PageGraph.has(p, session) {
                            PageGraph(session: session, page: p, rows: [p], hot: nil, modRoute: .constant(0))
                                .padding(6)
                                .aspectRatio(936.0 / 552.0, contentMode: .fit)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.well))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .id(p.id)
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: tab)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onChange(of: tab) { _, t in if let p = shared.first(where: { $0.title == t.pageTitle }) { ui.focus(p) } }
    }

    @AppStorage(ShowGraphics.key) private var showGraphics = ShowGraphics.standard

    /// A dial on its control-grey tile (board 77); an empty knob only an outline.
    private func cell(_ p: SoundPage, _ k: Int) -> some View {
        let empty = (p.ids[safe: k] ?? nil) == nil
        return PageDial(session: session, ui: ui, page: p, slot: k, marks: marks)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background {
                if empty { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.stepEmpty, lineWidth: 1.5) }
                else { RoundedRectangle(cornerRadius: 10).fill(Theme.control) }
            }
    }

    private func show(_ t: SkiffButtonMap.MixerTab) {
        if ui.mixerSection != t { ui.mixerSection = t }
        let there = session.deviceScreen.map { !$0.home && $0.page == t.page } == true
        if session.screenLinked, ui.followDevice, !there { session.showOnDevice(page: t.page) }
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

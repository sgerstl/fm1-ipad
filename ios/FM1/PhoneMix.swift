import SloopKit
import SwiftUI

// Skiff's Mix on the phone (design/structure-map.md › "The phone with a Skiff FM-1", boards 48 and 49, Scott
// 2026-11-10). The iPad's six strips over four effect cards don't fit 393 pt, so the phone shows one of GLO's five pages
// at a time, picked down the left in the FM-1's order: MIXER (the six tracks as rows), DELAY, REVERB, CHORUS, GLOBAL
// (the iPad's own cards). GLO on the FM-1 steps them, as it steps the iPad's sections; linked, the page picked here
// goes to the FM-1.

struct PhoneMix: View {
    let session: DeviceSession
    let ui: EditorUI
    @State private var marks = ShapeMarks()

    static let selectorWidth: CGFloat = 112

    var body: some View {
        let shared = SoundPage.pages(session).filter { $0.family == .glo }
        let tab = ui.mixerSection
        HStack(alignment: .top, spacing: 12) {
            selector
            Group {
                if tab == .mixer || shared.isEmpty {
                    PhoneMixerRows(session: session, ui: ui, touched: { show(.mixer) })
                } else if let p = shared.first(where: { $0.title == tab.pageTitle }) {
                    ScrollView {
                        SoundCard(session: session, ui: ui, rows: [p], pages: glo(shared), marks: marks).equatable()
                            .id(p.id)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.bottom, 8)
        .onChange(of: tab) { _, t in
            // the card's page is the knobs' (the FM-1's knobs turn what's shown)
            if let p = shared.first(where: { $0.title == t.pageTitle }) { ui.focus(p) }
        }
    }

    /// MIXER DELAY REVERB CHORUS GLOBAL down the left: the one shown lit; a tap shows it (and, linked, on the FM-1).
    private var selector: some View {
        VStack(spacing: 8) {
            ForEach(SkiffButtonMap.MixerTab.allCases) { t in
                let on = ui.mixerSection == t
                Button { show(t) } label: {
                    HStack(spacing: 8) {
                        LED(on: on)
                        Text(t.title).font(.lupe(13, on ? .semibold : .regular))
                            .foregroundStyle(on ? Theme.text : Theme.textSecondaryRaised)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background { if on { Color.clear.selectedKey(8) } else { Color.clear.raisedKey(8) } }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .accessibilityLabel(t.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .frame(width: Self.selectorWidth)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mix pages")
    }

    /// GLO's five pages as the FM-1 counts them (MIXER first), so a card's "On the FM-1" reads as its screen does.
    private func glo(_ shared: [SoundPage]) -> [SoundPage] {
        [SoundPage(fw: SkiffButtonMap.MixerTab.mixer.page, title: "MIXER", family: .glo, scope: 1, ids: [nil, nil, nil, nil])] + shared
    }

    private func show(_ t: SkiffButtonMap.MixerTab) {
        if ui.mixerSection != t { ui.mixerSection = t }
        let there = session.deviceScreen.map { !$0.home && $0.page == t.page } == true
        if session.screenLinked, ui.followDevice, !there { session.showOnDevice(page: t.page) }
    }
}

/// MIXER on the phone: the six tracks as rows (board 48), like the Pads rows: the number and name (tap: select), LEVEL,
/// PAN and the REVERB send as the iPad strip's faders laid across, Mute.
struct PhoneMixerRows: View {
    let session: DeviceSession
    let ui: EditorUI
    var touched: () -> Void = {}

    var body: some View {
        let strips = MixerStrips(session: session, ui: ui, touched: touched)
        let id = strips.revID
        VStack(spacing: 4) {
            ForEach(Array(session.trackIndices), id: \.self) { t in
                PhoneMixerRow(session: session, row: strips.row(t, id), touched: touched).equatable()
            }
            Spacer(minLength: 0)
        }
        // every track's REVERB, read on opening and every few seconds (the protocol doesn't push other tracks')
        .task(id: id) {
            guard let id else { return }
            while !Task.isCancelled {
                await session.readEveryTrack(id: id)
                try? await Task.sleep(for: .seconds(3))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mixer")
    }
}

private struct PhoneMixerRow: View, Equatable {
    let session: DeviceSession
    let row: MixRow
    let touched: () -> Void

    nonisolated static func == (a: PhoneMixerRow, b: PhoneMixerRow) -> Bool { a.session === b.session && a.row == b.row }

    var body: some View {
        let t = row.track, colour = Theme.track[t]
        HStack(spacing: 10) {
            Button { session.select(track: t) } label: {
                HStack(spacing: 8) {
                    TrackChip(track: t, selected: row.selected).frame(width: 28, height: 28)
                    Text(row.name).font(.lupe(13, row.selected ? .semibold : .regular))
                        .foregroundStyle(row.selected ? Theme.text : Theme.textSecondaryRaised)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                }
                .frame(width: 92).frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Track \(t + 1), \(row.name)")
            .accessibilityHint("Selects the track")
            .accessibilityAddTraits(row.selected ? .isSelected : [])
            Fader(axis: .horizontal, spec: row.levelSpec(session), tint: row.mute ? Theme.textTertiary : colour, nudge: 2,
                  detent: MixerStrips.unity, touched: touched)
                .frame(minWidth: 120, maxWidth: .infinity)
            Fader(axis: .horizontal, spec: row.panSpec(session), tint: colour, touched: touched)
                .frame(width: 84)
            if row.rev != nil {
                Fader(axis: .horizontal, spec: row.revSpec(session), tint: colour, touched: touched)
                    .frame(width: 84)
            }
            Button { session.set(track: t, param: Param.mute, to: row.mute ? 0 : 1) } label: {
                Image(systemName: row.mute ? "speaker.slash.fill" : "speaker.wave.2.fill").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(row.mute ? Theme.onColour : Theme.text)
                    .frame(width: 40, height: 40)
                    .background { HeadKeySurface(on: row.mute, onColour: Theme.text) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressSink())
            .accessibilityLabel("Mute track \(t + 1)")
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(row.mute ? "muted" : "playing")
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 10).fill(row.selected ? SelectionTint.fill(t) : Theme.well))
        .accessibilityElement(children: .contain)
    }
}

import SloopKit
import SwiftUI

/// Shape on the iPhone (2026-11-04): the FM-1's buttons as a strip, then that button's pages side by side
/// with the active one in the middle. A swipe snaps the next page into the centre with a little bounce,
/// a flick runs through several; the centred page is the active one (lit, and shown on the FM-1), so
/// there's no tap-to-activate as on the iPad, where every page is in view at once. The neighbours peek in
/// at both sides, a little smaller; a tap on one brings it to the centre.
struct PhoneShape: View {
    let session: DeviceSession
    let ui: EditorUI
    @State private var centred: String?
    @State private var followed: UIState?       // the FM-1's screen as last followed
    @State private var width: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pages = SoundPage.shown(session, ui.soundFamily)
        VStack(spacing: 8) {
            strip
            if pages.isEmpty {
                DrumNoPages(session: session, ui: ui, family: ui.soundFamily)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                carousel(pages)
                dots(pages)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onAppear {
            followed = session.deviceScreen
            centred = devicePage(in: pages) ?? pages.first?.id
        }
        .onChange(of: ui.soundFamily) { _, f in
            let p = SoundPage.shown(session, f)
            centred = devicePage(in: p) ?? p.first?.id
        }
        .onChange(of: session.deviceScreen) { _, s in followScreen(s) }
    }

    // MARK: The buttons

    private var strip: some View {
        HStack(spacing: 4) {
            ForEach(SoundFamily.allCases) { f in
                let on = ui.soundFamily == f
                Button {
                    ui.soundFamily = f
                    if session.screenLinked, ui.followDevice, let first = SoundPage.reached(session, f).first {
                        session.showOnDevice(page: first.fw)
                    }
                } label: {
                    HStack(spacing: 6) {
                        if on { LED(on: true) }
                        Text(f.rawValue).font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(on ? Theme.text : Theme.textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background { if on { Color.clear.recessed(9) } else { Color.clear.raisedKey() } }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressSink())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("FM-1 buttons")
    }

    // MARK: The pages

    private func carousel(_ pages: [SoundPage]) -> some View {
        let pageWidth = min(420, max(280, (width * 0.56).rounded()))
        return ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(pages) { p in
                    page(p, of: pages, active: centred == p.id)
                        .frame(width: pageWidth)
                        .scrollTransition(.interactive, axis: .horizontal) { c, phase in
                            c.scaleEffect(phase.isIdentity ? 1 : 0.92)
                        }
                        .id(p.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centred, anchor: .center)
        .contentMargins(.horizontal, max(0, (width - pageWidth) / 2), for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(maxHeight: .infinity)
        .onChange(of: centred) { _, id in
            // the page swiped into the middle is the one the FM-1 shows
            guard let id, let p = pages.first(where: { $0.id == id }), session.screenLinked, ui.followDevice,
                  session.deviceScreen.map({ !$0.home && $0.page == p.fw }) != true else { return }
            session.showOnDevice(page: p.fw)
        }
    }

    private func page(_ p: SoundPage, of pages: [SoundPage], active: Bool) -> some View {
        let onDevice = session.screenLinked && session.deviceScreen.map { !$0.home && $0.page == p.fw } == true
        let lit = session.screenLinked ? onDevice : active
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                LED(on: lit)
                Text(p.title(session)).font(.system(size: 15, weight: .semibold))
                if onDevice, let k = pages.firstIndex(where: { $0.fw == p.fw }) {
                    Text("On the FM-1 · \(k + 1)/\(pages.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.10)))
                }
                if p.scope == 1 { Text("all tracks").font(.system(size: 12)).foregroundStyle(Theme.textSecondary) }
                Spacer(minLength: 0)
            }
            .frame(height: 24)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            graph(for: p)
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { slot in
                    if let id = p.ids[slot] {
                        KnobControl(ui: ui, size: 56) { KnobSpec.param(session, scope: p.scope, id: id, slot: slot) }
                            .frame(maxWidth: .infinity)
                    } else {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1).accessibilityHidden(true)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .panel()
        // the page on the FM-1's screen (or, unlinked, the centred one): a lit edge along the top
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 1.5).fill(Theme.text)
                .frame(height: 3).padding(.horizontal, 14).offset(y: 1)
                .shadow(color: Theme.text.opacity(0.7), radius: 6)
                .opacity(lit ? 1 : 0)
                .animation(.easeOut(duration: 0.15), value: lit)
                .accessibilityHidden(true)
        }
        // a peeking page takes a tap anywhere on it and comes to the middle; its knobs work once it's there
        .overlay {
            if !active {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82)) { centred = p.id } }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityAction(named: "Show on the FM-1") { centred = p.id }
    }

    /// ENV's shape and the LFO's wave, as the FM-1 draws them on those pages, shorter than the iPad's.
    @ViewBuilder private func graph(for p: SoundPage) -> some View {
        let v = session.params
        let colour = Theme.track[session.selectedTrack]
        let turning = ui.knobGrab.flatMap { g in p.ids.firstIndex { $0.map { "s0.\($0)" } == g.id } }
        if p.fw == 0, v.count > 4 {
            EnvelopeGraph(attack: v[1], decay: v[2], sustain: v[3], release: v[4], colour: colour, active: turning)
                .frame(height: 56).padding(.horizontal, 4).recessed(10)
        } else if p.fw == 2, v.count > 11 {
            LFOGraph(wave: v[10], phase: v[11], colour: colour)
                .frame(height: 56).padding(.horizontal, 4).recessed(10)
        }
    }

    private func dots(_ pages: [SoundPage]) -> some View {
        HStack(spacing: 5) {
            ForEach(pages) { p in
                Capsule().fill(centred == p.id ? Theme.text : Theme.ledOff)
                    .frame(width: centred == p.id ? 14 : 6, height: 6)
            }
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }

    // MARK: Following the FM-1

    private func devicePage(in pages: [SoundPage]) -> String? {
        guard session.screenLinked, let s = session.deviceScreen, !s.home else { return nil }
        return pages.first { $0.fw == s.page }?.id
    }

    /// The FM-1 changed page (a button pressed on it): bring up that button and centre that page. Only a
    /// real change moves anything, so the same screen reported again never undoes a swipe here.
    private func followScreen(_ s: UIState?) {
        guard let s, s.home != followed?.home || s.page != followed?.page || s.layer != followed?.layer else { return }
        followed = s
        if s.layer == 5 { ui.soundFamily = .sel; return }              // SEL held
        guard !s.home, let page = SoundPage.page(fw: s.page),
              SoundPage.reached(session, page.family).contains(where: { $0.fw == page.fw }) else { return }
        if ui.soundFamily != page.family { ui.soundFamily = page.family }
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82)) { centred = page.id }
    }
}

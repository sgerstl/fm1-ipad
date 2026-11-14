import SwiftUI

// The phone's tab change with the track thread (design/boards/tab-thread.html, Scott 2026-11-14; Android's TabPager):
// going right (Pads → Edit → Timeline) the old page leaves to the left and the new one comes in from the right, and back
// the other way, ease-out over Labs › Tab change (380 ms), the outgoing page done at 85 % of it. The selected track's
// 2 pt outline in its colour travels from where the old tab shows the track (Pads: its row; Edit: the step grid; the
// Timeline: its lane) to where the new one does, on the same curve, then fades. No scale, no overshoot. Reduce Motion:
// the pages cross-fade (150 ms) and the outline cross-fades between its two places.

/// Where each tab shows the selected track, in the pager's space.
struct PhoneTrackAnchorKey: PreferenceKey {
    static let defaultValue: [PhoneTab: CGRect] = [:]
    static func reduce(value: inout [PhoneTab: CGRect], nextValue: () -> [PhoneTab: CGRect]) { value.merge(nextValue()) { $1 } }
}

private struct PhoneTabPageKey: EnvironmentKey { static let defaultValue: PhoneTab? = nil }
private struct PhonePageOffsetKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues {
    /// The tab a view is drawn on (nil outside the phone's pager).
    var phoneTabPage: PhoneTab? { get { self[PhoneTabPageKey.self] } set { self[PhoneTabPageKey.self] = newValue } }
    /// How far its page is slid right now, taken off what it reports so the anchor is where the page rests.
    var phonePageOffset: CGFloat { get { self[PhonePageOffsetKey.self] } set { self[PhonePageOffsetKey.self] = newValue } }
}

extension View {
    /// Marks this as where the page shows the selected track (the thread lands on it). Nothing outside the pager.
    func phoneTrackAnchor() -> some View { modifier(PhoneTrackAnchor()) }
}

private struct PhoneTrackAnchor: ViewModifier {
    @Environment(\.phoneTabPage) private var tab
    @Environment(\.phonePageOffset) private var offset
    func body(content: Content) -> some View {
        content.background {
            if let tab {
                GeometryReader { g in
                    Color.clear.preference(key: PhoneTrackAnchorKey.self,
                                           value: [tab: g.frame(in: .named(PhoneTabPager<EmptyView>.space)).offsetBy(dx: -offset, dy: 0)])
                }
            }
        }
    }
}

struct PhoneTabPager<Content: View>: View {
    static var space: String { "phoneTabPager" }
    let tab: PhoneTab
    let colour: Color
    @ViewBuilder let content: (PhoneTab) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown: PhoneTab?
    @State private var from: PhoneTab?
    @State private var inP: CGFloat = 1          // the incoming page, 0…1
    @State private var outP: CGFloat = 1         // the outgoing page, 0…1 (done at 85 % of the time)
    @State private var anchors: [PhoneTab: CGRect] = [:]
    @State private var thread: CGRect?
    @State private var threadFrom: CGRect?       // Reduce Motion: the old place, fading out
    @State private var threadAlpha: CGFloat = 0
    @State private var run = 0

    var body: some View {
        let now = shown ?? tab
        GeometryReader { g in
            let w = g.size.width
            let dir: CGFloat = (from?.rawValue ?? now.rawValue) <= now.rawValue ? 1 : -1
            ZStack(alignment: .topLeading) {
                if let f = from {
                    let x = reduceMotion ? 0 : -dir * w * outP
                    page(f, offset: x)
                        .opacity(reduceMotion ? 1 - outP : 1 - 0.4 * outP)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                let x = reduceMotion || from == nil ? 0 : dir * w * (1 - inP)
                page(now, offset: x)
                    .opacity(reduceMotion && from != nil ? inP : 1)
                // the thread: one outline easing between the two places; with Reduce Motion the two cross-fading
                if let r = threadFrom { outline(r).opacity(threadAlpha == 0 ? 0 : 1 - inP) }
                if let r = thread { outline(r).opacity(threadAlpha) }
            }
        }
        .clipped()
        .coordinateSpace(name: Self.space)
        .onPreferenceChange(PhoneTrackAnchorKey.self) { v in anchors.merge(v) { $1 } }
        .onChange(of: tab) { old, new in go(from: shown ?? old, to: new) }
    }

    private func page(_ t: PhoneTab, offset: CGFloat) -> some View {
        content(t)
            .environment(\.phoneTabPage, t)
            .environment(\.phonePageOffset, offset)
            .offset(x: offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .id(t)
    }

    private func outline(_ r: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 9).strokeBorder(colour, lineWidth: 2)
            .frame(width: r.width, height: r.height)
            .offset(x: r.minX, y: r.minY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func go(from old: PhoneTab, to new: PhoneTab) {
        guard old != new else { return }
        run += 1
        let me = run
        let dur = reduceMotion ? 0.15 : Labs.tabChange.value
        let a = anchors[old]
        // the new page in its starting place, the thread on the old tab's track
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            from = old; shown = new; inP = 0; outP = 0
            thread = reduceMotion ? nil : a
            threadFrom = reduceMotion ? a : nil
            threadAlpha = a == nil ? 0 : 1
        }
        Task { @MainActor in
            // a frame for the new page to lay out and say where its track is
            try? await Task.sleep(for: .milliseconds(16))
            guard me == run else { return }
            let b = anchors[new]
            if reduceMotion {
                withTransaction(t) { thread = b; threadAlpha = 0 }
                withAnimation(.easeOut(duration: dur)) { inP = 1; outP = 1; if b != nil { threadAlpha = 1 } }
            } else {
                if a == nil, let b { withTransaction(t) { thread = b } }
                let curve = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: dur)
                withAnimation(curve) { inP = 1; if let b { thread = b; threadAlpha = 1 } else { threadAlpha = 0 } }
                withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: dur * 0.85)) { outP = 1 }
            }
            try? await Task.sleep(for: .seconds(dur))
            guard me == run else { return }
            withTransaction(t) { from = nil; threadFrom = nil }
            // landed: the page's own selection takes over (the lane's tint), the outline fades
            withAnimation(.easeIn(duration: 0.15)) { threadAlpha = 0 }
        }
    }
}

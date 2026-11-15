import SkiffDraw
import SkiffDrawLink
import SloopKit
import SwiftUI

/// Decision 45's spike (2026-11-15), shown only with the launch argument `-skiffdraw-spike`: the FM-1's screen drawn by
/// Skiff-Lupe 2.5.1's own UI code (the SkiffDraw package), fed by a mirror of what the session already reads. Not a
/// screen of the app: it replaces the root view only under that argument. Verdict: qa/scope-spike-2026-11-15.md.
struct SkiffDrawSpike: View {
    let session: DeviceSession

    private enum Shown: String, CaseIterable, Identifiable {
        case gloDelay = "GLO › DELAY", gloReverb = "GLO › REVERB", editScope = "EDIT 1 (scope)", homeScope = "HOME scope",
             follow = "Follow FM-1"
        var id: String { rawValue }
    }

    @State private var mirror = SkiffMirror()
    @State private var shown: Shown = Self.initialShown
    @State private var palette = Self.initialPalette
    @State private var scopeId = UUID()
    @State private var scopeCount = 0
    @State private var scopeRate = 0.0
    @State private var rateFrom = Date.now
    @Environment(\.displayScale) private var displayScale

    private static var initialShown: Shown {
        let a = LaunchArgs.all
        if let i = a.firstIndex(of: "-skiffdraw-page"), a.indices.contains(i + 1) {
            return [Shown.gloDelay, .gloReverb, .editScope, .homeScope, .follow][min(4, max(0, Int(a[i + 1]) ?? 0))]
        }
        return .gloDelay
    }
    private static var initialPalette: Int {
        let a = LaunchArgs.all
        if let i = a.firstIndex(of: "-skiffdraw-theme"), a.indices.contains(i + 1), let p = Int(a[i + 1]) { return p }
        return 0
    }

    var body: some View {
        GeometryReader { geo in
            // whole device pixels per FM-1 pixel, so every FM-1 pixel is the same size
            let k = max(1, floor((geo.size.height - 32) * displayScale / 240))
            let side = 240 * k / displayScale
            HStack(alignment: .top, spacing: 24) {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { t in
                    frame(at: t.date)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: side, height: side)
                        .accessibilityLabel("The FM-1's screen, drawn by Skiff's own code: \(shown.rawValue)")
                }
                controls
            }
            .padding(16)
        }
        .background(Theme.page)
        .onAppear { session.showScope(scopeId, true) }
        .onDisappear { session.showScope(scopeId, false) }
        .onChange(of: session.scope.frame) { _, _ in scopeCount += 1 }
    }

    private func frame(at date: Date) -> Image {
        let s = mirror.screen
        mirror.followDevice = shown == .follow
        mirror.fill(from: session, palette: palette)
        switch shown {
        case .gloDelay: s.show(page: s.page(named: "DELAY", nth: 1) ?? 0)
        case .gloReverb: s.show(page: s.page(named: "REVERB", nth: 1) ?? 0)
        case .editScope: s.show(page: s.page(named: "EDIT 1") ?? 0)
        case .homeScope: s.showHome(scope: true)
        case .follow: break
        }
        if let img = s.renderImage() { return Image(decorative: img, scale: 1) }
        return Image(systemName: "xmark")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Skiff's own drawing (spike)")
                .font(.lupe(17, .semibold))
                .foregroundStyle(Theme.text)
            Picker("Page", selection: $shown) {
                ForEach(Shown.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            Picker("Theme", selection: $palette) {
                ForEach(Array(mirror.screen.paletteNames.enumerated()), id: \.offset) { Text($0.element).tag($0.offset) }
            }
            .pickerStyle(.menu)
            TimelineView(.periodic(from: .now, by: 1)) { t in
                stats(t.date)
            }
        }
        .frame(maxWidth: 320, alignment: .leading)
    }

    private func stats(_ now: Date) -> some View {
        let st = mirror.stats
        let dt = now.timeIntervalSince(rateFrom)
        if dt >= 1 {
            DispatchQueue.main.async {
                scopeRate = Double(scopeCount) / dt
                scopeCount = 0
                rateFrom = now
            }
        }
        // SCOPE on the wire: 120 points + the frame's 6 bytes (F0 7D cmd … F7), 3 bytes a USB-MIDI packet of SysEx
        let wire = scopeRate * 126 / 3 * 4
        return VStack(alignment: .leading, spacing: 4) {
            Text("Mirror: \(st.globals) globals, \(st.selectedParams) of the selected track's parameters, \(st.otherTrackParams) of the other tracks', \(st.meters) meters, \(st.scopePoints) scope points")
            Text("Draw: \(mirror.screen.lastDrawMicroseconds) µs a frame")
            Text(String(format: "SCOPE: %.1f a second, about %.0f bytes a second over USB", scopeRate, wire))
            Text("Track \((session.deviceScreen?.track ?? session.selectedTrack) + 1), engine \(session.tracks[session.selectedTrack].engine)")
        }
        .font(.lupe(13))
        .foregroundStyle(Theme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

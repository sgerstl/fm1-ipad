import SloopKit
import SwiftUI

/// The FM-1's keyboard on the iPad: 16 keys from F3 along the bottom and 11 above, as on the
/// device, rubber membrane keys with a slit of white light. It plays the selected track over MIDI (channel 16:
/// GLO > MIDI > OTHER = SEL). On the drum track, white key k plays lane k and a black key the lane of
/// the white key to its left, as on the device. A key lights while pressed here or on the FM-1 (the
/// notes its keys send), and dimmer while the selected track plays its note. The FM-1 lights its own
/// keys for the iPad's notes by itself (drums always; synths with MENU > LIGHTS > NOTES on).
struct KeyboardDrawer: View {
    let session: DeviceSession
    let ui: EditorUI

    /// White keys from F3: F G A B C D E, twice, then F G.
    static let whiteOffsets = [0, 2, 4, 6, 7, 9, 11, 12, 14, 16, 18, 19, 21, 23, 24, 26]   // semitones above F
    /// A black key sits after these white keys (index into the 16).
    static let blackAfter = [0, 1, 2, 4, 5, 7, 8, 9, 11, 12, 14]

    var body: some View {
        let drums = session.selectedIsDrums
        VStack(spacing: 12) {
            header(drums)
            keys(drums)
        }
        .padding(16)
        .panel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keyboard")
    }

    private func header(_ drums: Bool) -> some View {
        HStack(spacing: 16) {
            Text("Keys").font(.system(size: 17, weight: .semibold))
            if drums {
                Text("Drums: one sound per white key").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
            } else {
                // the FM-1's OCT buttons; the iPad follows them when you play the FM-1's keys
                StepperKeys(label: "Octave", value: session.keyboardOctave, range: -3...3, step: 1,
                            format: { o in o == 0 ? "OCT 0" : String(format: "OCT %+d", o) }) {
                    session.keyboardOctave = $0
                }
            }
            if !session.otherChannelsPlaySelected {
                Text("GLO > MIDI > OTHER is OFF on the FM-1, so these keys play nothing. Set it to SEL.")
                    .font(.system(size: 13)).foregroundStyle(Theme.text)
            }
            Spacer()
            Button { ui.keyboardOpen = false } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44).raisedKey(22)
            }
            .buttonStyle(PressSink())
            .accessibilityLabel("Close keyboard")
        }
    }

    /// As on the FM-1 (photo, 2026-10-31): every key the same rubber pill. 16 along the bottom, 11
    /// above in the piano's 3-2-3-2-1 groups, each half a key over. Unlike the device, the rows don't
    /// overlap (Scott's call): each key is a whole target.
    private func keys(_ drums: Bool) -> some View {
        let sounding = session.sounding
        let deviceNotes = session.deviceNotes
        let onDeviceLanes = Set(deviceNotes.map(session.keyID(forDeviceNote:)))
        // Synth keys are FM-1 key positions (0 = F3 ... 26 = G5): each plays what the FM-1's key would
        // (transpose, SNAP / WHITE, OCT), so both keyboards light for the same notes.
        func pitch(_ k: Int) -> Int? { session.pitch(ofKey: k) }
        func name(_ k: Int) -> String { pitch(k).map(Music.noteName) ?? "" }
        func spoken(_ k: Int) -> String { pitch(k).map(Music.spokenNoteName) ?? "silent" }
        return GeometryReader { geo in
            let spacing = geo.size.width / 16, keyW = spacing * 0.74
            let topH: CGFloat = 94, bottomH: CGFloat = 94, bottomY = geo.size.height - bottomH   // a gap between rows, no overlap
            ZStack(alignment: .topLeading) {
                ForEach(Self.blackAfter, id: \.self) { k in
                    let key = Self.whiteOffsets[k] + 1
                    let id = drums ? k : key         // drums: the lane of the white key to its left, as on the device
                    let p = pitch(key)
                    MembraneKey(name: "", spoken: drums ? Music.drumLanes[k] : spoken(key),
                                lit: !drums && p.map(sounding.contains) == true,
                                held: drums ? onDeviceLanes.contains(k) : p.map(deviceNotes.contains) == true,
                                silent: !drums && p == nil,
                                down: { session.keyDown(id) }, up: { session.keyUp(id) })
                        .frame(width: keyW, height: topH)
                        .offset(x: CGFloat(k + 1) * spacing - keyW / 2, y: 0)
                }
                ForEach(0..<16, id: \.self) { k in
                    let key = Self.whiteOffsets[k]
                    let id = drums ? k : key
                    let p = pitch(key)
                    MembraneKey(name: drums ? Music.drumLanes[k] : name(key),
                                spoken: drums ? Music.drumLanes[k] : spoken(key),
                                lit: drums ? sounding.contains(k) : p.map(sounding.contains) == true,
                                held: drums ? onDeviceLanes.contains(k) : p.map(deviceNotes.contains) == true,
                                down: { session.keyDown(id) }, up: { session.keyUp(id) })
                        .frame(width: keyW, height: bottomH)
                        .offset(x: CGFloat(k) * spacing + (spacing - keyW) / 2, y: bottomY)
                }
            }
        }
        .frame(height: 206)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        // the membrane sheet the keys rise out of: nearly the keys' own charcoal
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(hex: 0x1A1A1D)).recessed(22))
        .accessibilityAddTraits(.allowsDirectInteraction)
    }
}

/// A membrane key: a matte rubber pill with a soft top highlight, set into the tray; a slit down
/// its middle that lights white.
private struct MembraneKey: View {
    let name: String
    let spoken: String
    let lit: Bool
    var held = false            // pressed on the FM-1: lights as if pressed here
    var silent = false          // plays nothing (a black key in WHITE mode, as on the FM-1)
    let down: () -> Void
    let up: () -> Void
    @State private var pressed = false

    var body: some View {
        let glow = pressed || held ? 1.0 : lit ? 0.5 : 0
        ZStack {
            // rubber: matte, domed, no shine. Edges darkened from inside, one broad faint highlight,
            // a soft shadow onto the sheet. Pressed, it flattens.
            // (gradients, no blur: 27 blurred keys made the drawer slide and redraw slowly)
            Capsule()
                .fill(Color(hex: 0x232427))
                .overlay(
                    Capsule().strokeBorder(LinearGradient(colors: [.black.opacity(pressed ? 0.25 : 0.4), .black.opacity(pressed ? 0.35 : 0.55)],
                                                          startPoint: .top, endPoint: .bottom), lineWidth: 4)
                )
                .overlay(
                    Capsule().fill(RadialGradient(colors: [.white.opacity(pressed ? 0.02 : 0.06), .clear],
                                                  center: UnitPoint(x: 0.5, y: 0.22), startRadius: 0, endRadius: 30))
                )
                // its shadow on the sheet: a darker pill lower down
                .background(Capsule().fill(.black.opacity(pressed ? 0.3 : 0.5)).offset(y: pressed ? 1 : 4))
            VStack(spacing: 6) {
                // the slit: a groove, with white light behind it
                Capsule()
                    .fill(Color(hex: 0x0B0B0D))
                    .overlay(Capsule().fill(Theme.text.opacity(glow)))
                    .overlay(Capsule().stroke(.white.opacity(0.05), lineWidth: 0.5).offset(y: 0.5))
                    .frame(width: 4, height: 38)
                    .shadow(color: Theme.text.opacity(glow * 0.9), radius: glow > 0 ? 6 : 0)   // the glow only while lit
                if !name.isEmpty {
                    Text(name).font(.system(size: 11)).foregroundStyle(Theme.textSecondary).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .offset(y: name.isEmpty ? 0 : 6)
        }
        .opacity(silent ? 0.35 : 1)
        .scaleEffect(pressed ? 0.97 : 1)
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !pressed { pressed = true; down() } }
                .onEnded { _ in pressed = false; up() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(.isButton)
        .disabled(silent)
        .accessibilityAction {           // VoiceOver: a short note
            down()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { up() }
        }
    }
}

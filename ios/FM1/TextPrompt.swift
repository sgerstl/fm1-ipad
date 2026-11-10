import SwiftUI

// A name asked for in place (2026-11-10, Scott: "Yes, convert them"): Lupe's own card at the finger in place of the
// system's text alert, for saving a project, renaming one, saving a sound to a user slot, and saving to an FM-1 project
// slot. A title, what happens (and whether it comes back), the name, Cancel and the choice. A choice that replaces
// something is outlined in the record red, as the menus' confirms are. A refusal shows in the card, under the name,
// and the card stays (never a toast).

struct TextPrompt: Identifiable {
    let id = UUID()
    var title: String
    /// What saving does: where it goes, what it replaces, whether that comes back.
    var message: String? = nil
    var text: String
    var confirm: String
    /// Replaces something that doesn't come back: the choice in the record red's outline.
    var destructive = false
    var uppercase = false
    var maxLength: Int? = nil
    var at: CGPoint = TouchPoint.last
    /// Done with the name: nil closes the card; a sentence keeps it open with that sentence under the name.
    var action: @MainActor (String) async -> String?
}

/// Draws an open TextPrompt over what it's put on (the app's root has one, the Projects sheet its own), beside the
/// finger, kept above the keyboard (the layer gives way to it). Escape or Cancel closes it; a touch outside doesn't
/// (a name half typed isn't thrown away by a stray tap).
struct TextPromptLayer: View {
    @Binding var prompt: TextPrompt?
    @State private var frame: CGRect = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                Color.clear.allowsHitTesting(false)
                if let p = prompt {
                    TextPromptCard(prompt: p, close: { prompt = nil })
                        .id(p.id)
                        .position(x: Self.x(p.at.x - frame.minX, in: g.size.width), y: Self.y(p.at.y - frame.minY, in: g.size.height))
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.2), value: prompt?.id)
        }
        .globalFrame($frame)
    }

    static let width: CGFloat = 360, height: CGFloat = 250
    private static func x(_ at: CGFloat, in w: CGFloat) -> CGFloat { min(max(width / 2 + 12, at), w - width / 2 - 12) }
    /// Under the finger where it fits, above it where it doesn't, always inside (the keyboard takes the layer's foot).
    private static func y(_ at: CGFloat, in h: CGFloat) -> CGFloat {
        let below = at + 24 + height / 2
        let c = below + height / 2 <= h - 12 ? below : at - 24 - height / 2
        return min(max(height / 2 + 12, c), h - height / 2 - 12)
    }
}

private struct TextPromptCard: View {
    let prompt: TextPrompt
    let close: () -> Void
    @State private var text = ""
    @State private var refusal: String?
    @State private var working = false
    @FocusState private var focused: Bool

    private var name: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(prompt.title).font(.lupe(17, .semibold)).accessibilityAddTraits(.isHeader)
                if let m = prompt.message {
                    Text(m).font(.lupe(13)).foregroundStyle(Theme.textSecondaryRaised).fixedSize(horizontal: false, vertical: true)
                }
            }
            TextField("Name", text: $text)
                .font(.lupe(17))
                .textInputAutocapitalization(prompt.uppercase ? .characters : .words)
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { go() }
                .onChange(of: text) {
                    if prompt.uppercase, text != text.uppercased() { text = text.uppercased() }
                    if let n = prompt.maxLength, text.count > n { text = String(text.prefix(n)) }
                    refusal = nil
                }
                .padding(.horizontal, 12).frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.well))
                .accessibilityLabel("Name")
                .accessibilityHint(prompt.maxLength.map { "Up to \($0) letters" } ?? "")
            if let refusal {
                Label(refusal, systemImage: "exclamationmark.triangle").font(.lupe(13)).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                Button { close() } label: {
                    Text("Cancel").font(.lupe(15)).frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.control))
                }
                .buttonStyle(PressSink())
                .keyboardShortcut(.cancelAction)
                Button { go() } label: {
                    Text(prompt.confirm).font(.lupe(15, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundStyle(prompt.destructive ? Theme.text : Theme.onColour)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            RoundedRectangle(cornerRadius: 10).fill(prompt.destructive ? Theme.control : Theme.text)
                                .overlay { if prompt.destructive { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.recText, lineWidth: 3) } }
                        }
                }
                .buttonStyle(PressSink())
                .disabled(name.isEmpty || working)
                .accessibilityHint(prompt.destructive ? "Replaces it. Can't be undone" : "")
            }
        }
        .padding(16)
        .frame(width: TextPromptLayer.width)
        .background(RoundedRectangle(cornerRadius: 16).fill(Elevation.held.surface).elevationShadow(.held))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
        .onKeyPress(.escape) { close(); return .handled }
        .onAppear { text = prompt.text; focused = true }
    }

    private func go() {
        guard !name.isEmpty, !working else { return }
        working = true
        let n = name
        Task {
            let why = await prompt.action(n)
            working = false
            if let why { refusal = why; UIAccessibility.post(notification: .announcement, argument: why) } else { close() }
        }
    }
}

import XCTest

/// The accessibility audit (2026-11-10): `performAccessibilityAudit()` on each main screen, against the demo FM-1
/// (`-demo`, Skiff), simulator only. Every issue the audit raises is written out (the test log, lines starting
/// `A11Y|`, and `<screen>.tsv` in the output folder) and the test then fails if any were raised that aren't on the
/// written list of known ones below, so a new one can't slip in unseen. Nothing is suppressed without a reason
/// written beside it.
///
/// The output folder: `A11Y_OUT` in the environment (pass `TEST_RUNNER_A11Y_OUT=<dir>` to xcodebuild), else the
/// temporary folder. It also gets a screenshot and the element tree of each screen.
///
/// A clean audit is a floor, never a claim that a screen is accessible: it can't judge reading order, whether a
/// label makes sense, gestures, live announcements or how a screen reads with VoiceOver. See
/// `qa/accessibility-2026-11-10/README.md`.
final class AccessibilityAuditTests: XCTestCase {

    // MARK: Known issues, each with its reason (empty: none suppressed)

    /// Audit issues accepted for now, matched on "screen|type|element label". Each needs a reason and a finding in
    /// the report. Nothing here hides an issue from the log: they're still written out, only not failed on.
    static let accepted: [String: String] = [:]

    // MARK: Plumbing

    private var app: XCUIApplication!
    private static var out: URL = {
        let env = ProcessInfo.processInfo.environment["A11Y_OUT"]
        let u = env.map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("a11y-audit")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()
    private var unexpected: [String] = []

    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    private func launch(_ extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-demo", "-no-intro"] + extra
        app.launch()
        // the demo FM-1 connects and reads in a moment
        _ = app.buttons["Pages"].waitForExistence(timeout: 2)
        sleep(3)
    }

    private var device: String { UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone" }

    /// Audits what's on screen now, writes the issues, the screenshot and the element tree under `name`.
    private func audit(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let screen = "\(device)-\(name)"
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: Self.out.appendingPathComponent("\(screen).png"))
        try? app.debugDescription.write(to: Self.out.appendingPathComponent("\(screen).tree.txt"), atomically: true, encoding: .utf8)
        let a = XCTAttachment(screenshot: shot); a.name = screen; a.lifetime = .keepAlways; add(a)

        var rows: [String] = []
        // one audit pass per kind: a whole screen of Lupe (six rows of pads, the editor, the top bar) in one pass ran out
        // of the audit's time ("Audit failed to complete in time", code -56); a pass that still does is written as ERROR
        let passes: [(String, XCUIAccessibilityAuditType)] = [
            ("contrast", .contrast), ("hitRegion", .hitRegion),
            ("description", [.sufficientElementDescription, .trait]), ("elementDetection", .elementDetection),
            ("text", [.dynamicType, .textClipped]),
        ]
        for (passName, kinds) in passes {
            do {
                try app.performAccessibilityAudit(for: kinds) { issue in
                    let el = issue.element
                    // (each property read is a query of the app: two, keep a screen's audit to minutes)
                    let label = el?.label ?? ""
                    let f = el?.frame ?? .zero
                    let frame = el == nil ? "" : "\(Int(f.minX)),\(Int(f.minY)),\(Int(f.width))x\(Int(f.height))"
                    let kind = Self.name(issue.auditType)
                    let row = [screen, kind, label, "", "", frame, issue.compactDescription, issue.detailedDescription]
                        .map { $0.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }
                        .joined(separator: "\t")
                    rows.append(row)
                    print("A11Y|" + row.replacingOccurrences(of: "\t", with: "|"))
                    if Self.accepted["\(screen)|\(kind)|\(label)"] == nil { self.unexpected.append(row) }
                    return true        // handled here (logged), so the audit goes on to the next issue
                }
            } catch {
                let row = "\(screen)\tERROR(\(passName))\t\t\t\t\t\(error.localizedDescription)\t"
                rows.append(row); unexpected.append(row)
                print("A11Y|\(screen)|ERROR(\(passName))|\(error.localizedDescription)")
            }
        }
        if rows.isEmpty { print("A11Y|\(screen)|none") }
        // one file a screen (the tests can run side by side on clones); concatenate them for the whole audit
        let text = rows.isEmpty ? "\(screen)\tnone\n" : rows.joined(separator: "\n") + "\n"
        try? text.write(to: Self.out.appendingPathComponent("\(screen).tsv"), atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        // reported, not hidden: every issue the audit raised that isn't on the accepted list
        XCTAssertTrue(unexpected.isEmpty, "\(unexpected.count) accessibility audit issue(s):\n" + unexpected.joined(separator: "\n"))
        app?.terminate()
    }

    private static func name(_ t: XCUIAccessibilityAuditType) -> String {
        switch t {
        case .contrast: "contrast"
        case .elementDetection: "elementDetection"
        case .hitRegion: "hitRegion"
        case .sufficientElementDescription: "sufficientElementDescription"
        case .dynamicType: "dynamicType"
        case .textClipped: "textClipped"
        case .trait: "trait"
        default: "other(\(t.rawValue))"
        }
    }

    /// Taps the first element with this label, any type. False when there's none (written to the log).
    @discardableResult
    private func tap(_ label: String) -> Bool {
        let e = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        guard e.waitForExistence(timeout: 3), e.isHittable else { print("A11Y|\(device)|reach|no hittable '\(label)'"); return false }
        e.tap(); sleep(1); return true
    }

    private func dismissSheet() {
        // swipe the sheet down (a hand's way), then escape for the keyboard's
        app.swipeDown(velocity: .fast); sleep(1)
    }

    // MARK: Screens

    // the editor's place is a stored default (SongPosition.key): 0 No grid, 1 Half, 2 Max
    func testSongPadsHalf() {
        launch(["-songPosition", "1"])
        audit("song-pads-half")
    }

    func testSongPadsNoGrid() {
        launch(["-songPosition", "0"])
        audit("song-pads-nogrid")
    }

    func testSongPadsMax() {
        launch(["-songPosition", "2"])
        audit("song-pads-max")
    }

    func testSongTimeline() {
        launch(["-song-timeline"])
        audit("song-timeline")
    }

    func testMix() {
        launch()
        tap("Mix")
        audit("mix")
    }

    func testSounds() {
        launch()
        tap("Sounds")
        audit("sounds")
    }

    func testConnectionMenuAndSettings() {
        launch()
        let conn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Demo' OR label CONTAINS 'FM-1' OR label CONTAINS 'Connected'")).firstMatch
        if conn.waitForExistence(timeout: 3) { conn.tap(); sleep(1) }
        audit("connection-menu")
        if tap("Settings…") {
            audit("settings")
            if tap("Labs") { audit("labs") }
        }
    }

    func testProjects() {
        launch()
        if tap("Projects") { audit("projects") }
    }

    func testFirmwarePicker() {
        launch(["-demo-firmware", "picker"])
        audit("firmware-picker")
    }

    func testFirmwareInstalling() {
        launch(["-demo-firmware", "installing"])
        audit("firmware-installing")
    }

    // MARK: The phone's own screens (2026-11-10: Pads · Edit · Mix · Sounds, boards 46–50)

    private func phoneOnly() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom == .pad, "the phone's layout")
    }

    func testPhoneEdit() throws {
        try phoneOnly()
        launch(["-page", "edit"])
        audit("edit")
        let step = app.buttons.matching(NSPredicate(format: "label ENDSWITH ' panel' AND label BEGINSWITH 'Step '")).firstMatch
        if step.waitForExistence(timeout: 3) { step.tap(); sleep(1); audit("edit-step-panel") }
        else { print("A11Y|\(device)|reach|no Step key") }
    }

    func testPhoneMixDelay() throws {
        try phoneOnly()
        launch()
        tap("Mix")
        if tap("Delay") { audit("mix-delay") }
    }

    func testPhoneLaunchMenu() throws {
        try phoneOnly()
        launch()
        if tap("Launch at") { audit("launch-menu") }
    }

    func testPhoneSoundPanel() throws {
        try phoneOnly()
        // Settings › Sound buttons on: the rail down the right, then FX's pages over Pads
        launch(["-soundRail.v2", "YES"])
        if tap("FX pages") { audit("sound-panel") }
    }

    func testPadMenu() {
        launch(["-songPosition", "0"])
        let pad = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Entry' OR label CONTAINS ', entry'")).firstMatch
        if pad.waitForExistence(timeout: 3) {
            pad.press(forDuration: 0.8); sleep(1)
            audit("pad-hold-menu")
        } else {
            print("A11Y|\(device)|reach|no pad found")
        }
    }
}

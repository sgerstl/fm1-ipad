// Which firmware this library draws for (decision 46, Scott 2026-11-15): SkiffDraw draws a picture only when the
// connected FM-1 runs exactly the Skiff-Lupe build its drawing code was copied from; anywhere else the app falls back
// to its hand-drawn picture. Any other Skiff (2.2, a newer Skiff-Lupe, upstream 2.5.1 without the screen link) can
// move ids, pages or drawings without saying so.
import CSkiffDraw

public enum SkiffDrawBuild {
    /// INFO's version string of the vendored source (CSkiffDraw/skiff/VERSION: Skiff-Lupe 2.5.1 at 737e3fb).
    public static var version: String { String(cString: skd_build_version()) }
    /// The screen link builds (INFO `56 01 nn`) whose drawing code is the vendored one: 6 is 737e3fb itself; 7
    /// (5e10a37, Skiff-Lupe 2.5.1 take) changes only editor.c and the FREE TAKE picker's ui_take.c (`git diff
    /// 737e3fb 5e10a37 -- firmware/src`), neither of which draws a page SkiffDraw shows. A new build is added here only
    /// after that diff is checked again.
    public static let screenLinks: Set<Int> = [6, 7]

    /// Whether the unit described can be drawn by this library.
    @MainActor
    public static func accepts(version: String?, screenLink: Int?, paramCount: Int?, globalCount: Int?) -> Bool {
        guard let version, let screenLink, let paramCount, let globalCount else { return false }
        let s = SkiffScreen.shared
        return version == Self.version && screenLinks.contains(screenLink)
            && paramCount == s.trackParamCount && globalCount == s.globalCount
    }
}

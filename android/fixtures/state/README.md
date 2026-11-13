# android/fixtures/state

`ViewState` recordings that `FakeLupeCore` replays (BRIDGE.md §2). One file per scenario:
`{"provisional": bool, "frames": [{"atMs", "area", "state"}]}`, each frame one `onState(area, json)` call.

**Everything here is provisional**: hand-written by P2 to the BRIDGE.md contract until P1's Mac test
(`PhoneCore` over `FakeSkiff(demo: true)`) writes real recordings. When it does, replace the files (keep the
scenario names `ready`, `searching`, `lost`, `wrongFirmware`, or tell P2) and drop the `provisional` flag.
`app/src/test/.../FixturesTest` decodes every file, so a renamed field fails a build.

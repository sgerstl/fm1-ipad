# Lupe: how we work in this repo

Read this before building anything here. These rules came out of a review of the first nine days (2026-11-08). The code got built faster than Scott could test it on the iPad and the FM-1, so these rules are about verification, not speed.

Project notes, decisions and the batch list live in Scott's vault: `~/vaults/Panopticon/Projects/Dev/fm1-ipad/` (`index.md`, `batch-list.md`, `session-log.md`).

## 1. Every batch item has three states

In `batch-list.md`, an item moves through **Built** (in the simulator, tests pass) → **On the device** (Scott ran its check on the iPad with the FM-1) → **VoiceOver** (checked with VoiceOver on). Strike an item through only at the last state that applies to it. Most VoiceOver checks wait for the accessibility pass before release, so until then an item that passed on the device counts as done, with "VoiceOver: release pass" noted.

Never mark something as working on the device because it works in the simulator or against a fake. The simulator can't record animation hitches, and the fakes have been more forgiving than the real firmware more than once.

## 2. A session that builds ends by writing the device check

Any session that changes app or firmware behaviour, and every overnight session, ends by writing `qa/device-checks/YYYY-MM-DD-<branch>.md` from the template in `qa/device-checks/TEMPLATE.md`. One numbered check per thing built: what to do with the iPad and the FM-1, what Scott should see, and whether a backup comes first (anything that writes the FM-1's flash: samples, settings, firmware, song order). Keep each check to what a hand can do in about a minute.

**The branch merges to `main` only after Scott has run that check.** Failures go back on the batch list. Never merge to `main` or push it yourself; ask.

**One worktree per active build session, removed when its branch merges into the trunk** (`git worktree remove`, then `git branch -d`). Added 2026-11-08 after a cleanup of 16 stale worktrees.

## 3. Feel goes into Labs first

When Scott comments on a timing, spring, delay, threshold, distance or offset ("a bit slower", "too easy to trigger"), add it to Labs (`ios/FM1/Labs.swift`, Settings › Labs) **before** a second round of tweaking: current value as the default, a sensible range, today's date, review in two weeks. Scott tunes it by hand on the iPad. Don't keep re-guessing the number through prompts.

## 4. Structure before screens

Before designing a new tab, panel or screen, or moving where something lives, update the structure map: `design/structure-map.md` (create it on first use). It shows the tabs, the panels on each, and where each FM-1 button and page lands. Scott agrees the map first; the screen design and polish come after. Changing the layout after it's been polished cost the most rework so far (Shape, three sets of tab names).

## 5. The fakes are strict

`FakeSkiff` records every request it doesn't model in `unanswered`, and the tests expect it to be empty (`unansweredCommands`). When a test fails on that, **teach the fake from evidence**: a probe of the real FM-1 (`tools/skiffprobe.swift`), skiff-sim, or the firmware's own source. Never from what the app happens to send. Copy the firmware's refusals too: short forms, wrong argument counts, writes refused while playing. The INSERT knob names passed against a fake that was more forgiving than the real FM-1.

## 6. Accessibility is a release gate

The full accessibility pass (VoiceOver, keyboard, largest text, Reduce Motion; `qa/TEST-PLAN.md` section 6) is the last step before preparing a release. It doesn't happen per batch. Until then, keep the floor: every drag has a non-drag way in (WCAG 2.5.7), new controls get VoiceOver labels and actions, Reduce Motion is respected, and contrast is computed, not eyeballed.

## 7. A component with a reference document: read it first, write back the same session

*Trial from 2026-11-13, on the pattern pad only.* `design/components/` holds one document per component (rules in its `README.md`). Before changing a component that has one, read it: requirements, Ruled out, the decision logs. **If what you're about to build touches a line marked `[open]`, stop and ask Scott**; don't decide it. Anything Scott decides or rejects during the session goes back into the document in the same commit as the work. Never copy into it what `DESIGN.md`, the tokens, Labs or the device checks already hold.

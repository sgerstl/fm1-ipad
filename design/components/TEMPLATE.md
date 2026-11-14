---
component: {Name}
lifecycle: requested   # requested · active · built · deprecated (the component)
status:                # the document, per section: empty · draft · complete
  requirements: empty
  design: empty
  build-notes: empty
  usage: empty
code: []               # Swift files that draw it
boards: []             # canvas boards and mockups
figma: []              # component sets in the Lupe UI kit (a sketch kit, never a source of behaviour)
---

# {Name}

<!-- Amendment: only while a built component is being changed. Delete once folded into section 1.
> **Under revision (YYYY-MM-DD):** what's changing and why. Section 1 below is the current behaviour until this closes.
-->

## 1. Requirements

Only what's true now. Superseded lines are removed; their reasons go to the decision log or Ruled out.

### Purpose and scope

What it's for, in two or three sentences. Who uses it and when.

### Anatomy

The parts, by the names the code uses. Every statement below uses these nouns and no others; needing a new word means this list is incomplete.

- **{part}**: what it is.

### Requirements

F functional · S states · B behaviour · C content · A accessibility · I integration (firmware, drivers, other components). One testable statement per line. `[review]` for what only Scott on the device can check, `[open]` for what isn't decided.

- **F1** …
- **S1** …
- **B1** …
- **C1** …
- **A1** …
- **I1** …

### Ruled out

Considered and rejected, so nobody proposes it again. Date, who, why.

- …

### Out of scope

What belongs to another component, and which.

- …

## 2. Design

What the canvas settled that the boards don't say on their own. Link boards; don't describe their pixels.

### Decision log

- YYYY-MM-DD: decision, because why (who).

## 3. Build notes

Before and during a build: how the codebase already does this, precedent from other CRDs, firmware facts checked in the source, implementation decisions and the questions they raised.

### Decision log

- YYYY-MM-DD: decision, because why (who).

## 4. Usage

Quick notes for a session placing or reusing it: when to use it, when not, what to use instead.

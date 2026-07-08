# SwiftTutor Apprentice

A private, local macOS app for learning Swift by hand. Not a chatbot: it
teaches you to *understand* code — what you typed, what each part means, why
Swift needs the syntax, and what happens when it runs.

Fully offline. No AI, accounts, backend, or network.

## Requirements

- macOS 14 or newer
- A Swift toolchain (comes with Xcode or the Xcode Command Line Tools)

## Open it as a normal app (recommended)

Build a double-clickable `.app` bundle:

```bash
cd ~/Developer/SwiftTutorApprentice
./Scripts/build-app.sh
```

Then open `dist/SwiftTutor Apprentice.app` from Finder (drag it to your
Applications folder to keep it around). Re-run the script after any code change.

First launch may show a Gatekeeper prompt because the app isn't from the App
Store — right-click the app → **Open** → **Open**, or approve it in
**System Settings → Privacy & Security**.

## Or run it from the terminal

```bash
swift build
swift run SwiftTutorApprentice
```

## The curriculum

Seven fundamentals lessons that build on each other:

1. Printing Text in Swift — `print`
2. Storing Text in a Constant — `let`
3. Variables You Can Change — `var`
4. Combining Text with Interpolation — `\(  )`
5. Numbers and Simple Math — `Int`, operators
6. Making Decisions with `if` — `Bool`, conditions, braces
7. Writing Your Own Function — `func`

Pick any lesson from the sidebar. Completed lessons get a green checkmark, and
your progress is saved between launches.

## The learning loop (every lesson)

1. Read the lesson (left panel): goal, what to type, terms, and a Syntax Lens
   that breaks the key line into clickable pieces.
2. Type the code by hand (middle panel).
3. Watch the Live Coach react as you type (right panel): it flags missing
   quotes/parentheses/braces and tells you when the code looks right.
4. Hover or click glossary terms and syntax tokens to learn the vocabulary.
5. Write a **prediction** of the output (bottom bar).
6. Press **Run** (or ⌘R).
7. See real `stdout`, `stderr`, and the `exit code`, plus a plain-language
   explanation and whether your prediction matched. A clean run that produces
   the lesson's expected output marks the lesson complete automatically.

## Where things are stored

- Code you run is written to and executed from
  `~/Developer/SwiftTutorApprentice/Workspace/main.swift`
- Progress is saved as readable JSON at
  `~/Library/Application Support/SwiftTutorApprentice/progress.json`
  (the sidebar's **Reset** button clears it)

## Project layout

- `Models/` — `Lesson`, `Curriculum` (all lesson content), `GlossaryEntry`,
  `SyntaxToken`. The whole app is driven by this data.
- `Services/` — `SwiftRunner` (runs your code), `LiveCoach` (rule-based
  feedback), `ProgressStore` (saves completion).
- `AppModel.swift` — shared state (view model).
- `Views/` — the sidebar, the three panels, and the run/output bar.

## Note on sandboxed shells

If you ever see `sandbox-exec: sandbox_apply: Operation not permitted` when
building, your shell is itself inside a sandbox that blocks the one SwiftPM
starts. Add `--disable-sandbox` (already used by `build-app.sh`):

```bash
swift build --disable-sandbox
swift run --disable-sandbox SwiftTutorApprentice
```

On a normal Terminal this isn't needed.

## Intentionally not here yet

No AI/Codex/Claude integration, no accounts, backend, cloud sync, database,
networking, or syntax highlighting. See the `TODO:` comments in the source for
the planned next steps.
```

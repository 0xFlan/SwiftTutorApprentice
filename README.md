# SwiftTutor Apprentice

A private, local macOS app for learning Swift by hand. Not a chatbot: it
teaches you to *understand* code — what you typed, what each part means, why
Swift needs the syntax, and what happens when it runs.

Everything happens **inside the app**: reading, typing, running, tracking
progress, and even authoring your own lessons. No terminal needed to use it.

## Requirements

- macOS 14 or newer
- A Swift toolchain (comes with Xcode or the Xcode Command Line Tools)

## Open it as a normal app (recommended)

Build a double-clickable `.app` bundle (this one-time step uses the terminal;
using the app afterwards does not):

```bash
cd ~/Developer/SwiftTutorApprentice
./Scripts/build-app.sh
```

Then open `dist/SwiftTutor Apprentice.app` from Finder (drag it to your
Applications folder to keep it). Re-run the script after any code change.

First launch may show a Gatekeeper prompt because the app isn't from the App
Store — right-click the app → **Open** → **Open**, or approve it in
**System Settings → Privacy & Security**.

To run from the terminal instead: `swift run SwiftTutorApprentice`.

## What it does

**A complete beginner Swift curriculum (17 lessons)** that builds up step by
step:

1. Printing Text · 2. Constants (`let`) · 3. Variables (`var`) ·
4. String Interpolation · 5. Math · 6. `if` · 7. Functions ·
8. `if`/`else` · 9. `Double` · 10. Bool logic · 11. Arrays · 12. Loops ·
13. Optionals · 14. Dictionaries · 15. Structs · 16. Function parameters ·
17. Return values

**The learning loop, every lesson:**

1. Read the lesson (left): goal, what to type, clickable glossary terms, and a
   Syntax Lens that breaks the key line into tappable pieces.
2. Type the code by hand (middle) — a faint placeholder shows the starter.
3. Watch the Live Coach react as you type (right): it flags missing
   quotes/parentheses/braces and confirms when the code looks right.
4. Predict the output (bottom bar).
5. Run it (**⌘R**). See real `stdout`, `stderr`, and exit code, a
   plain-language explanation, and whether your prediction matched.
6. A clean run that matches the lesson's expected output marks it complete
   (green check in the sidebar). Move between lessons with **⌘[** / **⌘]**.

**Author your own lessons — no files, no terminal.** Click **Manage lessons**
in the sidebar to add, edit, reorder, and delete lessons (title, code, terms,
syntax tokens, coach text, expected output). Everything saves automatically.
**Restore default lessons** brings back the built-in curriculum.

**Optional AI coach (off by default).** In **Settings** you can enable an
"Ask the AI coach" button that sends the current lesson and your code to your
local `claude` CLI (or any command you specify) for extra explanation. The
rule-based coach always works offline; AI is purely additive and only runs
when you turn it on and press the button.

## Where things are stored

- Code you run: `~/Developer/SwiftTutorApprentice/Workspace/main.swift`
- Your lessons: `~/Library/Application Support/SwiftTutorApprentice/lessons.json`
- Progress: `~/Library/Application Support/SwiftTutorApprentice/progress.json`

## Project layout

- `Models/` — `Lesson`, `Curriculum` (default lessons), `GlossaryEntry`,
  `SyntaxToken`. Data-driven: a lesson is just data.
- `Services/` — `SwiftRunner` (runs code), `LiveCoach` (rule-based feedback),
  `AICoach` (optional CLI-based AI), `LessonStore` (JSON lessons),
  `ProgressStore`, `AppSettings`.
- `AppModel.swift` — shared state (view model).
- `Views/` — sidebar, three panels, run/output bar, lesson editor, settings,
  welcome.
- `Scripts/` — `build-app.sh` (package the `.app`), `make-icon.sh` +
  `make-icon.swift` (regenerate the icon).

## Note on sandboxed shells

If you see `sandbox-exec: sandbox_apply: Operation not permitted` when
building, your shell is inside a sandbox that blocks the one SwiftPM starts.
Add `--disable-sandbox` (`build-app.sh` already does). A normal Terminal
doesn't need it.

## Still deferred (future ideas)

API-key AI provider as an alternative to the CLI; a "review my whole project"
action; automatic Syntax Lens tokenizing for arbitrary lines; SwiftUI-app
lessons. See the `TODO:` comments in the source.
```

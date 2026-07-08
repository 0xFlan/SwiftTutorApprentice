# SwiftTutor Apprentice

A private, local macOS app for learning Swift by hand. Not a chatbot: it
teaches you to *understand* code — what you typed, what each part means, why
Swift needs the syntax, and what happens when it runs.

This is the **MVP**: one lesson, one tight learning loop, fully offline.

## Requirements

- macOS 14 or newer
- A Swift toolchain (comes with Xcode or the Xcode Command Line Tools)

## Run it

```bash
cd ~/Developer/SwiftTutorApprentice
swift build
swift run SwiftTutorApprentice
```

The app window opens with **Lesson 1: Printing Text in Swift**.

The learning loop:

1. Read the lesson (left panel).
2. Type `print("Hello, Swift!")` into the editor by hand (middle panel).
3. Watch the Live Coach react as you type (right panel).
4. Tap glossary terms and Syntax Lens tokens to learn the vocabulary.
5. Write a **prediction** of the output (bottom bar).
6. Press **Run** (or ⌘R).
7. See real `stdout`, `stderr`, and the `exit code`, plus a plain-language
   explanation of what happened and whether your prediction matched.

When you Run, your code is saved to and executed from:

```
~/Developer/SwiftTutorApprentice/Workspace/main.swift
```

## Note on this sandboxed environment

If you ever see `sandbox-exec: sandbox_apply: Operation not permitted` when
building, your shell is itself running inside a sandbox that blocks the one
SwiftPM starts. Add `--disable-sandbox`:

```bash
swift build --disable-sandbox
swift run --disable-sandbox SwiftTutorApprentice
```

On a normal Terminal this is not needed.

## What's intentionally NOT here yet

No AI, no Codex/Claude integration, no accounts, no backend, no cloud sync, no
database, no networking, no syntax highlighting. See the `TODO:` comments in
the source for the planned next steps.
```

# Contributing to SwiftTutor Apprentice

Thanks for helping make programming education clearer and more accessible.

## Before you start

- Open an issue for substantial curriculum, persistence, runner, or navigation
  changes so the behavior and migration path can be agreed first.
- Keep the core learning experience offline and usable without an AI account.
- Never commit API keys, access tokens, learner data, build products, or local
  workspace files.
- Preserve stable lesson and progress identities. Persistence changes require
  legacy fixtures and migration tests.

## Development setup

Requirements:

- macOS 14 or newer
- Xcode or the Xcode Command Line Tools
- Swift 5.9 or newer

Run the tests and development build:

```bash
swift test
swift build
```

Build the app bundle used for user-facing verification:

```bash
./Scripts/build-app.sh
open "dist/SwiftTutor Apprentice.app"
```

## Pull requests

1. Add or update tests before changing behavior.
2. Keep changes focused and explain migration or accessibility effects.
3. Run `swift test`, `swift build -c release`, and the relevant bundled-app
   smoke path.
4. Include screenshots or a short recording for visible interface changes.
5. Confirm keyboard navigation, VoiceOver labels, and Reduce Motion behavior
   for new interactive or animated surfaces.

Educational content should distinguish language requirements from conventions,
avoid unsupported certification claims, and link primary sources when making
research-backed claims.

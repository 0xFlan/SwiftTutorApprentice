# Course Platform Milestone 1 Real-App Smoke

Date: 2026-07-12

## Verified bundle

- Source commit: `90d56e81e30fb1ee92613b5ae43c63ea2f5fd11e`.
- Bundle: `dist/SwiftTutor Apprentice.app`.
- Signed executable SHA-256: `9b3f535dc7c7fc4bf33dc5130eae086d6f7d6f8781832c351087a36444c2e37f`.
- Manifest unsigned SHA-256: `c6d7b39784e6d2b845a4381d16e09af7502b7fdb2e0c040aadc131130f0e5eff`.

Commands and outcomes:

```bash
swift build -c release --disable-sandbox
./Scripts/build-app.sh
bash Scripts/verify-app-bundle.sh
```

All commands exited 0. The verifier reported the bundle, hashes, and source
commit above.

## Automated gates

- Full feature-branch package gate: 283 tests, 6 truthful environment-gated
  skips, 0 failures in 447.8 seconds.
- Player-first feature gate: 75 tests, 5 truthful environment-gated skips, 0
  failures.
- `CancellableProcessRunnerTests`: 9 tests, 0 failures, with descendant-held
  pipe and orphan-process coverage.
- `bash Tests/Scripts/restore-transaction-tests.sh
  "$PWD/Scripts/course-platform-smoke-state.sh"`: PASS, including fault,
  signal, SIGKILL, rollback, roll-forward, and cleanup boundaries.
- macOS `/var` versus `/private/var` temporary-directory alias regression:
  PASS.
- exact preference replacement regression for restore and rollback: PASS.
- `bash -n Scripts/course-platform-smoke-state.sh
  Tests/Scripts/restore-transaction-tests.sh`: PASS.
- `git diff --check`: PASS.

## Protected real-app proof

The exact guarded command families used were:

```bash
bash Scripts/course-platform-smoke-state.sh backup
bash Scripts/course-platform-smoke-state.sh clean "$SESSION"
bash Scripts/course-platform-smoke-state.sh legacy "$SESSION"
bash Scripts/course-platform-smoke-state.sh future-progress "$SESSION"
bash Scripts/course-platform-smoke-state.sh future-lessons "$SESSION"
bash Scripts/course-platform-smoke-state.sh corrupt-progress "$SESSION"
bash Scripts/course-platform-smoke-state.sh snapshot "$SESSION" "$FILE" "$LABEL"
bash Scripts/course-platform-smoke-state.sh assert-unchanged "$SESSION" "$FILE" "$LABEL"
bash Scripts/course-platform-smoke-state.sh restore "$SESSION"
```

No learner content, preference value, backup payload, or private session path
is recorded in this report.

Results:

- Clean Welcome and Course Home: PASS.
- Swift Development Lessons 1–3 show one authored 16:9 player first, with the
  title, objective, lesson path, Recall, Modify, and Practice/Run below: PASS.
- Lesson 4 is ordinarily unauthored, shows no synthetic player, and begins with
  its title and objective: PASS.
- Active narration/playback continued while the outer lesson document scrolled
  fully to practice: PASS.
- The player scrolled away naturally and never became sticky: PASS.
- Playback did not change the outer offset, clip above navigation, lock the
  editor, or steal editor focus: PASS.
- Pause, Back, Next, Replay, narration toggle, transcript, Skip, and Read Deeper:
  PASS.
- Transcript remained inside the player frame: PASS.
- Practice starter insertion and local Run completed successfully: PASS.
- Legacy fixture migration and course entry: PASS.
- Future progress displayed read-only protection; attempted Recall mutation did
  not change the file: PASS.
- Corrupt progress displayed read-only protection; attempted Recall mutation did
  not change the file: PASS.
- Future lesson content disabled editing and showed a stable unavailable player
  while leaving the base lesson and local practice usable: PASS.
- Future lesson file remained byte-identical after practice execution: PASS.
- Original Application Support, workspace, and normalized preferences restored
  exactly; both protected sessions exited 0 and were deleted: PASS.

## Final provenance launch

After the smoke-only restore fixes were committed, the app was rebuilt and
verified at source commit `e648d588a596b8754cad34b0bac904a68d1d5734`.
That exact protected-smoke bundle was launched under a fresh clean session and
verified through:

1. Welcome;
2. Course Home with truthful available/coming-next cards;
3. Swift Development;
4. Lesson 1 with the animated player first and lesson content below.

The app was then quit and the second protected session restored exactly.

## Result

`PASS` — the player-first lesson flow, narration containment, forward-compatible
read-only paths, exact signed bundle provenance, and unconditional learner-state
restoration passed at the source commit and hashes recorded above.

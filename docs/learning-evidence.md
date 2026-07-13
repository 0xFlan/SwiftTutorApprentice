# Learning-science evidence & feature roadmap

Findings from a deep-research pass (5 search angles, 23 sources, 87 claims
extracted, top 25 adversarially verified with 3 independent skeptic votes each;
**21 confirmed, 4 refuted**). Confidence labels are the verifier's, not ours.
This file grounds the app's pedagogy in evidence and sequences the roadmap.

## Confirmed techniques (high confidence)

1. **PRIMM staging (Predict → Run → Investigate → Modify → Make)** — quasi-
   experiment, 493 students aged 11–14 across 13 schools, PRIMM group beat
   control on a programming post-test. *Source: Sentance, Waite & Kallia 2019
   (ERIC EJ1217966).*
   - **App fit:** Predict and Run are implemented, and the animated player plus
     Syntax Lens support Investigate. Built-in Lessons 1–3 now present a paused
     visual explanation,
     then hand off through Recall to explicit **Modify** with working code, one
     guided change, and an output prediction. Practice/Run supplies the current
     independent coding step; broader free-coding (**Make**) remains later
     program work.

2. **Parsons problems (arrange scrambled code lines)** — ~30% faster practice
   than fixing/writing code with no learning loss (473s vs 679s; F(2,133)=10.8,
   p<.001); a second study (N=89) found large benefits *specifically for
   low-self-efficacy novices* (CLES ≈ .80–.81). Bridges the sharp jump from
   reading worked examples to writing code. **Start WITHOUT distractors** for
   absolute beginners (Harms et al.: distractors cut novice efficiency ~26%).
   *Sources: Ericson, Margulieux & Rick 2017 (Koli Calling); arXiv 2311.18115.*
   - **App fit:** the Parsons baseline is implemented for eligible multi-line
     lessons: it splits and scrambles starter-code lines as an optional scaffold
     before the editor.

3. **Self-explanation / bug-finding with immediate feedback** — explaining why
   a "classmate's" buggy code fails and how to fix it produced significant
   real-course gains (+1.7 to +2.4 on a 0–10 scale vs +0.6 control); guided
   self-explanation questions beat instructor-given explanations on transfer
   without adding cognitive load. *Sources: JISE 2024 v35n3; ACM 10.1145/3732791.*
   - **App fit:** the Find the bug baseline is implemented for injectable code
     lessons: the learner explains an injected mistake, then reveals stored
     feedback or loads the broken code into the editor. Guided "why is this line
     needed?" player questions remain a possible enhancement.

4. **Cognitive Load Theory** — keep intrinsic load appropriate, minimise
   extraneous load; unfamiliar terminology itself raises load for novices.
   *Source: PMC12246501.*
   - **App fit:** clickable glossary chips in the Terms section are implemented.
     Automatic inline term linking and prerequisite-gated one-concept
     microlessons remain deferred beyond Deep Lesson Pilot v1; keeping the
     novice UI spare remains a design goal.

5. **Expertise-reversal / faded worked examples** — support that helps novices
   *harms* more advanced learners (meta-analysis: low-prior-knowledge d=+0.505
   from high assistance; high-prior-knowledge d=−0.428). Effect is asymmetrical,
   so **fade conservatively**. *Sources: Tetzlaff et al. 2025; Kalyuga 2007.*
   - **App fit:** a per-concept proficiency signal that, as it rises, shifts
     entry worked-example → Parsons → free coding and lets the learner collapse
     the syntax lens / player / coach. Make all scaffolds toggleable.

## Confirmed (medium confidence — domain caveat)

6. **Spaced retrieval with *varied* cues** — beats constant-cue practice and
   passive restudy (d ≈ 0.33–0.81), and retrieval + variability are
   *superadditive*. **Caveat: evidence is from vocabulary, not programming** —
   applying it to Swift is a reasonable but untested extrapolation. *Source:
   PMC11536137.* (A Swift FSRS port exists if we want a real scheduler.)
   - **App fit:** a spaced-review mode that resurfaces past concepts as *active*
     tasks with a *different* cue each time (Parsons, then predict-output, then
     fill-in-the-blank) rather than replaying the same lesson.

## NOT supported by surviving evidence
- **Subgoal labeling** — all four claims were refuted in verification here.
  Implement only tentatively, if at all.
- **Interleaving** and **deliberate practice** — named in the query but produced
  no surviving verified claims; this pass can't speak to them for novice coding.

## Current pilot alignment

Milestone 1 is a bounded Swift Lessons 1–3 pilot, not evidence that every future
course or certification program is ready. Its embedded offline presentation is
first and paused in one stable 16:9 player, with authored state changes,
captions, an internal transcript, optional local narration, Reduce Motion,
keyboard, and VoiceOver support. The player scrolls away with the lesson and
does not move or lock the practice workspace. It hands off
through **Watch → Recall → Modify → Practice/Run**. The optional written
**Read deeper** material preserves the concept-first segments, working examples,
wrong variants, Syntax Microscope, and **Required by Swift** / **Convention** /
**Depends on context** labels without auto-opening.

This is an implementation mapping, not a measured learning-effect claim.
Opening, watching, replaying, skipping, or completing a presentation records
viewing/player state only. It is not lesson completion, mastery, course
completion, or certification readiness. Current lesson completion still means
a successful Run matching the expected output. Future mastery and readiness
require the program's separately specified repeated independent, delayed, and
assessment evidence; completion and readiness remain distinct.

The pilot's **Understand AI Code** exercises are deterministic local claim-review
activities. Only a submitted answer set creates a local course-scoped attempt;
opening the exercise or choosing answers does not. These submissions do not call
the optional remote AI coach, do not establish mastery by themselves, and are
not evidence that remote AI evaluated the learner.

Progress and migration remain private and local. Existing Swift completion,
Deep Lesson, Recall, Modify, custom-lesson, settings, and workspace state are
preserved, while presentation activity remains a separate record. The protected
exact-bundle, migration, accessibility, and layout checks are recorded
in the [Milestone 1 smoke evidence](testing/course-platform-milestone-1-smoke.md).

## Roadmap (evidence-ranked)
1. **Implemented:** Parsons practice for eligible multi-line lessons.
2. **Implemented:** Find the bug / self-explanation baseline for injectable code
   lessons.
3. **Pilot implemented:** Offline presentation, Recall, explicit Modify, local
   AI-code review, and Practice/Run for built-in Swift Lessons 1–3. Full Swift
   coverage remains future work.
4. **Future approved program:** Complete Swift, Web, Cybersecurity, and
   Networking instruction and assessment, with presentations, projects, mock
   exams, capstones, and Understand AI Code exercises throughout.
5. **Deferred:** Per-concept proficiency + fadeable scaffolds (expertise
   reversal).
6. **Deferred:** Spaced varied-cue review across courses.
7. **Deferred:** Inline glossary auto-linking + prerequisite gating.
8. **Future end state:** Objective-level certification-readiness reporting from
   repeated independent evidence. This is not a present guarantee of readiness
   or an external exam outcome.

_Split votes (2-1) and single-study / non-programming caveats are noted per
finding; treat exact effect sizes as indicative, not definitive._

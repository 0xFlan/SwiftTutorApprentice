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
   - **App fit:** already have Predict, Run, and (via the walkthrough)
     Investigate. Add explicit **Modify** (hand the learner working code +
     one guided change) and reserve free-coding (**Make**) for last. Consider
     making a prediction expected before running.

2. **Parsons problems (arrange scrambled code lines)** — ~30% faster practice
   than fixing/writing code with no learning loss (473s vs 679s; F(2,133)=10.8,
   p<.001); a second study (N=89) found large benefits *specifically for
   low-self-efficacy novices* (CLES ≈ .80–.81). Bridges the sharp jump from
   reading worked examples to writing code. **Start WITHOUT distractors** for
   absolute beginners (Harms et al.: distractors cut novice efficiency ~26%).
   *Sources: Ericson, Margulieux & Rick 2017 (Koli Calling); arXiv 2311.18115.*
   - **App fit:** a Parsons practice mode, auto-derived by splitting a lesson's
     starter code into lines and scrambling them. Optional scaffold before the
     blank editor. **← building first.**

3. **Self-explanation / bug-finding with immediate feedback** — explaining why
   a "classmate's" buggy code fails and how to fix it produced significant
   real-course gains (+1.7 to +2.4 on a 0–10 scale vs +0.6 control); guided
   self-explanation questions beat instructor-given explanations on transfer
   without adding cognitive load. *Sources: JISE 2024 v35n3; ACM 10.1145/3732791.*
   - **App fit:** extend the coach with "explain-the-bug" problems (buggy code +
     output → learner explains → reveal stored explanation), and attach guided
     "why is this line needed?" questions to the walkthrough.

4. **Cognitive Load Theory** — keep intrinsic load appropriate, minimise
   extraneous load; unfamiliar terminology itself raises load for novices.
   *Source: PMC12246501.*
   - **App fit:** inline tap-to-define glossary on first use (have the glossary;
     could auto-link terms in lesson text), spare novice UI, prerequisite-gated
     one-concept microlessons.

5. **Expertise-reversal / faded worked examples** — support that helps novices
   *harms* more advanced learners (meta-analysis: low-prior-knowledge d=+0.505
   from high assistance; high-prior-knowledge d=−0.428). Effect is asymmetrical,
   so **fade conservatively**. *Sources: Tetzlaff et al. 2025; Kalyuga 2007.*
   - **App fit:** a per-concept proficiency signal that, as it rises, shifts
     entry worked-example → Parsons → free coding and lets the learner collapse
     the syntax lens / walkthrough / coach. Make all scaffolds toggleable.

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

The built-in Lessons 1–3 pilot is a bounded application of the rationale above.
Its concept-first segments, working examples, wrong variants, Syntax Microscope,
and recall map to PRIMM's Investigate phase before the guided Modify task. Short
one-concept segments and explicit **Required by Swift** / **Convention** /
**Depends on context** labels apply the documented cognitive-load rationale
around terminology and extraneous load. This is an implementation mapping, not
a claim that the app itself has measured learning effects.

## Roadmap (evidence-ranked)
1. Parsons practice mode ← in progress
2. Explain-the-bug / self-explanation prompts with stored feedback
3. Explicit Modify stage — pilot implemented for built-in Lessons 1–3; full
   curriculum coverage remains deferred
4. Per-concept proficiency + fadeable scaffolds (expertise reversal)
5. Spaced varied-cue review mode — deferred beyond Deep Lesson Pilot v1
6. Inline glossary auto-linking + prerequisite gating (CLT) — deferred beyond
   Deep Lesson Pilot v1

_Split votes (2-1) and single-study / non-programming caveats are noted per
finding; treat exact effect sizes as indicative, not definitive._

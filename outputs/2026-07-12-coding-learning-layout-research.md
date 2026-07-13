# Coding-Learning Lesson Layout Research

Date: 2026-07-12

## Question

What lesson structure and interface should SwiftTutor Apprentice use for a
beginner coding lesson, given the product requirement that a wide,
YouTube-like lesson player is the first thing the learner sees and the rest of
the lesson continues below it?

## Bottom line

No research proves that one page layout is universally best for learning to
code. Product ratings measure satisfaction, not retained programming skill.
The strongest defensible design is:

1. a wide, stable, learner-controlled player first;
2. a compact lesson path directly underneath;
3. immediate retrieval and coding activity below;
4. progressively less scaffolding as the learner demonstrates skill; and
5. later retrieval on a changed problem.

The player belongs in normal page flow and scrolls away naturally. It should
not become sticky in a 680-by-520 window. Playback, narration, captions,
transcript, scene changes, and transport controls remain inside the player and
must never move the outer page, steal focus, resize the player, or disable
manual scrolling.

## Evidence hierarchy

### Stronger general evidence

- **Active learning:** A meta-analysis of 225 undergraduate STEM studies found
  better assessment performance and lower failure under active learning than
  traditional lecture. This supports frequent learner action, not a specific
  app layout or unguided project-first instruction.
  [Freeman et al., 2014](https://doi.org/10.1073/pnas.1319030111)
- **Retrieval practice:** A systematic review of 50 classroom experiments
  found substantial benefits across subjects and delays. A separate controlled
  study found retrieval beat restudy on delayed tests, though the material was
  prose rather than programming.
  [Agarwal, Nunes, and Blunt, 2021](https://doi.org/10.1007/s10648-021-09595-9),
  [Roediger and Karpicke, 2006](https://pubmed.ncbi.nlm.nih.gov/16507066/)
- **Spacing:** A meta-analysis covering 317 experiments found robust benefits
  for distributed rather than massed practice. Exact review intervals depend
  on the intended retention period and should remain a measured product
  policy, not a universal schedule.
  [Cepeda et al., 2006](https://pubmed.ncbi.nlm.nih.gov/16719566/)
- **Worked examples and fading:** Worked examples generally help novices, and
  assistance should decrease as knowledge grows. A 2025 expertise-reversal
  meta-analysis reinforces that high assistance helps low-prior-knowledge
  learners but can become counterproductive for more advanced learners.
  [Barbieri et al., 2023](https://doi.org/10.1007/s10648-023-09745-1),
  [Atkinson, Renkl, and Merrill, 2003](https://doi.org/10.1037/0022-0663.95.4.774),
  [expertise-reversal meta-analysis, 2025](https://doi.org/10.1016/j.learninstruc.2025.102142)
- **Segmented multimedia:** Meta-analytic and review evidence supports
  learner-paced segmentation, signaling of relevant relationships, and
  removing irrelevant decoration. Evidence around modality and duplicate text
  has boundary conditions; it does not justify removing captions or
  transcripts.
  [Rey et al., 2019](https://doi.org/10.1007/s10648-018-9454-0),
  [Richter, Scheiter, and Eitel, 2016](https://doi.org/10.1016/j.edurev.2015.12.003),
  [Sundararajan and Adesope, 2020](https://doi.org/10.1007/s10648-020-09522-4),
  [multimedia-learning review, 2022](https://link.springer.com/article/10.1186/s40561-022-00200-2)
- **Feedback:** Specific task- and strategy-level feedback is more useful than
  a generic correct/incorrect signal. Revealing a complete solution too early
  can remove the productive retrieval and debugging work.
  [Shute, 2008](https://doi.org/10.3102/0034654307313795)

### Programming-specific evidence

- **Subgoal-labeled worked examples:** Programming studies suggest stable
  procedural labels can improve near-term performance and reduce
  withdrawal/failure, but the evidence is moderate and does not show a clear
  average exam advantage.
  [Margulieux, Morrison, and Decker, 2020](https://doi.org/10.1186/s40594-020-00222-7)
- **PRIMM:** Predict, Run, Investigate, Modify, Make is a useful sequencing
  hypothesis. Its prominent study was a nonrandomized school-based
  quasi-experiment with a small post-test effect, so it should not be described
  as universally proven for adult self-study.
  [Sentance, Waite, and Kallia, 2019](https://doi.org/10.1080/08993408.2019.1608781)
- **Tracing and prediction:** Reading and tracing working code can help novices,
  but transfer to independent code writing is limited unless it is followed by
  modification and creation.
  [Kumar, 2013](https://doi.org/10.1145/2462476.2462507),
  [Xie et al., 2018](https://par.nsf.gov/biblio/10107747)
- **Parsons problems:** Rearranging code can reduce blank-page load and is a
  useful optional scaffold. Reviews emphasize heterogeneity and limited
  replication, so Parsons tasks should fade into real editing and writing.
  [Ericson et al., 2022](https://doi.org/10.1145/3571785.3574127)

## Current product patterns

The product review inspected official lesson/help/store surfaces current on
2026-07-12.

- **Khan Academy and Frontend Masters:** familiar player-first pages, with
  transcript, outline, or notes below/alongside. This supports the requested
  spatial convention, not a claim of superior learning outcomes.
- **Scrimba:** makes the recorded code state editable, removing the handoff
  between watching and experimenting. Its core interaction is denser than the
  requested separate player.
- **Codecademy and Hyperskill:** move from explanation/checkpoints into guided
  practice and larger projects. Their multi-pane or IDE handoff models do not
  fit a 680-by-520 window unchanged.
- **Mimo, Sololearn, and Brilliant:** use one dominant task per viewport,
  concise instructions, and immediate feedback. Their strong store ratings are
  satisfaction signals rather than independent learning evidence.
- **freeCodeCamp:** progresses from short theory into workshops, labs, reviews,
  and quizzes, reinforcing the value of quick movement from explanation to
  production.

Selected current rating snapshots:

- [Mimo: 4.9/5, about 109K US App Store ratings](https://apps.apple.com/us/app/mimo-learn-coding-programming/id1133960732)
- [Sololearn: 4.8/5, about 81K US App Store ratings](https://apps.apple.com/us/app/sololearn-learn-to-code/id1210079064)
- [Brilliant: 4.7/5, about 31K US App Store ratings](https://apps.apple.com/us/app/brilliant-learn-math-coding/id913335252)
- [Codecademy Go: 4.8/5, about 38K US App Store ratings](https://apps.apple.com/us/app/codecademy-go/id1376029326)
- [Frontend Masters: 4.7/5, about 333 US App Store ratings](https://apps.apple.com/us/app/frontend-masters/id1383780486)

## Recommended SwiftTutor lesson page

### 1. Global lesson header

Keep Home/back, lesson identity, and completion status compact. This header is
not part of the media surface and does not resize during playback.

### 2. Wide player first

- Full available lesson-column width, 16:9 aspect ratio, stable reserved frame.
- Poster is paused by default; motion and speech start only through explicit
  learner action.
- Scene visual, code tokens, values, output, captions, transcript, narration,
  and all transport controls stay inside the frame.
- Use familiar native macOS control conventions and keyboard behavior.
  [Apple HIG: Playing video](https://developer.apple.com/design/human-interface-guidelines/playing-video),
  [AVPlayerView](https://developer.apple.com/documentation/avkit/avplayerview)
- At a 680-pixel content width, approximately 632-640 usable pixels produce a
  356-360 pixel 16:9 player. That intentionally fills most of the first view.
- The player is not sticky. It scrolls away when the learner moves into the
  lesson.

### 3. Lesson title, objective, and path

Immediately below the player, show:

- lesson title and one plain-language objective;
- a compact path: `Watch -> Recall -> Modify -> Practice/Run`;
- current status without locks, streak pressure, or mastery claims.

The path orients the learner; it should not become a permanently visible side
rail or a second scroll surface.

### 4. One vertical lesson flow

The same outer page continues through:

1. **Recall:** predict output or explain the causal change without replay cues.
2. **Investigate:** compare prediction with actual output and trace the relevant
   line/value/state.
3. **Modify:** change one part of working code with progressive help.
4. **Practice/Run:** solve a small changed problem with less scaffolding.
5. **Reflect/Review:** state the takeaway and later retrieve it in a different
   context.

This preserves the current SwiftTutor labels while adding the evidence-backed
Predict/Investigate mechanics inside Recall and Practice rather than adding a
new mode-switching interface.

## Non-negotiable interaction contract

- Play, pause, seek, scene changes, narration, captions, and transcript do not
  call outer `scrollTo`, change the outer scroll offset, move focus outside the
  invoked player control, open a sheet, resize/expand the player, or disable
  outer hit testing.
- The learner can wheel, trackpad-scroll, and keyboard-scroll the page during
  narration.
- Player frame height is identical for poster, playback, paused, caption, and
  transcript states. Transcript opens inside a bounded player region.
- There is no autoplay, sticky mini-player, automatic transcript expansion, or
  narration-follow scrolling.
- Keyboard and VoiceOver can enter, operate, and leave every control without a
  trap. Captions and a text transcript remain available.
  [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility),
  [W3C accessible media player guidance](https://www.w3.org/WAI/media/av/player/)

## Evaluation gates

### UI regression

- During at least 60 seconds of playback/narration, repeated mouse, trackpad,
  and keyboard scrolling remains available.
- Play/pause/seek/scene/narration changes move the outer scroll offset by no
  more than one point and do not change outer focus.
- No clipping or control loss at the 680-by-520 minimum and larger sizes.

### Accessibility

- Keyboard and VoiceOver can reach and leave every player control.
- Captions, transcript, visible focus, Reduce Motion, and logical reading order
  pass in the real app.

### Learning outcomes

- Measure immediate Recall and independent transfer, then delayed retrieval;
  do not use watch time, completion, replays, or star ratings as proof of
  learning.
- Track hint use, retries, time to successful independent change, and errors
  that recur on a changed task.

## Claims to avoid

- “A YouTube layout is scientifically proven best.”
- “High app-store ratings prove learning effectiveness.”
- “Watching or narration demonstrates mastery.”
- “PRIMM or Parsons problems are universally superior.”
- “A separate player automatically reduces cognitive load.”

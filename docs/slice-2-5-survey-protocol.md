# Slice-2.5 Survey Protocol

> **Charter:** [[2026-05-02-slice-2-5-named-tuning-pass]]. Slice-2.5 is a tuning ratification, not a feature build. Output is decisions; code lands only if a rejection predicate is ratified.

This is the one-pager you drive the survey from. Director frame + Critic tightenings + user calls A2 (defer same-as-prior-seed) and B (accept all four pre-commitments). Print or pin -- do not modify mid-survey.

## 1. Degeneracy definitions (Director, felt-experience)

One sentence each. These are what you are looking for as you eyeball each generated world.

- **Hub-and-spoke.** One node so central nearly every viable route passes through it; pillar 1's route choice collapses into "go through the hub."
- **Free-lunch.** A short edge whose price spread will reliably exceed travel cost under any plausible pricing; the kernel is gone for that edge's lifetime.
- **Dominant routes.** One path so much better than alternatives the player stops comparing routes; pillar 1 collapses to "find the obvious loop, run it." (Out of scope to confirm in slice-2.5 -- requires running the economy. Note suspects only.)
- **Planarity.** Edge crossings only matter when they make the topology unreadable; the player can't see at a glance which nodes connect to which.
- **Starting-node sameness.** **Deferred to slice-3+ per user call A2.** Eyeballing 20 silent boots can't answer a play-feel question; revisit when actual play does the comparison work.

## 2. Per-seed row (5 fields)

Three from the log line (verbatim, no eyeball needed), two by eye.

| field | source | type |
|---|---|---|
| `seed` | log line (incl. `effective=` if bumped, formatted `12345->12347`) | int or "N->M" |
| `nodes / edges` | log line | "K/M" |
| `min/max edge dist` | log line | "d/D" |
| `hub-y?` | eye | y / n / borderline |
| `free-lunch suspect?` | eye (short edge between visually-distant-feeling nodes) | y / n / borderline |
| `notes` | optional | free text -- planarity issues, low node count, repeat-bumps, anything weird |

## 3. Pre-commitments (Critic, binding -- decide once, apply 20 times)

These are the survey-loop tightenings. If any of them slip, the data is corrupted.

1. **Stdout capture method:** PowerShell launch helper at `tools/survey.ps1` (gitignored -- local-only because it pins a machine-specific Godot path). Deletes the save, launches Godot with `--seed=N`, and tees stdout to `slice-2-5-survey.log` (append). One file, all 20 runs, log lines preserved verbatim. Usage: `./tools/survey.ps1 42`. **Do not** rely on terminal scrollback or memory.
2. **Save deletion:** the helper deletes `%APPDATA%\Godot\app_userdata\Medieval Trader\save.json` before every launch. Verify on seed 1 by checking the file is gone before the game window opens. If a stale save loads (boot without `worldgen:` line, or wrong seed in StatusBar), the row is bogus -- delete the save by hand and re-run.
3. **Borderline rule:** `hub-y?` and `free-lunch suspect?` default to **n**. Reserve `borderline` for cases where you would argue both sides for 30+ seconds. Borderline is a tail category, not a modal escape hatch.
4. **Hard 20-cap.** Twenty seeds, stop at twenty. No early stop on apparent patterns (confirmation bias). No "let me run 20 more" if results are ambiguous (sprawl). Tail ambiguity defers to slice-3+ play, period.

### Edge-case pre-commits (also binding)

- **Effective-seed bumps fire.** Record as `12345->12347` in the `seed` column; treat as a normal row. If bumps fire on >3 of 20, that's a retry-logic flag for slice-3+, not a row to discard.
- **Low node count (< target).** Record the row, flag in `notes`, do **not** retry the seed. The survey samples what the generator produces.
- **Stop condition.** Twenty hard. No early termination. No continuation past 20.

## 4. "No, unless" -- when a threshold gets cut from enforcement (default = accept entropy)

Enforcement requires affirmative evidence the kernel is breaking, not absence of evidence it's safe.

1. **Appears 0-1 times in 20:** don't enforce. Revisit if it shows up in slice-3+ play.
2. **Appears but doesn't break the kernel on inspection:** the visual heuristic was misleading. Move on.
3. **Threshold needs systems not yet built** (e.g., free-lunch needs pricing): defer enforcement. **See cross-slice owe-note in §6.**
4. **Appears only on edge cases** (effective-seed bumps, retries): tighten retry logic, not add a rejection predicate.

## 5. Out of scope (do not let the survey sprawl)

- Price tuning, spread distributions, anything pricing-related.
- Anything requiring gameplay loops (dominant-route confirmation, travel-cost feel, "does this world play well").
- Node-type behaviour (city/town/village).
- Edge attributes beyond distance.
- New rejection criteria the survey reveals -- capture in `notes`, do not let new criteria join the four named threads mid-survey. They become slice-2.5 follow-up candidates or slice-3 inputs.
- Generator code changes during the survey. Patching mid-inspection invalidates prior rows.
- MapPanel polish. If a degeneracy is hard to see, that's data ("we couldn't tell"), not a reason to redesign.

## 6. Cross-slice owe-note (capture at session close)

Free-lunch ratification is deferred to whichever slice introduces price spreads. That slice **owes a topology-revisit step** -- look at the slice-2.5 survey data with pricing in hand, decide whether free-lunch needs a topology rejection predicate or a pricing constraint instead. Capture as a Decision Scribe entry at slice-2.5 close so the carryover doesn't go silent.

## 7. Verdicts after 20 rows -- what comes next

For each named thread (hub, free-lunch, planarity), one of three outcomes:

- **Enforce in generator.** Predicate + threshold ratified; Designer/Architect/Engineer pipeline lands the rejection rule.
- **Accept entropy.** Threshold not enforced; revisit signal recorded for slice-3+.
- **Defer with owe-note.** Slice-3+ owns the question; cross-slice owe-note logged.

Director + Critic + user converge on the verdicts. Decision Scribe writes one decision per thread.

## 8. Time budget

45-75 minutes for 20 seeds, including judgement time on borderlines. If you blow past 90 minutes, stop and re-read this protocol -- something is sprawling.

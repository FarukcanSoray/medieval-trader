---
title: Slice-2.5 survey is a hard 20-seed cap with no tail extension
date: 2026-05-02
status: ratified
tags: [decision, slice-2-5, survey, scope, sprawl-prevention]
---

# Slice-2.5 survey is a hard 20-seed cap with no tail extension

## Decision

The slice-2.5 seed survey runs exactly 20 seeds. No early termination on apparent patterns (confirmation bias). No continuation past 20 if the tail produces ambiguous suspects.

If seeds 18-20 land on suspect cases that are genuinely ambiguous, the verdict is **"tail entropy, defer to slice-3+ play,"** not "run 20 more seeds to see if it stabilises."

## Reasoning

Critic flagged the sample-size scaling risk: ambiguity at the tail tempts the user into extending the run. Once 20 becomes 40 it becomes 60, and the dump_catalog helper that the log-line decision explicitly rejected ([[2026-05-02-slice-2-log-line-only-no-dump-catalog]]) starts looking reasonable. That trajectory is slice-2.5 sprawl in disguise and contradicts the thin scope ratified in [[2026-05-02-slice-2-5-named-tuning-pass]].

Pre-committing to 20 as a hard budget closes both loopholes (early stop, late extension) before the survey starts, when the user is still cool-headed.

## Alternatives considered

- **Run until ambiguity resolves.** Rejected. Open-ended scope is the sprawl mechanism.
- **Start at 20 with explicit option to extend.** Rejected. Critic identified this as the actual sprawl pattern -- "let me run 20 more" begins as a reasonable request and ends as a 60-seed catalog.
- **Allow early stop if patterns are obvious by seed 8-10.** Rejected. Confirmation bias (seeing what you expect) is the failure mode of early-stop.

## Confidence

High. User explicitly accepted pre-commitment B (which includes this cap); Critic's sprawl analysis named the failure pattern directly.

## Source

This session (2026-05-02 PM, slice-2.5 framing). Critic stress-test "Sample-size scaling risk" section; user binding call B.

## Related

- [[2026-05-02-slice-2-5-named-tuning-pass]] -- the thin scope this cap protects.
- [[2026-05-02-slice-2-log-line-only-no-dump-catalog]] -- the artifact a 60-seed catalog would re-litigate.
- [[slice-2-5-survey-protocol]].

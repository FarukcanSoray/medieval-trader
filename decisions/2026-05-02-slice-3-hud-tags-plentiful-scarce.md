---
title: HUD bias tags = `(plentiful)` / `(scarce)` (amends source/sink choice)
date: 2026-05-02
status: ratified
tags: [decision, slice-3, hud-legibility, amendment, playtest-driven]
---

# HUD bias tags = `(plentiful)` / `(scarce)` (amends source/sink choice)

## Decision
The node-panel bias tags read `(plentiful)` for negative-bias goods (cheap; the node has surplus) and `(scarce)` for positive-bias goods (expensive; the node has shortage). This **amends** [[2026-05-02-slice-3-hud-source-sink-syntax-no-numbers]] which used `(source)` / `(sink)`.

The framework from the prior decision still holds: ASCII parens, lowercase, single word, bias number not exposed.

## Reasoning
Playtest signal: user reported `(source)` / `(sink)` as not understandable. Tested two replacement framings:

- `(cheap)` / `(dear)` -- price-effect framing; concrete but "dear" reads as British-English
- **`(plentiful)` / `(scarce)`** -- supply-effect framing; describes the underlying world state rather than its consequence
- `(buy here)` / `(sell here)` -- action-oriented; rejected because it collides visually with the existing Buy/Sell buttons in the same row
- `(makes)` / `(needs)` -- verb-form; was a candidate but user picked supply-effect

Supply-effect framing wins on Pillar 1 (legibility): "this town has scarce wool, so wool is expensive here" is the causal chain the player should learn. Price-effect framing (`cheap`/`dear`) skips the cause and only shows the consequence; the player still has to infer "why is it cheap?" themselves. Supply-effect framing names the cause, so the player builds a mental model of the world that explains the prices.

## Alternatives considered
- `(source)` / `(sink)` -- original choice; rejected at first playtest as not understandable.
- `(cheap)` / `(dear)` -- clear and short, but skips the cause and "dear" is dialectal.
- `(buy here)` / `(sell here)` -- direct but visually collides with adjacent button labels.
- `(makes)` / `(needs)` -- verb-oriented; viable, just not picked.

## Confidence
Medium-high. Word choice is reversible cheaply (one Edit on `node_panel.gd`); the playtest signal that triggered the change was concrete (user said the prior wording didn't read).

## Source
First playtest of slice-3 on 2026-05-02. User direction.

## Related
- [[2026-05-02-slice-3-hud-source-sink-syntax-no-numbers]] -- prior decision this amends; framework (ASCII, no numbers) preserved
- [[2026-05-02-slice-3-tags-as-label-not-driver]] -- still holds; tags are a label of bias, derivation unchanged
- [[2026-05-02-slice-3-tags-in-slice]] -- prior decision noted "if playtest shows the tag isn't legible enough, escalate to numbers in slice-3.x"; this amendment is the lighter-weight option (better words instead of numbers)

## Amendment 2026-05-02 (post-slice-4-playtest): tag/price visible inversion is intended

During slice-4 playtest, user observed: `wool 10g (untagged)` and `wool 11g (plentiful)` simultaneously across two nodes. Asked whether this was a bug.

**Verdict: not a bug; intended behaviour.** The tag reflects **structural identity** (the node's bias from `world_seed` -- think "this town has wool workshops / sheep / looms"). The displayed price is `anchor + drift`, where `anchor = base_price * (1 + bias)` and drift fluctuates each tick. The two can disagree at any single moment; over many ticks the plentiful node's wool averages lower than the untagged node's wool. Mean-reversion (`MEAN_REVERT_RATE = 0.10`) pulls drift back toward the anchor.

**Fictional framing the user accepted:** "A plentiful town is a structural producer. Today's price might be high (bad shearing week, passing army buying cloaks) but it'll trend back down. The tag teaches you about the town's identity, not the moment's deal." This framing earns the visible-inversion behaviour as world-feels-alive rather than tag-lies.

**Slice-3.x tuning option preserved (not invoked):** if a future playtest shows inversion happens too often and the player loses faith in the tag, the path is to lower wool's `volatility` (currently 0.10) or raise `WorldRules.MEAN_REVERT_RATE` (currently 0.10). The structural design holds; only the bias-vs-drift balance would tune.

**Constraint surfaced for future tuning:** with the current free-lunch predicate, wool's bias range is clamped to ~`±0.17`, putting plentiful anchors at ~10-11g vs untagged at ~11-13g -- a ~1-2g structural gap, easily inverted by ~1g per-tick drift. Lowering volatility would simultaneously *widen* the bias headroom (the predicate would allow larger bias ranges) and *narrow* the drift envelope. Two-for-one.

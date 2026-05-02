---
title: No mid-encounter choice UI; the choice lives in route selection
date: 2026-05-02
status: ratified
tags: [decision, slice-4, design, pillar-1, encounters]
---

# No mid-encounter choice UI; the choice lives in route selection

## Decision
Bandit encounters resolve automatically — there is **no fight/flee/pay choice UI** during travel. The player's choice point is at *route selection* (whether to take a `(bandit road)`-tagged edge given its expected cost).

## Reasoning
Career-merchant fantasy + Pillar 1 both demand the same thing: the player wins by reasoning *before* committing. A mid-travel choice UI is a gut-reaction surface — exactly the twitch-adjacent thing the project brief rules out. The math problem is "is this 12g, 4-tick `(bandit road)` route worth taking given my carried gold and the spread waiting at the destination?", not "do I press 1 or 2 when the bandits show up."

This decision was load-bearing for compressing slice-1 §10's "four mini-systems" warning to three subsystems (trigger + readback + tag, no choice UI).

## Alternatives considered
- **Mid-travel fight/flee/pay menu** — rejected as twitch-adjacent and Pillar 1-violating.

## Confidence
High. Director rooted in Pillar 1 + careful-merchant fantasy; Critic accepted as the right compression.

## Source
Director scoping pass.

## Related
- [[2026-04-29-fantasy-careful-merchant]]
- [[project-brief]] — anti-goal "no combat-as-skill"
- [[slice-spec]] §10 — the four-mini-systems warning this decision answers

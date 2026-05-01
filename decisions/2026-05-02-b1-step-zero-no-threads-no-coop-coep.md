---
title: B1 Step 0 drops COOP/COEP check; no-threads build is the canonical target
date: 2026-05-02
status: ratified
tags: [decision, b1, web-export, no-threads, supersedes]
---

# B1 Step 0 drops COOP/COEP check; no-threads build is the canonical target

## Decision

B1's Step 0 no longer requires the tester to confirm `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` on the served HTML response. Step 0 now requires only that the Godot canvas reaches the in-game main menu (or the boot scene's terminal state) without console errors referencing SharedArrayBuffer, threading, or cross-origin isolation.

The reason is that the project's distribution build is the **no-threads** Godot Web variant (`thread_support=false`, `ensure_cross_origin_isolation_headers=false` in `godot/export_presets.cfg`), which does not use `SharedArrayBuffer` and therefore does not require cross-origin isolation. itch.io is the canonical hosting target and does not serve COOP/COEP by default; testing the threaded variant against a different host would test a build that does not ship.

This decision **supersedes** [[2026-05-01-b1-coop-coep-verification-step-zero]].

If the project later switches to the threaded variant for any reason (performance, threading-dependent feature), this decision lapses and the COOP/COEP requirement is reinstated.

## Reasoning

Godot's no-threads HTML5 variant exists precisely so SharedArrayBuffer is not required at runtime. The threaded variant requires COOP/COEP because it relies on SharedArrayBuffer for thread synchronization; the no-threads variant compiles without that dependency.

The 2026-05-01 Step 0 decision was authored before the export preset was flipped to no-threads later that same day (commit 8d500a2). The runbook's Step 0 and the actual deploy path were therefore in conflict from the moment the preset changed: a tester following Step 0 against the itch.io build would hard-fail Step 0 by infrastructure design, halt B1, and route to web-deployer for a header issue that does not apply to the no-threads variant. That is a runbook bug, not a deployer bug.

The principle Step 0 was protecting — *do not run iterations 1-6 against an export that is not in a runnable state* — still applies. The check now reads "canvas reaches main menu" because that is the no-threads-equivalent precondition: if the build does not boot, the iterations are invalid regardless of why.

## Alternatives considered

- **Run B1 on a separate threaded build hosted somewhere with COOP/COEP** (e.g. local server with custom headers, Netlify, Cloudflare Pages). Rejected — B1 must test what ships. Maintaining a parallel threaded build for testing creates a divergence the harness cannot detect.
- **Switch hosts off itch.io to one that serves COOP/COEP, ship threads on.** Rejected as larger blast radius than the conflict warrants. itch.io + Butler + the deploy workflow are already wired; the no-threads build is a stable Godot-supported variant.
- **Keep the COOP/COEP check, accept that Step 0 will fail on itch.io and route to web-deployer every time.** Rejected — that is the conflict, not a resolution.
- **Run the pipeline (Director -> Designer -> DS) to ratify the override.** Rejected by user during the implementation step where the conflict surfaced. The choice resolves a runbook/preset mismatch rather than a design question; the standing project workflow does not require pipeline arbitration for runbook corrections.

## Confidence

High. The conflict is mechanical (no-threads does not need COOP/COEP) and the resolution restores Step 0 to its original purpose.

## Source

- Conflict surfaced during the 2026-05-02 web-deployer handoff prep, when reading [[2026-05-01-b1-coop-coep-verification-step-zero]] against `godot/export_presets.cfg` (post-8d500a2) and `.github/workflows/deploy.yml`.
- User ratified option A in conversation.

## Related

- [[2026-05-01-b1-coop-coep-verification-step-zero]] — superseded by this decision
- [[b1-test-protocol]] — Step 0 prose updated to match
- `godot/export_presets.cfg` — `thread_support=false` is the load-bearing fact

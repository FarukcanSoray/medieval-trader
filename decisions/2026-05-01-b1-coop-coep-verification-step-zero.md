---
title: B1 protocol Step 0 — verify COOP/COEP headers before running iterations
date: 2026-05-01
status: superseded
superseded_by: 2026-05-02-b1-step-zero-no-threads-no-coop-coep
tags: [decision, b1, web-export, verification, superseded]
---

> **Superseded 2026-05-02** by [[2026-05-02-b1-step-zero-no-threads-no-coop-coep]]. The export preset was flipped to no-threads later on 2026-05-01 (commit 8d500a2) for itch.io compatibility, after which the COOP/COEP check was no longer applicable to the canonical build. Step 0 now requires only that the canvas reaches main menu. The original prose below stands as the record of what was originally ratified.

# B1 protocol Step 0 — verify COOP/COEP headers before running iterations

## Decision

B1's test protocol begins with **Step 0 — COOP/COEP verification**, executed before any of the six refresh-mid-travel iterations. The tester opens the HTML5 build via the local server, opens DevTools → Network, hard-reloads, inspects the top-level HTML response headers, and confirms:

- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`

The tester also confirms the Godot canvas reaches the main menu before proceeding. **If Step 0 fails (header missing or canvas stalled), B1 halts and routes to web-deployer**; iterations 1–6 do not run until Step 0 is green.

Implementation of the headers is web-deployer's lane (host config). Verification of correctness is B1's lane (gates iteration validity).

## Reasoning

Designer's call: COOP/COEP correctness gates whether the export *loads at all* — Godot 4.5's HTML5 export uses SharedArrayBuffer, which requires cross-origin isolation. If the headers are wrong, the canvas may still render but threading and IndexedDB behavior diverge from the reference desktop build. A tester staring at a blank canvas, or a tester running iterations 1–6 against a partially-broken export, might mis-attribute failures to save logic rather than infrastructure.

Step 0 is materially different from B1's deferred cross-browser parity: parity is about reproducing across engines, Step 0 is about whether iteration 1 is even valid in the chosen browser. A test whose validity precondition is unverified produces results that don't generalize.

The ownership split (web-deployer implements, B1 verifies) keeps the boundary clean: web-deployer owns host config, headers, and hosting choices; B1 reads the resulting Network panel to confirm those choices land. This mirrors the harness/runbook boundary established elsewhere in B1.

## Alternatives considered

- **Trust web-deployer's setup; assume headers correct**: rejected. The cost of verification is one DevTools panel inspection; the cost of running iterations 1–6 against a broken export is misattributed bug reports.
- **Bundle COOP/COEP into web-deployer's lane entirely (no B1 step)**: rejected. Web-deployer doesn't know whether the test will run successfully against their export — they ship the export, B1 confirms it's in a runnable state.
- **Make Step 0 part of every iteration rather than once-up-front**: rejected. Headers don't change between iterations; once-per-session is sufficient.

## Confidence

High. Designer's framing was tight (gate vs. parity); web-deployer boundary was already established.

## Source

- Designer's second pass (COOP/COEP ruling on Architect's open question).

## Related

- [[2026-05-01-save-invariant-checker-harness-no-autoload]] — the Architect/web-deployer boundary established alongside this
- [[b1-test-protocol]] — §2 (Step 0) is the artifact this decision produces

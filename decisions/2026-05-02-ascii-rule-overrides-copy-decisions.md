---
title: ASCII-only UI rule overrides ratified copy decisions until a custom font ships
date: 2026-05-02
status: ratified
tags: [decision, precedence, ui, ascii, copy, standing-rule]
---

# ASCII-only UI rule overrides ratified copy decisions until a custom font ships

## Decision

When a ratified copy decision specifies a UI string containing glyphs forbidden by the standing ASCII-only rule (em-dash, en-dash, fancy quotes, ellipses, Unicode arrows, etc.), the standing rule wins. The implementation ships the ASCII substitute (`--`, `'...'`, `...`, `->`, etc. per CLAUDE.md), and **both** files get cross-reference footnotes:

- A WHY-comment at the substitution site naming the original copy decision and the standing-rule decision.
- A footnote on the original copy decision recording the substitution as-implemented.

The original copy decision is not rewritten — its prose stands. The footnote is the bridge.

This precedence holds **until a custom font is bundled into the project theme** with glyph coverage for the affected characters. At that point the ASCII rule (and this precedence rule) lapses for the covered characters, and the original copy decisions become canonical again as written.

## Reasoning

Surfaced by the B1 harness implementation. Decision [[2026-05-01-save-corruption-regenerate-release-build]] specified the corruption toast as `"Save was corrupted — beginning anew"` (em-dash, register-matched to past-participle precedents in the slice). The standing rule from CLAUDE.md and [[2026-05-01-ascii-arrows-in-ui-strings]] forbids em-dashes in UI strings because Godot's HTML5 default font has no glyph and tofus the character. The Engineer downgraded to `--` and added a code comment at `godot/ui/hud/status_bar.gd:7-11` explaining the conflict.

The conflict will recur — the slice's tone register (past-participle, em-dash-friendly) and the slice's hard target (web export, ASCII-only) pull in opposite directions until the font is bundled. Logging the precedence rule once is cheaper than re-litigating the tiebreaker each time.

The choice not to rewrite the original copy decision is deliberate: rewriting would lose the canonical copy that becomes correct again post-font-bundling, and would erase the record of what was originally ratified. A footnote preserves both states.

## Alternatives considered

- **Rewrite the original copy decision to specify the ASCII substitute as canonical.** Rejected — discards the post-font-bundling correct form and erases the original ratification.
- **Silent downgrade with no cross-reference.** Rejected — invisible conflicts are exactly what bites future readers when they grep for the toast text.
- **Update the standing ASCII rule to defer to copy decisions.** Rejected — defeats the rule's purpose. The rule exists because the web-export font cannot render the glyphs *at all*; "preserve the copy decision's character" loses to "the character renders as a tofu box for every web player."
- **Bundle the custom font now.** Out of scope this session and possibly portfolio-cycle; bundling a font has its own asset and licensing surface.

## Confidence

Medium. The concrete choice (`--` substitute) is settled and correct. The precedence rule is inferred from the Engineer's action plus the Director's standing-rule framing on related ASCII decisions; no explicit conversation in this session ratified the abstract precedence rule. Logging at medium confidence so future glyph collisions can either lean on this precedent or surface a more emphatic ruling.

## Source

- B1 Engineer round, code at `godot/ui/hud/status_bar.gd:7-11` (the substitution comment) and `godot/ui/hud/status_bar.tscn:39` (the substituted text).
- Decision Scribe candidate [1] from this session's extraction; user ratified [1] only.

## Related

- [[2026-05-01-save-corruption-regenerate-release-build]] — the copy decision whose toast was downgraded under this precedence rule
- [[2026-05-01-ascii-arrows-in-ui-strings]] — the precedent ASCII rule for `->` substitution
- [[CLAUDE.md]] — project-level standing rule that the ASCII substitution lives under

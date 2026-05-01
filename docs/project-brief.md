# Project Brief — Medieval Trader

## One-line pitch
A turn-based medieval trading sim where arbitrage profit and travel cost sit in permanent tension — one trader, one life, one knowable economy per world.

## Kernel
Arbitrage profit only matters because travel costs bite, and travel only matters because there's profit waiting at the other end. Neither side works alone.

## Player fantasy
The careful merchant. The player is a calculating accountant who feels smart when a route pays off. Mastery comes from reading the system — prices, distances, risks — and committing to the route that the numbers say is best.

## Pillars (3)
1. **Every trade decision is a math problem the player can win.** The economy is legible; profit is earned by reasoning, not luck. Justification: protects the "careful merchant" fantasy and rules out hidden information that would convert mastery into gambling.
2. **Travel always costs something the player feels.** Distance, time, supplies, risk — moving is never free. Justification: protects the kernel directly. Without bite, arbitrage is trivial and the game collapses to a spreadsheet.
3. **One trader, one economy, one outcome.** A run is a single coherent life inside a single coherent world; choices accumulate. Justification: protects the weight of decisions and the meaning of permadeath. Rules out reset-spam play.

## Scope frame
Small complete game. ~3–6 months of evening work. One full economic system, one map generator, one event system, one save slot, 1–3 hour expected first-death playtime. Desktop + web export from day one.

## What's in
- Procedurally generated map: nodes (cities/towns/villages) and edges (routes) with distances and route attributes.
- Procedurally generated price tables per node, refreshed on a tick cadence.
- A small fixed catalogue of goods (hand-authored, not procgen) — likely 6–12 items with stable identities so the player can build mental models.
- Travel as a discrete action that consumes resources (time, supplies, possibly cart capacity).
- Abstracted encounters: bandits, weather, spoilage, tolls — resolved as economic outcomes (gold/goods loss, delays, injury).
- A single persistent save: one trader, ages over time, dies on one of: violent encounter outcome, starvation/ruin, old age.
- A run-end screen on death: stats, route history, final ledger.

## What's out (anti-goals)
- No crafting or production chains.
- No city-building or settlement management.
- No combat-as-skill (no twitch, no tactics layer).
- No reputation or faction systems.
- No multi-role gameplay (not also a farmer, knight, ruler).
- No multiplayer, no real-time, no story, no named characters.

## Open design questions (deferred to Systems Designer)
- Travel-cost formula shape: linear, distance-squared, supply-consumption-driven, or hybrid.
- Price elasticity model: static-per-tick, demand-responsive to player actions, or regional shocks.
- Map node count and graph density appropriate for 1–3h first runs and web export budget.
- Tick cadence and how player actions advance time relative to economic refresh.
- Event frequency and severity curves; how risk scales with route choice.
- Death cause weighting — what kills the trader, how often, and how telegraphed.
- Whether goods catalogue is fully static or partially seeded per world.

## Tensions resolved during intake
**Careful-merchant fantasy vs. permadeath.** Resolved toward **death rare and earned**. The player's mastery is in-world (this trader, this map, this economy), not meta across saves. Death is the punctuation that gives the run weight, not a roguelite reset cadence. Designer should tune so a competent player's first death lands hours in, usually from compounded bad decisions or one ignored risk — not from a single unavoidable roll. Old age is a real ending.

**Full procgen vs. knowable system.** Resolved by **scope splitting**: the *world* is procgen (map shape, node placement, price tables, event seeds), but the *vocabulary* is hand-authored and stable (the goods catalogue, the encounter types, the cost structures). Mastery transfers as procedural reasoning — "wool-to-cloth corridors exist, find this world's" — not as memorized geography. This also helps web export: procgen is cheap, hand-authored places are not.

**Ambitious scope for a first AI-developed solo project.** Acknowledged. The slice above is deliberately one of each system, not several. Polish, tuning, and a single death-screen are the finish line — not multiple biomes, multiple trader archetypes, or post-death meta-layers. Scope Critic will pressure-test this next.

**No win + permadeath outcome shape.** Resolved: the game is a sandbox with one terminal punctuation. There is no victory screen; there is a death screen that summarises the life. Players leave with a story ("my trader lived 47 years and died crossing the northern pass with 800 gold"), not a verdict.

## Pipeline next steps
1. **Scope Critic** — adversarial review of "What's in" against the 3–6 month frame and web export target.
2. **Systems Designer** — take the open questions above and propose concrete models for the core loop.
3. Director remains available for fit-to-pillar checks as new proposals surface.

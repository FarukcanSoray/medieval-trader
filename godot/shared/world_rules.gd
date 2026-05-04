## Static-method holder for cross-system world rules. Never instantiated.
## Owns the canonical travel-cost formula so DeathService and TravelController
## can't drift apart.
class_name WorldRules
extends Object

# Travel cost per edge-distance unit. Slice-spec §6 range 2–5; 3 matches the §5 worked example.
# [needs playtesting] — kernel-tuning surface. Cost must chew 20–50% of a typical
# spread or the kernel collapses (slice-spec §6 commentary).
const TRAVEL_COST_PER_DISTANCE: int = 3

# Wall-clock duration of one travel tick, in seconds. Drives TravelController's
# per-step yield so a journey is perceptible rather than instant.
# Validated 2026-05-02 via extended playtest.
const TICK_DURATION_SECONDS: float = 0.45

# Slice-3 pricing constants. See docs/slice-3-pricing-spec.md §6.
# Slice-8 retires bias from the price formula but keeps it as the tag-derivation
# seed (decision: 2026-05-04-slice-8-bias-role-narrowed-to-tag-seed). MEAN_REVERT_RATE
# is removed -- pull-driven prices have no drift state to revert. BIAS_* constants
# stay because _author_bias still uses them to seed produces/consumes tags.
const BIAS_MIN: float = -0.40
const BIAS_MAX: float = 0.40
const MIN_BIAS_RANGE: float = 0.20
const PRODUCER_THRESHOLD_FRACTION: float = 0.5
const CONSUMER_THRESHOLD_FRACTION: float = 0.5

# Slice-4 encounter constants. See docs/slice-4-encounters-spec.md §6.
const BANDIT_ROAD_FRACTION: float = 0.35
const BANDIT_ROAD_PROBABILITY: float = 0.30
const BANDIT_GOLD_LOSS_MIN_FRACTION: float = 0.05
const BANDIT_GOLD_LOSS_MAX_FRACTION: float = 0.20
const BANDIT_GOLD_LOSS_HARD_CAP: int = 30
# Day-2 (goods loss) — read by EncounterResolver in the Tier D pass.
const BANDIT_GOODS_LOSS_FRACTION: float = 0.50

# Slice-6 cargo constants. See docs/slice-6-weight-cargo-spec.md §6.
# Single hard cap shared across all goods; the buy gate refuses when
# current_load + good.weight > CARGO_CAPACITY. Value backed by the
# decision-divergence harness (tools/measure_cargo_decision_divergence.gd).
# Slice-6.1 promotes this to a TraderState field if capacity ever varies
# per-trader; until then, the constant is the seed.
const CARGO_CAPACITY: int = 60

# Slice-7 stock multipliers. See docs/slice-7-production-caps-spec.md §6.2.
# Cap and refill-rate per (node, good) are derived at world-gen time as
# Good.base_stock_cap * cap-mult and Good.base_refill_rate * rate-mult, where
# the multiplier is selected by the per-node tag (good in produces -> plentiful,
# good in consumes -> scarce, neither -> neutral).
#
# Slice-8 §5.8: 5x supply-cap bump. The factor is calibrated against the +/-5%
# perturbation envelope so a per-buy curve move (~5% of base for a 4-unit buy
# at cap=80) sits within perturbation noise. Decision:
# 2026-05-04-slice-8-5x-supply-cap-bump-rationale.
const STOCK_CAP_MULT_PLENTIFUL: float = 20.0
const STOCK_CAP_MULT_NEUTRAL: float = 5.0
const STOCK_CAP_MULT_SCARCE: float = 1.25
const REFILL_MULT_PLENTIFUL: float = 5.0
const REFILL_MULT_NEUTRAL: float = 1.0
const REFILL_MULT_SCARCE: float = 0.2

# Slice-8 demand multipliers. See docs/slice-8-pricing-v2-spec.md §5.7.
# Per-(node, good) demand cap and decay rate are derived at world-gen time as
# Good.base_demand_cap * cap-mult and Good.base_demand_decay_rate * rate-mult,
# where the multiplier is selected by the per-node tag inverse to supply:
# good in produces -> producer (low demand), good in consumes -> consumer
# (high demand), neither -> neutral. Decision:
# 2026-05-04-slice-8-demand-multiplier-inverse-supply.
const DEMAND_CAP_MULT_PRODUCER: float = 0.25
const DEMAND_CAP_MULT_NEUTRAL: float = 1.0
const DEMAND_CAP_MULT_CONSUMER: float = 4.0
const DEMAND_DECAY_MULT_PRODUCER: float = 0.2
const DEMAND_DECAY_MULT_NEUTRAL: float = 1.0
const DEMAND_DECAY_MULT_CONSUMER: float = 5.0

# Slice-8 perturbation envelope. +/-5% multiplicative on the curve output,
# seeded as hash([world_seed, tick, node_id, good_id, side]). Decision:
# 2026-05-04-slice-8-pool-curve-formula-locked.
const PERTURBATION_FRACTION: float = 0.05

static func edge_cost(e: EdgeState) -> int:
	return e.distance * TRAVEL_COST_PER_DISTANCE

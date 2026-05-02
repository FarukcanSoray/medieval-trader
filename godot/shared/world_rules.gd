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
const MEAN_REVERT_RATE: float = 0.10
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

static func edge_cost(e: EdgeState) -> int:
	return e.distance * TRAVEL_COST_PER_DISTANCE

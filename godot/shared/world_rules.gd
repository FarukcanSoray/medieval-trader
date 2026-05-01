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

static func edge_cost(e: EdgeState) -> int:
	return e.distance * TRAVEL_COST_PER_DISTANCE

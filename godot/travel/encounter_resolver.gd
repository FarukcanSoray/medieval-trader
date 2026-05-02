## Per-leg encounter roll. Pure function over the world+leg+wallet+inventory snapshot;
## no state, no side effects. Lives at the same layer as WorldRules (script-only,
## static methods, no extends).
##
## Determinism contract: same (world_seed, tick, lo_id, hi_id) -> same RNG draws,
## byte-identical. Direction-symmetric via lex-min canonicalisation of edge id.
## Goods-loss target is DERIVED from inventory + origin prices, not rolled — so
## adding it does not change the existing two RNG draws (probability + loss_fraction).
class_name EncounterResolver
extends Object

# Returns null on (a) edge.is_bandit_road == false OR (b) the roll did not fire.
# Returns a populated EncounterOutcome only when the encounter actually bites.
# `trader_inventory` and `from_node_prices` are pure value snapshots (per spec §5.7);
# the resolver reads them but does not retain references.
static func try_resolve(
	world_seed: int,
	tick: int,
	edge: EdgeState,
	trader_gold: int,
	trader_inventory: Dictionary[String, int],
	from_node_prices: Dictionary[String, int],
) -> EncounterOutcome:
	if not edge.is_bandit_road:
		return null
	# Canonical edge identity: lex-min first so (a->b) and (b->a) hash equal
	# (spec §5.3 -- the edge is undirected, fate is a property of the road and the moment).
	var lo: String = edge.a_id if edge.a_id < edge.b_id else edge.b_id
	var hi: String = edge.b_id if edge.a_id < edge.b_id else edge.a_id
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([world_seed, tick, lo, hi, "encounter_roll"])
	if rng.randf() >= WorldRules.BANDIT_ROAD_PROBABILITY:
		return null
	var loss_fraction: float = rng.randf_range(
		WorldRules.BANDIT_GOLD_LOSS_MIN_FRACTION,
		WorldRules.BANDIT_GOLD_LOSS_MAX_FRACTION,
	)
	var gold_loss: int = mini(WorldRules.BANDIT_GOLD_LOSS_HARD_CAP, roundi(loss_fraction * float(trader_gold)))
	var outcome: EncounterOutcome = EncounterOutcome.new()
	outcome.kind = "bandits"
	outcome.gold_loss = gold_loss
	# Goods loss is additive to gold loss (spec §5.7); only fires when inventory has stock.
	# Derived deterministically from inventory + origin prices — no new RNG draws.
	if not trader_inventory.is_empty():
		var target_good_id: String = ""
		var target_value: int = -1
		for good_id: String in trader_inventory.keys():
			var qty: int = int(trader_inventory[good_id])
			if qty <= 0:
				continue
			var price: int = int(from_node_prices.get(good_id, 0))
			# Most-valuable-by-origin-price; lex-min good_id breaks ties.
			# Sentinel target_value = -1 ensures any real price (incl. 0) wins first.
			if price > target_value or (price == target_value and good_id < target_good_id):
				target_good_id = good_id
				target_value = price
		if target_good_id != "":
			var stack_qty: int = int(trader_inventory[target_good_id])
			# floor() rounds toward zero for positive floats; maxi(1, ...) enforces
			# the spec's "stack of 1 loses 1" rule.
			var qty_to_lose: int = maxi(1, int(floor(WorldRules.BANDIT_GOODS_LOSS_FRACTION * float(stack_qty))))
			outcome.goods_loss_id = target_good_id
			outcome.goods_loss_qty = qty_to_lose
	return outcome

# Cost-preview helper: the upper bound the player could lose this leg, computed
# from current gold. Mirrors the clamp in try_resolve so the displayed max is the
# actual ceiling, not a theoretical one.
static func preview_loss_max(trader_gold: int) -> int:
	return mini(
		WorldRules.BANDIT_GOLD_LOSS_HARD_CAP,
		roundi(WorldRules.BANDIT_GOLD_LOSS_MAX_FRACTION * float(trader_gold)),
	)

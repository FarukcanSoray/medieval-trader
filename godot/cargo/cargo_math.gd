## Static helper for cargo-load arithmetic. Pure function over (inventory, goods);
## no state, no side effects. Lives at the same layer as WorldRules / EncounterResolver
## (script-only, static methods, no extends Resource).
##
## Single source of truth for current-load: NodePanel and Trade both call this so
## the UI predicate cannot drift from the runtime predicate. See
## docs/slice-6-weight-cargo-spec.md §4.3 (derive vs memo) and §10 (edge cases).
class_name CargoMath
extends Object

## Sums qty * weight for every inventory entry whose good is in the catalogue.
## Skips qty <= 0 entries (defensive against stale negatives) and orphan ids
## whose good is missing from the catalogue (slice-6 spec §10: orphan stacks
## contribute zero weight and remain in inventory until sold).
static func compute_load(inventory: Dictionary[String, int], goods_by_id: Dictionary[String, Good]) -> int:
	var total: int = 0
	for good_id: String in inventory.keys():
		var qty: int = int(inventory[good_id])
		if qty <= 0:
			continue
		var good: Good = goods_by_id.get(good_id)
		if good == null:
			continue
		total += qty * good.weight
	return total

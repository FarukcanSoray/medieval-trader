## Travel confirm modal per slice-spec §7. Re-emits the inherited AcceptDialog.confirmed
## signal — caller in Tier 7 wires it. OK button is disabled at prompt-time when the
## trader cannot afford the cost (predicate evaluated here, not on click).
class_name ConfirmDialog
extends AcceptDialog

func prompt(from_name: String, to_name: String, cost: int, ticks: int,
		encounter_label: String = "", encounter_loss_max: int = 0,
		encounter_probability_pct: int = 0) -> void:
	# Slice invariant: ConfirmDialog is modal and ticks only advance during travel,
	# so gold is stable while this dialog is open — predicate captured at prompt-time
	# is sufficient. If the dialog is ever made non-modal, subscribe to gold_changed.
	# Format is debug-style (raw probability + loss cap exposed). See
	# [[2026-05-02-slice-4-cost-preview-with-expected-loss-hint]] amendment:
	# polish-pass owes a player-friendly version that hides the percentages.
	var base_line: String = "Travel %s -> %s. Cost: %dg. Time: %d ticks." % [
		from_name, to_name, cost, ticks,
	]
	if encounter_label == "":
		dialog_text = base_line
	else:
		dialog_text = "%s\n%s: %d%% chance to lose up to %dg." % [
			base_line, encounter_label.capitalize(), encounter_probability_pct, encounter_loss_max,
		]
	var ok_button: Button = get_ok_button()
	if ok_button != null:
		var trader: TraderState = Game.trader
		var can_afford: bool = trader != null and trader.gold >= cost
		ok_button.disabled = not can_afford
	popup_centered()

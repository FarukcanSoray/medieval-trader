## Modal confirmation for the Begin Anew path. Empty class body — configuration
## (title, body text, OK label) is set in begin_anew_confirm_dialog.tscn; the
## cancel button is added at runtime because AcceptDialog doesn't expose it as
## a .tscn property. _ready() runs before any popup_centered() call from the
## parent, so the cancel button exists by the time the dialog first shows.
class_name BeginAnewConfirmDialog
extends AcceptDialog

func _ready() -> void:
	add_cancel_button("Cancel")

extends CanvasLayer

# DebugOverlay: Toggleable debug UI panel (F12 or tilde key).
# Provides developer tools for testing without cluttering production UI.

@onready var word_input: LineEdit = $DebugPanel/VBox/WordInput
@onready var check_button: Button = $DebugPanel/VBox/CheckButton
@onready var remove_all_button: Button = $DebugPanel/VBox/RemoveAllButton
@onready var redraw_button: Button = $DebugPanel/VBox/RedrawButton
@onready var print_rack_button: Button = $DebugPanel/VBox/PrintRackButton

func _ready():
	# Wire button signals
	check_button.connect("pressed", Callable(self, "_on_check_word_pressed"))
	remove_all_button.connect("pressed", Callable(self, "_on_remove_all_pressed"))
	redraw_button.connect("pressed", Callable(self, "_on_redraw_pressed"))
	print_rack_button.connect("pressed", Callable(self, "_on_print_rack_pressed"))
	
	print("[debug_overlay] Debug overlay ready")

func _on_check_word_pressed():
	var word = word_input.text.strip_edges()
	if word.is_empty():
		print("[debug_overlay] No word entered")
		return
	
	# Find word_test to use its validate_word method
	var word_test = get_tree().get_current_scene()
	if word_test and word_test.has_method("validate_word"):
		var valid = word_test.validate_word(word)
		print("[debug_overlay] Word '", word, "' is ", "VALID" if valid else "INVALID")
	else:
		print("[debug_overlay] Cannot validate - word_test not found")

func _on_remove_all_pressed():
	# Find word_test and call its remove all handler
	var word_test = get_tree().get_current_scene()
	if word_test and word_test.has_method("_on_remove_all_pressed"):
		word_test._on_remove_all_pressed()
	else:
		print("[debug_overlay] Cannot remove all - word_test not found")

func _on_redraw_pressed():
	# Find word_test and call its redraw handler
	var word_test = get_tree().get_current_scene()
	if word_test and word_test.has_method("_on_redraw_hand_pressed"):
		word_test._on_redraw_hand_pressed()
	else:
		print("[debug_overlay] Cannot redraw - word_test not found")

func _on_print_rack_pressed():
	# Find word_test and call its print rack handler
	var word_test = get_tree().get_current_scene()
	if word_test and word_test.has_method("_on_print_rack_pressed"):
		word_test._on_print_rack_pressed()
	else:
		print("[debug_overlay] Cannot print rack - word_test not found")

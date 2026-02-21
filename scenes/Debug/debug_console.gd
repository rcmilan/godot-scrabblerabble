## DebugConsole: Interactive debug command interface.
##
## Displays command output and accepts user input for DebugManager commands.
## Toggled via F1 key. Owns DebugManager instance for command execution.
##
## Commands available: help, spawn, draw, clear_board, close/exit
## (See DebugManager for command documentation)

extends CanvasLayer

@onready var output_log: RichTextLabel = $Panel/VBoxContainer/OutputLog
@onready var input_line: LineEdit = $Panel/VBoxContainer/InputLine

var _debug_mgr: DebugManager = null


func _ready() -> void:
	# Default hidden state
	visible = false

	# Connect input submission
	input_line.text_submitted.connect(_on_command_submitted)

	# Create and setup DebugManager
	_debug_mgr = DebugManager.new()
	_debug_mgr.setup(get_parent(), print_line)

	print_line("Debug Console ready (press F1 to toggle)")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		# Only show console if currently hidden
		if not visible:
			show_console()
			get_viewport().set_input_as_handled()


func show_console() -> void:
	visible = true
	input_line.grab_focus()

func hide_console() -> void:
	visible = false
	input_line.release_focus()


func _on_command_submitted(command: String) -> void:
	if command.is_empty():
		return

	print_line("> %s" % command)
	_debug_mgr.execute_command(command)
	input_line.clear()


func print_line(text: String) -> void:
	output_log.append_text(text + "\n")
	#auto-scroll the console log to bottom
	await get_tree().process_frame
	output_log.scroll_to_line(output_log.get_line_count())

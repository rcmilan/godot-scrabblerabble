extends CanvasLayer


@onready var output_log: RichTextLabel = $Panel/VBoxContainer/OutputLog
@onready var input_line: LineEdit = $Panel/VBoxContainer/InputLine

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("[DebugConsole] _ready() called - node is in tree")
	print("[DebugConsole] Node path: ", get_path())
	print("[DebugConsole] Parent: ", get_parent().name if get_parent() else "NO PARENT")
	
	#default is hidden
	visible = false
	
	#input connections
	input_line.text_submitted.connect(_on_command_submitted)
	
	#output callback from debugmanager
	DebugManager.console_print = print_line
	
	print_line("Debug Console ready (press D to toggle)")
	print("[DebugConsole] _ready() complete")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
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
	DebugManager.execute_command(command)
	input_line.clear()
	

func print_line(text: String) -> void:
	output_log.append_text(text + "\n")
	#auto-scroll the console log to bottom
	await get_tree().process_frame
	output_log.scroll_to_line(output_log.get_line_count())

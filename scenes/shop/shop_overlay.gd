extends Control
class_name ShopOverlay

## Win95 browser shop window.
## Shows a 3x3 grid of 9 placeholder shop items.
## Keyboard navigation: TAB forward, Shift+TAB reverse, ENTER activate, ESC close.

signal continue_requested

@onready var CloseButton: Button = $BrowserWindow/VBox/TitleBar/HBox/CloseButton
@onready var RefreshButton: Button = $BrowserWindow/VBox/Toolbar/HBox/RefreshButton
@onready var UrlBar: LineEdit = $BrowserWindow/VBox/Toolbar/HBox/UrlBar
@onready var ItemGrid: GridContainer = $BrowserWindow/VBox/ContentArea/Margin/ItemGrid

var _shop_item_cells: Array[Button] = []

const ITEM_TYPES = [
	ShopItem.Type.EXE, ShopItem.Type.DLL, ShopItem.Type.EXE,
	ShopItem.Type.DLL, ShopItem.Type.BAT, ShopItem.Type.EXE,
	ShopItem.Type.BAT, ShopItem.Type.DLL, ShopItem.Type.BAT,
]

const ICON_MAP = {
	ShopItem.Type.EXE: preload("res://scenes/shop/icons/exe_icon.png"),
	ShopItem.Type.DLL: preload("res://scenes/shop/icons/dll_icon.png"),
	ShopItem.Type.BAT: preload("res://scenes/shop/icons/bat_icon.png"),
}

func _ready() -> void:
	# Gather all ShopItemCell nodes (cells 0-8)
	for i in range(9):
		var cell: Button = ItemGrid.get_child(i) as Button
		if cell:
			_shop_item_cells.append(cell)

	# Wire focus chain: RefreshButton -> Cell0..8 -> CloseButton -> (wrap to Refresh)
	if _shop_item_cells.size() == 9:
		RefreshButton.focus_next = NodePath("../../../ContentArea/Margin/ItemGrid/ShopItemCell0")
		for i in range(9):
			if i < 8:
				_shop_item_cells[i].focus_next = NodePath("../ShopItemCell%d" % (i + 1))
			else:
				_shop_item_cells[i].focus_next = NodePath("../../../../TitleBar/HBox/CloseButton")

		CloseButton.focus_next = NodePath("../../../Toolbar/HBox/RefreshButton")

		# Wire reverse focus (Shift+TAB): mirror the forward chain
		CloseButton.focus_previous = NodePath("../../../ContentArea/Margin/ItemGrid/ShopItemCell8")
		for i in range(8, -1, -1):
			if i > 0:
				_shop_item_cells[i].focus_previous = NodePath("../ShopItemCell%d" % (i - 1))
			else:
				_shop_item_cells[i].focus_previous = NodePath("../../../../Toolbar/HBox/RefreshButton")

		RefreshButton.focus_previous = NodePath("../../../TitleBar/HBox/CloseButton")

		# Connect cell pressed signals to no-op handler
		for i in range(9):
			_shop_item_cells[i].pressed.connect(_on_cell_pressed.bindv([i]))

	CloseButton.pressed.connect(_close_shop)
	RefreshButton.pressed.connect(_on_refresh_pressed)
	hide()

func show_shop(round_number: int) -> void:
	# Assign icons to cells from ITEM_TYPES
	for i in range(min(ITEM_TYPES.size(), _shop_item_cells.size())):
		var item_type: ShopItem.Type = ITEM_TYPES[i]
		var cell: Button = _shop_item_cells[i]
		var icon_texture_rect: TextureRect = cell.get_node("Icon") as TextureRect
		if icon_texture_rect and item_type in ICON_MAP:
			icon_texture_rect.texture = ICON_MAP[item_type]

	show()
	RefreshButton.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_shop()
		get_viewport().set_input_as_handled()

func _close_shop() -> void:
	hide()
	continue_requested.emit()

func _on_cell_pressed(index: int) -> void:
	pass

func _on_refresh_pressed() -> void:
	pass

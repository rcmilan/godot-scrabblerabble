extends Control
class_name ShopOverlay

## Win95 browser shop window.
## Shows a 3x3 grid of 9 placeholder shop items.
## Keyboard navigation: TAB forward, Shift+TAB reverse, ENTER activate, ESC close.

signal continue_requested

@onready var CloseButton: Button = $BrowserWindow/VBox/TitleBar/HBox/CloseButton
@onready var RefreshButton: Button = $BrowserWindow/VBox/Toolbar/HBox/RefreshButton
@onready var UrlBar: LineEdit = $BrowserWindow/VBox/Toolbar/HBox/UrlBar
@onready var ItemGrid: GridContainer = $BrowserWindow/VBox/ContentArea/ItemGrid

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
	hide()

func show_shop(round_number: int) -> void:
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

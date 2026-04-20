class_name ShopSlideAnimation

# Animation strategy for shop entrance/exit transitions
# Defines shop slide-in from bottom and slide-out to top behavior
# Board counterpart animations (slide out/in from top)

const ANIMATION_DURATION: float = 0.5  # 500ms

static func get_entrance_animation(shop: Control, board: Control, context: Node) -> Tween:
	# Shop slides in from bottom (y: screen_height → 0)
	# Board slides up off-screen (y: 0 → -screen_height)
	# Both start and end simultaneously (500ms)

	var screen_height: float = shop.get_viewport_rect().size.y

	shop.position.y = screen_height
	board.position.y = 0

	var tween = context.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(shop, "position:y", 0, ANIMATION_DURATION)
	tween.tween_property(board, "position:y", -screen_height, ANIMATION_DURATION)

	return tween


static func get_exit_animation(shop: Control, board: Control, context: Node) -> Tween:
	# Shop slides out top (y: 0 → -screen_height)
	# Board slides down back in (y: -screen_height → 0)
	# Both start and end simultaneously (500ms)

	var screen_height: float = shop.get_viewport_rect().size.y

	var tween = context.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(shop, "position:y", -screen_height, ANIMATION_DURATION)
	tween.tween_property(board, "position:y", 0, ANIMATION_DURATION)

	return tween

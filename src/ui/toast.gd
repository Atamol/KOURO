class_name Toast
## A line that says something happened and then gets out of the way. For the
## things a player would otherwise only find out by going somewhere and looking


## how long it stays put before it starts fading, and how long the fade takes
const LIFE := 3.4
const FADE := 0.6


static func show_on(host: Control, text: String, at_y := 132.0) -> void:
	var box := PanelContainer.new()
	# never in the way of a click: it is telling, not asking
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 30)
	pad.add_theme_constant_override("margin_right", 30)
	pad.add_theme_constant_override("margin_top", 14)
	pad.add_theme_constant_override("margin_bottom", 14)
	box.add_child(pad)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.68))
	pad.add_child(label)
	host.add_child(box)
	# its own width is only known once it has been laid out
	await host.get_tree().process_frame
	if not is_instance_valid(box):
		return
	box.position = Vector2((host.size.x - box.size.x) * 0.5, at_y)
	var tw := box.create_tween()
	tw.tween_interval(LIFE)
	tw.tween_property(box, "modulate:a", 0.0, FADE)
	tw.tween_callback(box.queue_free)

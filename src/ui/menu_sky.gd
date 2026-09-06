class_name MenuSky
extends Control
## A window onto SkyState. The state lives in an autoload so it keeps running
## between screens; this only shows it


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	SkyState.paint(self)

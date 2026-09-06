extends SceneTree
## Dev tool: writes icon.svg out as PNG at the usual sizes, rounded and square.
## Files land in icon/, which carries a .gdignore so Godot does not import them


const SIZES := [1024, 512, 256, 128, 64, 48, 32, 16]
const OUT := "res://icon/"


func _init() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	if svg.is_empty():
		push_error("icon.svg not found")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var keep := FileAccess.open(OUT + ".gdignore", FileAccess.WRITE)
	if keep != null:
		keep.close()
	# the square set comes from the same source with the corner radius taken out,
	# so editing icon.svg still moves both
	var square := RegEx.create_from_string(' rx="[0-9.]+"').sub(svg, "", true)
	for shape: Array in [["icon", svg], ["square", square]]:
		for size: int in SIZES:
			var img := Image.new()
			# the source is 128 square, so the scale is however many times that
			if img.load_svg_from_buffer((shape[1] as String).to_utf8_buffer(), float(size) / 128.0) != OK:
				push_error("could not rasterize %s at %d" % [shape[0], size])
				continue
			var path := "%s%s_%d.png" % [OUT, shape[0], size]
			img.save_png(path)
			print("%s  %dx%d" % [path, img.get_width(), img.get_height()])
	quit()

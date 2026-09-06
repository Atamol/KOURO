class_name ShotFix
## Dev tool helper: Forward+ hands back the linear buffer of an HDR viewport, so
## a straight save comes out far darker than the screen. Compatibility does not


static func save(img: Image, path: String) -> void:
	if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false) \
			and RenderingServer.get_current_rendering_method() != "gl_compatibility":
		for y in img.get_height():
			for x in img.get_width():
				img.set_pixel(x, y, img.get_pixel(x, y).linear_to_srgb())
	img.save_png(path)

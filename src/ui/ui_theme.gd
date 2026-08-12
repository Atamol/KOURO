class_name UiTheme
## System font fallback so Japanese text renders on any Windows box


## The wordmark is five wide letters, so it wants the spacing opened up.
## SystemFont has no spacing of its own, a variation wraps it to add some
static func title_font() -> Font:
	var base := SystemFont.new()
	base.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "Noto Sans JP", "sans-serif"])
	var f := FontVariation.new()
	f.base_font = base
	f.spacing_glyph = 10
	return f


static func make() -> Theme:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "Noto Sans JP", "sans-serif"])
	var t := Theme.new()
	t.default_font = f
	t.default_font_size = 17
	return t

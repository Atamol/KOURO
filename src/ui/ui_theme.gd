class_name UiTheme
## The fonts are carried in the project rather than looked up by name. A Web
## build has no OS font list for SystemFont to search, so every name misses and
## the text comes out as tofu.
##
## Inter is asked first and M PLUS 1p catches what it has no glyph for,
## which in practice means Latin from one and Japanese from the other


const LATIN := "res://assets/fonts/Inter.ttf"
const JAPANESE := "res://assets/fonts/MPLUS1p-Regular.ttf"


## Loaded, not read off disk: an export ships what the importer made of the ttf
## and drops the ttf itself, so reading the file by name works everywhere except
## in the build that ends up being shipped
static func body_font() -> Font:
	var f: FontFile = load(LATIN)
	f.fallbacks = [load(JAPANESE)]
	return f


## The wordmark is five wide letters, so it wants the spacing opened up
static func title_font() -> Font:
	var f := FontVariation.new()
	f.base_font = body_font()
	f.spacing_glyph = 10
	return f


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 17
	return t

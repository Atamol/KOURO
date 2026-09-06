class_name Glow
## Only what is drawn brighter than white blooms, which is why the viewport is
## HDR: the beams go past 1.0 and everything else on screen, text included,
## stays under the threshold and is left alone


## How far past the 1.0 threshold a beam is drawn, which is all the bloom has to
## work with
const BEAM_GAIN := 2.8


static func env() -> WorldEnvironment:
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	e.glow_enabled = true
	e.glow_intensity = 1.15
	e.glow_bloom = 0.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.glow_hdr_threshold = 1.0
	e.glow_hdr_scale = 1.0
	# level 0 is too tight a halo to read as one, and the top levels wash the board
	for level in [0, 1, 2, 3, 4, 5, 6]:
		e.set_glow_level(level, [0.0, 1.0, 0.8, 0.35, 0.0, 0.0, 0.0][level])
	var node := WorldEnvironment.new()
	node.environment = e
	return node


## A beam colour taken past white, so the bloom pass picks it up
static func hot(col: Color, amount := 1.0) -> Color:
	var lit := col * (1.0 + (BEAM_GAIN - 1.0) * amount)
	lit.a = col.a
	return lit

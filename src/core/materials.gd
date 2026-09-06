class_name OpticsMaterials
## Refractive indices at 589.3 nm. A material with "ne" is birefringent, one
## with "rotation" is optically active, quoted in degrees per mm the way a
## polarimeter reads it


const AIR := 1.000293

## Board scale, which only optical rotation depends on. A body the beam crosses
## comes out 20 to 40 cm of liquid, the length a polarimeter tube comes in
const PX_MM := 1.5

const TRANSPARENT := {
	# density dependent in reality, this is a dense sample
	"aerogel": {"label": "シリカエアロゲル", "label_en": "Silica aerogel", "n": 1.0250, "color": Color(0.85, 0.92, 0.98)},
	"water": {"label": "蒸留水", "label_en": "Distilled water", "n": 1.3330, "color": Color(0.35, 0.62, 0.95)},
	"ethanol": {"label": "エタノール", "label_en": "Ethanol", "n": 1.3614, "color": Color(0.55, 0.85, 0.80)},
	# 50% by weight, 0.615 g/mL against a specific rotation of -92
	"fructose": {"label": "果糖水溶液", "label_en": "Fructose solution", "n": 1.4200, "rotation": -0.566, "color": Color(0.95, 0.72, 0.85)},
	"fluorite": {"label": "蛍石", "label_en": "Fluorite", "n": 1.4338, "color": Color(0.72, 0.62, 0.88)},
	# 60% by weight, 0.774 g/mL against a specific rotation of +66.5
	"sucrose": {"label": "ショ糖水溶液", "label_en": "Sucrose solution", "n": 1.4418, "rotation": 0.515, "color": Color(0.98, 0.82, 0.68)},
	"silica": {"label": "石英ガラス", "label_en": "Fused silica", "n": 1.4585, "color": Color(0.80, 0.75, 0.95)},
	# neat (R)-(+)-limonene
	"limonene": {"label": "リモネン", "label_en": "Limonene", "n": 1.4713, "rotation": 0.971, "color": Color(0.72, 0.95, 0.55)},
	"turpentine": {"label": "テレビン油", "label_en": "Turpentine", "n": 1.4780, "rotation": -0.370, "color": Color(0.88, 0.88, 0.70)},
	"acrylic": {"label": "アクリル", "label_en": "Acrylic", "n": 1.4914, "color": Color(0.90, 0.65, 0.75)},
	"bk7": {"label": "BK7ガラス", "label_en": "BK7 glass", "n": 1.5168, "color": Color(0.60, 0.80, 0.60)},
	"soda_glass": {"label": "ソーダ石灰ガラス", "label_en": "Soda-lime glass", "n": 1.5230, "color": Color(0.55, 0.75, 0.55)},
	"quartz": {"label": "水晶", "label_en": "Quartz", "n": 1.5443, "ne": 1.5534, "color": Color(0.72, 0.86, 0.92)},
	"polycarb": {"label": "ポリカーボネート", "label_en": "Polycarbonate", "n": 1.5855, "color": Color(0.85, 0.80, 0.55)},
	"carbon_disulfide": {"label": "二硫化炭素", "label_en": "Carbon disulfide", "n": 1.6280, "color": Color(0.92, 0.90, 0.62)},
	"calcite": {"label": "方解石", "label_en": "Calcite", "n": 1.6584, "ne": 1.4864, "color": Color(0.98, 0.86, 0.55)},
	"sapphire": {"label": "サファイア", "label_en": "Sapphire", "n": 1.7683, "ne": 1.7601, "color": Color(0.45, 0.55, 0.95)},
	"sf11": {"label": "SF11ガラス", "label_en": "SF11 glass", "n": 1.7847, "color": Color(0.75, 0.55, 0.85)},
	"zirconia": {"label": "立方晶ジルコニア", "label_en": "Cubic zirconia", "n": 2.1600, "color": Color(0.78, 0.95, 0.98)},
	"diamond": {"label": "ダイヤモンド", "label_en": "Diamond", "n": 2.4175, "color": Color(0.85, 0.92, 1.0)},
	"rutile": {"label": "ルチル", "label_en": "Rutile", "n": 2.6142, "ne": 2.9029, "color": Color(0.95, 0.80, 0.45)},
	# opaque below about 550 nm, hence the orange
	"gallium_phosphide": {"label": "リン化ガリウム", "label_en": "Gallium phosphide", "n": 3.3100, "color": Color(0.95, 0.62, 0.30)},
}

## Append only: a stage code stores an index into this list, so reordering it
## would make every code already shared decode to different materials
const ORDER := [
	"water", "ethanol", "silica", "acrylic", "bk7", "soda_glass", "polycarb", "sf11", "diamond",
	"aerogel", "fluorite", "carbon_disulfide", "zirconia", "gallium_phosphide",
	"quartz", "calcite", "sapphire", "rutile",
	"fructose", "sucrose", "limonene", "turpentine",
]

## ascending n, for stepping to a neighbouring material
const BY_INDEX := [
	"aerogel", "water", "ethanol", "fructose", "fluorite", "sucrose", "silica", "limonene",
	"turpentine", "acrylic", "bk7", "soda_glass", "quartz", "polycarb", "carbon_disulfide",
	"calcite", "sapphire", "sf11", "zirconia", "diamond", "rutile", "gallium_phosphide",
]


static func is_crystal(key: String) -> bool:
	return TRANSPARENT.has(key) and TRANSPARENT[key].has("ne")


static func is_rotary(key: String) -> bool:
	return TRANSPARENT.has(key) and TRANSPARENT[key].has("rotation")


## radians per pixel, positive for a right handed medium
static func rotary(key: String) -> float:
	if not is_rotary(key):
		return 0.0
	return deg_to_rad(TRANSPARENT[key].rotation) * PX_MM

## REFLECTIVE keys in a fixed order, likewise append only
const REFLECTIVE_ORDER := ["mirror", "silver", "aluminum"]

const REFLECTIVE := {
	"mirror": {"label": "理想鏡", "label_en": "Ideal mirror", "reflectance": 1.0, "color": Color(0.85, 0.90, 0.95)},
	"silver": {"label": "銀", "label_en": "Silver", "reflectance": 0.96, "color": Color(0.80, 0.82, 0.86)},
	"aluminum": {"label": "アルミニウム", "label_en": "Aluminium", "reflectance": 0.92, "color": Color(0.68, 0.70, 0.74)},
}


## The one name a screen should print. Reading `label` gets the Japanese in
## both languages
static func label_of(key: String) -> String:
	var info: Dictionary = TRANSPARENT.get(key, REFLECTIVE.get(key, {}))
	if info.is_empty():
		return key
	return str(info.get("label_en", info.label)) if Lang.en() else str(info.label)

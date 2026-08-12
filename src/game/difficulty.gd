class_name Difficulty
## Three ladders laid end to end in LEVELS, each a teaching run followed by
## three that mix what came before and add nothing.
##
## kinds / materials / metals are cumulative, so a level always offers what the
## levels before it offered. What makes a teaching level about its own element
## is require_kinds and its neighbours, which force that element onto the answer
## path, and require_mistakes, which demands that getting it wrong land
## somewhere else


## kept in step with StageCode.MAX_CHOICES, which a test checks. Referring to it
## from a static var here would keep the two scripts alive past shutdown
const MAX_CHOICES := 8

const ALL_KINDS := ["mirror", "slab", "circle", "prism"]
const SHEET_KINDS := ["mirror", "slab", "circle", "prism", "polarizer"]
const FULL_KINDS := ["mirror", "slab", "circle", "prism", "polarizer", "gradient"]
const ALL_METALS := ["mirror", "silver", "aluminum"]
const GLASSES := ["water", "fluorite", "silica", "bk7", "soda_glass"]
const MANY := ["aerogel", "water", "ethanol", "fluorite", "silica", "acrylic", "bk7", "soda_glass", "polycarb", "carbon_disulfide"]
const DENSE := ["aerogel", "water", "ethanol", "fluorite", "silica", "acrylic", "bk7", "soda_glass", "polycarb", "carbon_disulfide", "sf11", "zirconia", "diamond", "gallium_phosphide"]
## DENSE plus the birefringent four
const CRYSTAL := ["aerogel", "water", "ethanol", "fluorite", "silica", "acrylic", "bk7", "soda_glass", "quartz", "polycarb", "carbon_disulfide", "calcite", "sapphire", "sf11", "zirconia", "diamond", "rutile", "gallium_phosphide"]
## and the optically active four on top of that
const EVERY := ["aerogel", "water", "ethanol", "fructose", "fluorite", "sucrose", "silica", "limonene", "turpentine", "acrylic", "bk7", "soda_glass", "quartz", "polycarb", "carbon_disulfide", "calcite", "sapphire", "sf11", "zirconia", "diamond", "rutile", "gallium_phosphide"]

## The twelve that teach. The three after them mix everything together
const TEACHING := [
	{
		"title": "反射の法則", "gimmick": "鏡は法線を挟んで，入ってきた角度をそのまま返す",
		"objects_min": 1, "objects_max": 1,
		"kinds": ["mirror"], "materials": ["soda_glass"], "metals": ["mirror"],
		"require_kinds": [], "fresnel": false, "choices": 3,
		"min_sep": 200.0, "min_events": 1, "min_objects": 1, "min_tir": 0,
		"min_deviation": 200.0, "decoy_clear": 150.0,
		"min_slips": 2, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
	{
		"title": "反射の連鎖", "gimmick": "跳ね返った先にまた鏡があり，折り返しが続く",
		"objects_min": 2, "objects_max": 3,
		"kinds": ["mirror"], "materials": ["soda_glass"], "metals": ["mirror"],
		"require_kinds": [], "fresnel": false, "choices": 3,
		"min_sep": 190.0, "min_events": 2, "min_objects": 2, "min_tir": 0,
		"min_deviation": 200.0, "decoy_clear": 150.0,
		"min_slips": 2, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
	{
		"title": "横ずれ", "gimmick": "厚いガラスを斜めに抜けると，向きは戻って位置だけずれる",
		"objects_min": 2, "objects_max": 3,
		"kinds": ["mirror", "slab"], "materials": ["soda_glass"], "metals": ["mirror"],
		"require_kinds": ["slab"], "fresnel": false, "choices": 3,
		"min_sep": 180.0, "min_events": 2, "min_objects": 1, "min_tir": 0,
		"min_deviation": 60.0, "decoy_clear": 60.0,
		"min_slips": 2, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
	{
		"title": "反射と屈折", "gimmick": "曲げる面と跳ね返す面が同じ経路に並ぶ",
		"objects_min": 2, "objects_max": 3,
		"kinds": ["mirror", "slab"], "materials": ["soda_glass"], "metals": ["mirror"],
		"require_kinds": ["slab", "mirror"], "fresnel": false, "choices": 4,
		"min_sep": 160.0, "min_events": 3, "min_objects": 2, "min_tir": 0,
		"min_deviation": 120.0, "decoy_clear": 110.0,
		"min_slips": 3, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
	{
		"title": "曲面の法線", "gimmick": "円は当たる場所ごとに法線の向きが変わる",
		"objects_min": 3, "objects_max": 4,
		"kinds": ["mirror", "slab", "circle"], "materials": ["water", "soda_glass"], "metals": ["mirror"],
		"require_kinds": ["circle"], "fresnel": false, "choices": 4,
		"min_sep": 150.0, "min_events": 3, "min_objects": 2, "min_tir": 0,
		"min_deviation": 120.0, "decoy_clear": 110.0,
		"min_slips": 3, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
	{
		"title": "偏角", "gimmick": "入口と出口の面が平行でないぶん，抜けた向きが元に戻らない",
		"objects_min": 3, "objects_max": 4,
		"kinds": ALL_KINDS, "materials": GLASSES, "metals": ["mirror", "silver"],
		"require_kinds": ["prism"], "fresnel": false, "choices": 4,
		"min_sep": 140.0, "min_events": 3, "min_objects": 2, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 100.0,
		"min_slips": 3, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
	{
		"title": "屈折率の差", "gimmick": "同じ角度で入っても，物質が違えば曲がる量が違う",
		"objects_min": 4, "objects_max": 5,
		"kinds": ALL_KINDS, "materials": MANY, "metals": ["mirror", "silver"],
		"require_kinds": [], "fresnel": false, "choices": 5,
		"min_sep": 120.0, "min_events": 4, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 90.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
	{
		"title": "臨界角", "gimmick": "内側から浅く当たった光は，外へ出られずに跳ね返る",
		"objects_min": 3, "objects_max": 5,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": ["prism"], "fresnel": false, "choices": 5,
		"min_sep": 110.0, "min_events": 4, "min_objects": 2, "min_tir": 1,
		"min_deviation": 150.0, "decoy_clear": 80.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
	{
		"title": "光の閉じ込め", "gimmick": "全反射が続くあいだ，光は物体の中を渡っていく",
		"objects_min": 4, "objects_max": 5,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": ["prism"], "fresnel": false, "choices": 5,
		"min_sep": 105.0, "min_events": 5, "min_objects": 2, "min_tir": 2,
		"min_deviation": 150.0, "decoy_clear": 76.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
	{
		"title": "部分反射", "gimmick": "どの面でも一部が跳ね返り，光が枝分かれする",
		"objects_min": 4, "objects_max": 5,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "fresnel": true, "choices": 5,
		"min_sep": 100.0, "min_events": 4, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 68.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
	{
		"title": "明るさの逆転", "gimmick": "抜けた側より，跳ね返った側が明るくなることがある",
		"objects_min": 4, "objects_max": 5,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "fresnel": true, "choices": 5, "min_split": 1,
		"min_sep": 98.0, "min_events": 4, "min_objects": 2, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 68.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
	{
		"title": "枝分かれと全反射", "gimmick": "分かれた片方が，その先で臨界角を超える",
		"objects_min": 4, "objects_max": 6,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "fresnel": true, "choices": 6,
		"min_sep": 95.0, "min_events": 4, "min_objects": 2, "min_tir": 1,
		"min_deviation": 150.0, "decoy_clear": 68.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
]

## Nothing new, only more of it. Meant to read as a step up from the levels that
## taught each element, not as a wall
const MAIN_MIXED := [
	{
		"title": "総合", "gimmick": "ここまでの要素が同じ盤面に並ぶ",
		"objects_min": 4, "objects_max": 5,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "fresnel": true, "choices": 6,
		"min_sep": 92.0, "min_events": 4, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 68.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
	{
		"title": "長い経路", "gimmick": "物体が増え，追う距離が延びる",
		"objects_min": 5, "objects_max": 6,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "fresnel": true, "choices": 6,
		"min_sep": 88.0, "min_events": 5, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 65.0,
		"min_slips": 5, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
	{
		"title": "総仕上げ", "gimmick": "全反射も枝分かれも入った，ノーマルの最後",
		"objects_min": 5, "objects_max": 6,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "fresnel": true, "choices": 7,
		"min_sep": 84.0, "min_events": 6, "min_objects": 4, "min_tir": 1,
		"min_deviation": 150.0, "decoy_clear": 62.0,
		"min_slips": 5, "answers": 1, "require_crystal": false, "min_clear": 12.0,
	},
]

## Polarization lives here and nowhere else in the game. The first seven hand
## out its elements in turn, the last three mix them
const HARD := [
	{
		"title": "直交偏光", "gimmick": "通す向きが決まった板を，向きを違えて2枚重ねると光が消える",
		"objects_min": 4, "objects_max": 5,
		"kinds": SHEET_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "place_kinds": ["polarizer", "polarizer"], "sheet_step": PI * 0.5,
		"require_mistakes": ["no_polarizer"], "fresnel": true, "choices": 5,
		"min_sep": 100.0, "min_events": 3, "min_objects": 2, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 80.0,
		"min_slips": 3, "answers": 1, "require_crystal": false,
	},
	{
		"title": "45度の一枚", "gimmick": "消えていた光が，間に1枚挟むだけで戻ってくる",
		"objects_min": 4, "objects_max": 5,
		"kinds": SHEET_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "place_kinds": ["polarizer", "polarizer", "polarizer"], "sheet_step": PI * 0.25,
		"min_sheets": 3, "fresnel": true, "choices": 5,
		"min_sep": 98.0, "min_events": 3, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 78.0,
		"min_slips": 3, "answers": 1, "require_crystal": false,
	},
	{
		"title": "常光線と異常光線", "gimmick": "結晶に入った光は2本に分かれ，出口も2箇所になる",
		"objects_min": 3, "objects_max": 5,
		"kinds": SHEET_KINDS, "materials": CRYSTAL, "metals": ALL_METALS,
		"require_kinds": [], "place_crystal": 1,
		"fresnel": true, "choices": 6,
		"min_sep": 90.0, "min_events": 3, "min_objects": 2, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 70.0,
		"min_slips": 3, "answers": 2, "require_crystal": true, "require_split": true,
	},
	{
		"title": "偏光板で選ぶ", "gimmick": "分かれた2本のうち，偏光板を抜けられるのは片方だけ",
		"objects_min": 3, "objects_max": 5,
		"kinds": SHEET_KINDS, "materials": CRYSTAL, "metals": ALL_METALS,
		"require_kinds": ["polarizer"], "place_kinds": ["polarizer"], "place_crystal": 1,
		"require_mistakes": ["no_polarizer"], "fresnel": true, "choices": 6,
		"min_sep": 90.0, "min_events": 3, "min_objects": 2, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 70.0,
		"min_slips": 4, "answers": 1, "require_crystal": true,
	},
	{
		"title": "偏光面の回転", "gimmick": "旋光性の液体が偏光面を回し，直交した2枚の間を通してしまう",
		"objects_min": 3, "objects_max": 4,
		"kinds": SHEET_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": [], "place_kinds": ["polarizer", "polarizer"], "sheet_step": PI * 0.5, "place_rotary": 1,
		"require_rotary": true, "require_mistakes": ["no_rotation"], "fresnel": true, "choices": 6,
		"min_sep": 90.0, "min_events": 3, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 70.0,
		"min_slips": 4, "answers": 1, "require_crystal": false,
	},
	{
		"title": "屈折率の勾配", "gimmick": "屈折率が場所で変わる媒質では，蜃気楼と同じで光路が曲がる",
		"objects_min": 3, "objects_max": 5,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": ["gradient"], "place_kinds": ["gradient"],
		"require_mistakes": ["flat_gradient", "flip_gradient"], "fresnel": true, "choices": 6,
		"min_sep": 90.0, "min_events": 3, "min_objects": 2, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 70.0,
		"min_slips": 4, "answers": 1, "require_crystal": false,
	},
	{
		"title": "曲がった先の臨界角", "gimmick": "曲がりながら面に近づき，浅くなったところで跳ね返る",
		"objects_min": 4, "objects_max": 5,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": ["gradient"], "place_kinds": ["gradient"],
		"require_mistakes": ["flat_gradient"], "fresnel": true, "choices": 6,
		"min_sep": 88.0, "min_events": 4, "min_objects": 3, "min_tir": 1,
		"min_deviation": 150.0, "decoy_clear": 68.0,
		"min_slips": 4, "answers": 1, "require_crystal": false,
	},
	{
		"title": "総合", "gimmick": "ハードの要素が同じ盤面に並ぶ",
		"objects_min": 4, "objects_max": 5,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": [], "place_kinds": ["polarizer"],
		"fresnel": true, "choices": 6,
		"min_sep": 84.0, "min_events": 4, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 66.0,
		"min_slips": 4, "answers": 1, "require_crystal": false,
	},
	{
		"title": "分かれて曲がる", "gimmick": "結晶が分けた2本が，どちらも勾配を抜ける",
		"objects_min": 5, "objects_max": 6,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": [], "place_kinds": ["gradient"], "place_crystal": 1,
		"fresnel": true, "choices": 7,
		"min_sep": 80.0, "min_events": 5, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 63.0,
		"min_slips": 4, "answers": 2, "require_crystal": true, "require_split": true,
	},
	{
		"title": "大詰め", "gimmick": "偏光板も勾配も旋光性も乗った，ハードの最後",
		"objects_min": 5, "objects_max": 6,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": [], "place_kinds": ["polarizer", "gradient"], "place_rotary": 1,
		"fresnel": true, "choices": 7,
		"min_sep": 78.0, "min_events": 6, "min_objects": 4, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 60.0,
		"min_slips": 5, "answers": 1, "require_crystal": false,
	},
]

## Five problems with nothing held back. Every element the game has can turn up
## in any of them, and the only thing that changes down the list is how much of
## the board the light has to be followed across
const EXTRA := [
	{
		"title": "総合", "gimmick": "偏光板と勾配と結晶が同じ盤面に並ぶ",
		"objects_min": 5, "objects_max": 6,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": ["gradient"], "place_kinds": ["polarizer", "gradient"], "place_crystal": 1,
		"fresnel": true, "choices": 7,
		"min_sep": 80.0, "min_events": 5, "min_objects": 4, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 60.0,
		"min_slips": 5, "answers": 1, "require_crystal": false,
	},
	{
		"title": "二本の行方", "gimmick": "分かれた2本を，勾配の先まで別々に追う",
		"objects_min": 5, "objects_max": 7,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": ["gradient"], "place_kinds": ["polarizer", "gradient"], "place_crystal": 1,
		"fresnel": true, "choices": 7,
		"min_sep": 78.0, "min_events": 5, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 60.0,
		"min_slips": 5, "answers": 2, "require_crystal": true, "require_split": true,
	},
	{
		"title": "旋光と全反射", "gimmick": "回された偏光面と，臨界角を超える面が同じ経路に乗る",
		"objects_min": 6, "objects_max": 7,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": ["polarizer"], "place_kinds": ["polarizer", "gradient"], "place_rotary": 1,
		"fresnel": true, "choices": 7,
		"min_sep": 76.0, "min_events": 6, "min_objects": 4, "min_tir": 1,
		"min_deviation": 150.0, "decoy_clear": 58.0,
		"min_slips": 5, "answers": 1, "require_crystal": false,
	},
	{
		"title": "八つの出口", "gimmick": "選択肢8つの中から2箇所を選ぶ",
		"objects_min": 6, "objects_max": 7,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": [], "place_kinds": ["polarizer", "gradient"], "place_crystal": 1,
		"fresnel": true, "choices": 8,
		"min_sep": 74.0, "min_events": 6, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 58.0,
		"min_slips": 5, "answers": 2, "require_crystal": true, "require_split": true,
	},
	{
		"title": "最終問題", "gimmick": "使える要素を全部使った1問",
		"objects_min": 6, "objects_max": 8,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": ["gradient", "polarizer"], "place_kinds": ["polarizer", "gradient"], "place_crystal": 1, "place_rotary": 1,
		"fresnel": true, "choices": 8,
		"min_sep": 72.0, "min_events": 7, "min_objects": 4, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 58.0,
		"min_slips": 5, "answers": 1, "require_crystal": false,
	},
]

## Where each ladder starts inside LEVELS
const MAIN_COUNT := 15
const HARD_COUNT := 10
const EXTRA_COUNT := 5
const HARD_START := MAIN_COUNT
const EXTRA_START := MAIN_COUNT + HARD_COUNT

## Every level, the three ladders laid end to end. A literal table rather than a
## generated one: a static var here would keep this script alive past shutdown,
## and the numbers are easier to hand tune where they are read
const LEVELS := TEACHING + MAIN_MIXED + HARD + EXTRA

const MODES := ["main", "hard", "extra"]


static func start_of(mode: String) -> int:
	if mode == "hard":
		return HARD_START
	return EXTRA_START if mode == "extra" else 0


static func count_of(mode: String) -> int:
	if mode == "hard":
		return HARD_COUNT
	return EXTRA_COUNT if mode == "extra" else MAIN_COUNT


static func mode_of(index: int) -> String:
	if index >= EXTRA_START:
		return "extra"
	return "hard" if index >= HARD_START else "main"


static func prefix_of(mode: String) -> String:
	if mode == "hard":
		return "ハード "
	return "エクストラ " if mode == "extra" else ""


static func label(index: int) -> String:
	return prefix_of(mode_of(index)) + short_label(index)


## Without the ladder's name, for a screen that already says which one it is
static func short_label(index: int) -> String:
	var mode := mode_of(index)
	return "Lv. %d %s" % [index - start_of(mode) + 1, LEVELS[index].title]

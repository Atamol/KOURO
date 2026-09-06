class_name Difficulty
## Three ladders laid end to end in LEVELS. Normal and hard each teach their
## elements and then mix them over three levels; extra is nothing but mixing.
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
		"title": "等角反射のアクシオム", "gimmick": "鏡が1枚だけ．反射の決まりをそのまま確かめろ．",
		"title_en": "Equal Angle Axiom", "gimmick_en": "One mirror and nothing else. Check the rule of reflection as it stands.",
		"objects_min": 1, "objects_max": 1,
		"kinds": ["mirror"], "materials": ["soda_glass"], "metals": ["mirror"],
		"require_kinds": [], "fresnel": false, "choices": 3,
		"min_sep": 200.0, "min_events": 1, "min_objects": 1, "min_tir": 0, "max_tir": 0,
		"min_deviation": 200.0, "decoy_clear": 150.0,
		"min_slips": 2, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "多重折返のカスケード", "gimmick": "鏡が続く．折り返した先をどこまで追えるか．",
		"title_en": "Folding Cascade", "gimmick_en": "Mirror after mirror. See how far you can follow the folds.",
		"objects_min": 2, "objects_max": 3,
		"kinds": ["mirror"], "materials": ["soda_glass"], "metals": ["mirror"],
		"require_kinds": [], "fresnel": false, "choices": 3,
		"min_sep": 190.0, "min_events": 2, "min_objects": 2, "min_tir": 0, "max_tir": 0,
		"min_deviation": 200.0, "decoy_clear": 150.0,
		"min_slips": 2, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "平行変位のパララックス", "gimmick": "厚いガラスを斜めに通す．向きと位置は同じようには扱えない．",
		"title_en": "Sidestep Parallax", "gimmick_en": "A thick slab taken at an angle. Direction and position do not come out the same way.",
		"objects_min": 2, "objects_max": 3,
		"kinds": ["mirror", "slab"], "materials": ["soda_glass"], "metals": ["mirror"],
		"require_kinds": ["slab"], "fresnel": false, "choices": 3,
		"min_sep": 180.0, "min_events": 2, "min_objects": 1, "min_tir": 0, "max_tir": 0,
		"min_deviation": 60.0, "decoy_clear": 60.0,
		"min_slips": 2, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "反射屈折のアマルガム", "gimmick": "曲げる面と跳ね返す面が，どちらも経路にある．",
		"title_en": "Bend and Bounce Amalgam", "gimmick_en": "A face that bends and a face that throws back, both on the path.",
		"objects_min": 2, "objects_max": 3,
		"kinds": ["mirror", "slab"], "materials": ["soda_glass"], "metals": ["mirror"],
		"require_kinds": ["slab", "mirror"], "fresnel": false, "choices": 4,
		"min_sep": 160.0, "min_events": 3, "min_objects": 2, "min_tir": 0, "max_tir": 0,
		"min_deviation": 120.0, "decoy_clear": 110.0,
		"min_slips": 3, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "曲面法線のタンジェント", "gimmick": "円が入る．どこに当たるかで法線の向きが違う．",
		"title_en": "Curved Surface Tangent", "gimmick_en": "A circle joins in. Where you hit it decides which way the normal points.",
		"objects_min": 3, "objects_max": 4,
		"kinds": ["mirror", "slab", "circle"], "materials": ["water", "soda_glass"], "metals": ["mirror"],
		"require_kinds": ["circle"], "fresnel": false, "choices": 4,
		"min_sep": 150.0, "min_events": 3, "min_objects": 2, "min_tir": 0, "max_tir": 0,
		"min_deviation": 120.0, "decoy_clear": 110.0,
		"min_slips": 3, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "稜角偏差のプリズム", "gimmick": "プリズムは入口と出口が平行でない．",
		"title_en": "Apex Deviation Prism", "gimmick_en": "On a prism the face light enters and the face it leaves are not parallel.",
		"objects_min": 3, "objects_max": 4,
		"kinds": ALL_KINDS, "materials": GLASSES, "metals": ["mirror", "silver"],
		"require_kinds": ["prism"], "fresnel": false, "choices": 4,
		"min_sep": 140.0, "min_events": 3, "min_objects": 2, "min_tir": 0, "max_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 100.0,
		"min_slips": 3, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "媒質序列のヒエラルキー", "gimmick": "物質が増える．屈折率の違いが頭を悩ませるだろう．",
		"title_en": "Refractive Hierarchy", "gimmick_en": "More materials. The differences between their indices are the problem now.",
		"objects_min": 4, "objects_max": 5,
		"kinds": ALL_KINDS, "materials": MANY, "metals": ["mirror", "silver"],
		"require_kinds": [], "fresnel": false, "choices": 5,
		"min_sep": 120.0, "min_events": 4, "min_objects": 3, "min_tir": 0, "max_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 90.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "臨界境界のスレッショルド", "gimmick": "内側から浅く当たった光の行方を考える．",
		"title_en": "Critical Angle Threshold", "gimmick_en": "Work out where light goes when it meets a face shallowly from the inside.",
		"objects_min": 3, "objects_max": 5,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": ["prism"], "fresnel": false, "choices": 5,
		"min_sep": 110.0, "min_events": 4, "min_objects": 2, "min_tir": 1,
		"min_deviation": 150.0, "decoy_clear": 80.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "内部反射のラビリンス", "gimmick": "物体の中を渡っていく経路を追う．",
		"title_en": "Internal Labyrinth", "gimmick_en": "Follow a path that travels around inside a body.",
		"objects_min": 4, "objects_max": 5,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": ["prism"], "fresnel": false, "choices": 5,
		"min_sep": 105.0, "min_events": 5, "min_objects": 2, "min_tir": 2,
		"min_deviation": 150.0, "decoy_clear": 76.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "再帰反射のブーメラン", "gimmick": "2枚の鏡が直角に向き合う．出ていく向きを，入ってきた向きから考える．",
		"title_en": "Retroreflex Boomerang", "gimmick_en": "Two mirrors face each other at a right angle. Read the way out off the way in.",
		"objects_min": 4, "objects_max": 5,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "place_kinds": ["mirror", "mirror"], "mirror_step": PI * 0.5,
		"min_on_path": {"mirror": 2}, "require_mistakes": ["reflect_axis"], "fresnel": false, "choices": 5,
		"min_sep": 100.0, "min_events": 4, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 68.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "二種反射のデュアリティ", "gimmick": "光を跳ね返す面は，鏡だけとは限らない．",
		"title_en": "Reflector Duality", "gimmick_en": "A mirror is not the only face that sends light back.",
		"objects_min": 4, "objects_max": 5,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "min_on_path": {"mirror": 1}, "fresnel": false, "choices": 5,
		"min_sep": 98.0, "min_events": 4, "min_objects": 2, "min_tir": 1,
		"min_deviation": 150.0, "decoy_clear": 68.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "二重稜角のタンデム", "gimmick": "プリズムを続けて通る．曲がり方は途中で終わらない．",
		"title_en": "Double Apex Tandem", "gimmick_en": "Prism after prism. The bending does not stop halfway.",
		"objects_min": 4, "objects_max": 6,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": ["prism"], "min_on_path": {"prism": 2}, "fresnel": false, "choices": 6,
		"min_sep": 95.0, "min_events": 4, "min_objects": 2, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 68.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
]

## Nothing new, only more of it. Meant to read as a step up from the levels that
## taught each element, not as a wall
const MAIN_MIXED := [
	{
		"title": "累積要素のアンサンブル", "gimmick": "これまでの要素が揃って出てくる．全軍突撃！",
		"title_en": "Full Roster Ensemble", "gimmick_en": "Everything so far, all at once. Charge!",
		"objects_min": 4, "objects_max": 5,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "fresnel": false, "choices": 6,
		"min_sep": 92.0, "min_events": 4, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 68.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "延伸経路のオデッセイ", "gimmick": "まだまだ増える．",
		"title_en": "Long Path Odyssey", "gimmick_en": "And there is still more of it.",
		"objects_min": 5, "objects_max": 6,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "fresnel": false, "choices": 6,
		"min_sep": 88.0, "min_events": 5, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 65.0,
		"min_slips": 5, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "基礎課程のフィナーレ", "gimmick": "フィナーレだ．しかし，まだこれで終わりではない．",
		"title_en": "Foundation Finale", "gimmick_en": "The finale. Though this is not the end of it.",
		"objects_min": 5, "objects_max": 6,
		"kinds": ALL_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "fresnel": false, "choices": 7,
		"min_sep": 84.0, "min_events": 6, "min_objects": 4, "min_tir": 1,
		"min_deviation": 150.0, "decoy_clear": 62.0,
		"min_slips": 5, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
]

## Polarization lives here and nowhere else in the game. The elements come one
## at a time, then the last three mix them
const HARD := [
	{
		"title": "直交軸のアニヒレーション", "gimmick": "偏光板が2枚．向きの組み合わせが重要．",
		"title_en": "Crossed Axis Annihilation", "gimmick_en": "Two polarizing sheets. What matters is how their axes sit together.",
		"objects_min": 4, "objects_max": 5,
		"kinds": SHEET_KINDS, "materials": DENSE, "metals": ALL_METALS,
		"require_kinds": [], "place_kinds": ["polarizer", "polarizer"], "sheet_step": PI * 0.5,
		# what the pair does not stop is the answer, and a leftover is fragile by
		# nature. Either max_shake or min_sheet on its own leaves no boards at all,
		# so both are off until the level asks for something else
		"require_mistakes": ["no_polarizer"], "fresnel": true, "choices": 5,
		"min_sep": 100.0, "min_events": 3, "min_objects": 2, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 80.0,
		"min_slips": 3, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 0.0, "min_sheet": 0.0,
	},
	{
		"title": "複屈折のドッペルゲンガー", "gimmick": "結晶を通った光は，1本では済まない．",
		"title_en": "Birefringent Doppelganger", "gimmick_en": "Light that went through a crystal does not come out as one beam.",
		"objects_min": 3, "objects_max": 5,
		"kinds": SHEET_KINDS, "materials": CRYSTAL, "metals": ALL_METALS,
		"require_kinds": [], "place_crystal": 1,
		"fresnel": true, "choices": 6,
		"min_sep": 90.0, "min_events": 3, "min_objects": 2, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 70.0,
		"min_slips": 3, "answers": 2, "require_crystal": true, "require_split": true, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "二線択一のジャッジメント", "gimmick": "分かれた光を偏光板がふるいにかける．",
		"title_en": "Two Beam Judgement", "gimmick_en": "A sheet sifts the beams the crystal parted.",
		"objects_min": 3, "objects_max": 5,
		"kinds": SHEET_KINDS, "materials": CRYSTAL, "metals": ALL_METALS,
		"require_kinds": ["polarizer"], "place_kinds": ["polarizer"], "place_crystal": 1,
		"require_mistakes": ["no_polarizer"], "fresnel": true, "choices": 6,
		"min_sep": 90.0, "min_events": 3, "min_objects": 2, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 70.0,
		"min_slips": 4, "answers": 1, "require_crystal": true, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "旋光作用のカイラリティ", "gimmick": "偏光面を回す液体が混ざる．",
		"title_en": "Rotary Chirality", "gimmick_en": "A liquid that turns the plane of polarization joins in.",
		# the three that matter sit in a row, so the room above the count they take
		# is what can bend the beam off the line it came in on
		"objects_min": 4, "objects_max": 5,
		"kinds": SHEET_KINDS, "materials": EVERY, "metals": ALL_METALS,
		# the pair is parallel, so without the liquid the light would go straight
		# through. Crossing them instead and letting the rotation revive the beam
		# lands it exactly where reading none of this would, which is no question.
		# What gets through is a branch rather than the beam itself, so what the
		# path has to carry is kept low
		"require_kinds": [], "place_kinds": ["polarizer", "polarizer"], "sheet_step": 0.0, "place_rotary": 1,
		"require_mistakes": ["no_rotation"], "fresnel": true, "choices": 6,
		"min_sep": 90.0, "min_events": 3, "min_objects": 2, "min_tir": 0,
		"min_deviation": 90.0, "decoy_clear": 60.0,
		# the pair being parallel is what buys the wider angle: a bar met askew has
		# its blocking axis foreshortened, and both bars lose the same amount, so
		# what the player reads off the two of them still holds
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.70,
	},
	{
		"title": "連続勾配のミラージュ", "gimmick": "屈折率が場所で変わる媒質を通る．",
		"title_en": "Gradient Mirage", "gimmick_en": "Through a medium whose index changes from place to place.",
		"objects_min": 3, "objects_max": 5,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": ["gradient"], "place_kinds": ["gradient"],
		"require_mistakes": ["flat_gradient", "flip_gradient"], "fresnel": true, "choices": 6,
		"min_sep": 90.0, "min_events": 3, "min_objects": 2, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 70.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "湾曲漸近のアシンプトート", "gimmick": "曲がった先で，面にどう当たるか．",
		"title_en": "Curving Asymptote", "gimmick_en": "How the curved path meets the face it runs into.",
		"objects_min": 4, "objects_max": 5,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": ["gradient"], "place_kinds": ["gradient"],
		"require_mistakes": ["flat_gradient"], "fresnel": true, "choices": 6,
		"min_sep": 88.0, "min_events": 4, "min_objects": 3, "min_tir": 1,
		"min_deviation": 150.0, "decoy_clear": 68.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "多重要素のコンフルエンス", "gimmick": "ハードモードで増えた要素が合流する．",
		"title_en": "Many Element Confluence", "gimmick_en": "Everything Hard Mode added, arriving together.",
		"objects_min": 4, "objects_max": 5,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": [],
		"fresnel": true, "choices": 6,
		"min_sep": 84.0, "min_events": 4, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 66.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "湾曲選別のシークエンス", "gimmick": "曲げてから選ぶ，二段構え．",
		"title_en": "Bend and Sort Sequence", "gimmick_en": "Bend it first, then sort it. Two steps.",
		"objects_min": 5, "objects_max": 6,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": ["gradient"], "place_kinds": ["gradient"],
		"fresnel": true, "choices": 7,
		"min_sep": 80.0, "min_events": 5, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 63.0,
		"min_slips": 4, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "複合過程のクライマックス", "gimmick": "正解できたら，やりますねぇスギ？",
		"title_en": "Compound Process Climax", "gimmick_en": "Get this one right. Yarimasune Sugi?",
		"objects_min": 5, "objects_max": 6,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": [], "place_kinds": ["gradient"],
		"fresnel": true, "choices": 7,
		"min_sep": 78.0, "min_events": 6, "min_objects": 4, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 60.0,
		"min_slips": 5, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
]

## Five problems with nothing held back. Every element the game has can turn up
## in any of them, and the only thing that changes down the list is how much of
## the board the light has to be followed across
const EXTRA := [
	{
		"title": "重層要素のポリフォニー", "gimmick": "複数の要素が同時に効いてくる．",
		"title_en": "Layered Element Polyphony", "gimmick_en": "Several elements bite at the same time.",
		"objects_min": 5, "objects_max": 6,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": ["gradient"], "place_kinds": ["gradient"],
		"fresnel": true, "choices": 7,
		"min_sep": 80.0, "min_events": 5, "min_objects": 4, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 60.0,
		"min_slips": 5, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "湾曲軌道のインターセプト", "gimmick": "曲がっていく経路の途中に，別の面が待っている．",
		"title_en": "Curved Path Intercept", "gimmick_en": "Another face is waiting partway along the curve.",
		"objects_min": 5, "objects_max": 7,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": ["gradient"], "place_kinds": ["gradient"],
		"fresnel": true, "choices": 7,
		"min_sep": 78.0, "min_events": 5, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 60.0,
		"min_slips": 5, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "深部臨界のランデヴー", "gimmick": "奥まで入った光が，あなたを迷宮へと誘い込む．",
		"title_en": "Deep Critical Rendezvous", "gimmick_en": "Light that got in deep leads you into the maze.",
		"objects_min": 6, "objects_max": 7,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": ["gradient"], "place_kinds": ["gradient"],
		"fresnel": true, "choices": 7,
		# every element on one path already makes this the thinnest board in the
		# game, and asking for a sixth bounce on top of it left almost none
		"min_sep": 76.0, "min_events": 5, "min_objects": 3, "min_tir": 1,
		"min_deviation": 150.0, "decoy_clear": 58.0,
		"min_slips": 5, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "八分岐のオクテット", "gimmick": "選択肢は8つ．",
		"title_en": "Eight Way Octet", "gimmick_en": "Eight choices.",
		"objects_min": 6, "objects_max": 7,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": [], "place_kinds": ["gradient"],
		"fresnel": true, "choices": 8,
		"min_sep": 74.0, "min_events": 6, "min_objects": 3, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 58.0,
		"min_slips": 5, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
	{
		"title": "全収束のシンギュラリティ", "gimmick": "正解できたら，やりますねぇスギ？",
		"title_en": "Total Convergence Singularity", "gimmick_en": "Get this one right. Yarimasune Sugi?",
		"objects_min": 6, "objects_max": 8,
		"kinds": FULL_KINDS, "materials": EVERY, "metals": ALL_METALS,
		"require_kinds": ["gradient"], "place_kinds": ["gradient"],
		"fresnel": true, "choices": 8,
		"min_sep": 72.0, "min_events": 7, "min_objects": 4, "min_tir": 0,
		"min_deviation": 150.0, "decoy_clear": 58.0,
		"min_slips": 5, "answers": 1, "require_crystal": false, "min_clear": 16.0, "min_entry": 24.0, "min_near": 10.0, "min_cos": 0.20, "max_shake": 58.0, "min_sheet": 0.90,
	},
]

## Where each ladder starts inside LEVELS
const MAIN_COUNT := 15
const HARD_COUNT := 9
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


## What each ladder is called on screen
const NAMES := {"main": "ノーマル", "hard": "ハード", "extra": "エクストラ"}
const NAMES_EN := {"main": "Normal", "hard": "Hard", "extra": "Extra"}


static func short_name(mode: String) -> String:
	var names := NAMES_EN if Lang.en() else NAMES
	return str(names.get(mode, ""))


## For the HUD, where the screen is the ladder and naming it in full each time
## only makes the line longer
static func prefix_of(mode: String) -> String:
	return "" if mode == "main" else short_name(mode) + " "


## For prose, where a ladder is being named rather than labelled
static func mode_name(mode: String) -> String:
	if not NAMES.has(mode):
		return ""
	return "%s Mode" % NAMES_EN[mode] if Lang.en() else "%sモード" % NAMES[mode]


static func title_of(level: Dictionary) -> String:
	return str(level.get("title_en", level.title)) if Lang.en() else str(level.title)


static func gimmick_of(level: Dictionary) -> String:
	return str(level.get("gimmick_en", level.gimmick)) if Lang.en() else str(level.gimmick)


static func label(index: int) -> String:
	return prefix_of(mode_of(index)) + short_label(index)


## Without the ladder's name, for a screen that already says which one it is
static func short_label(index: int) -> String:
	var mode := mode_of(index)
	return "Lv. %d %s" % [index - start_of(mode) + 1, title_of(LEVELS[index])]

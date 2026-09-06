class_name Lang
## Japanese is the original, so an entry with no English falls back to it.
##
## Not an autoload: the material and level tables are static and reach for this,
## and an autoload name does not exist in a script run with -s, which is how the
## tests and the generator tools start.
##
## Only the short strings scattered through the screens are keyed here. Anything
## long enough to read as prose (tutorial pages, codex trivia, level names) sits
## next to what shows it, one table per language


const LOCALES := ["ja", "en"]
const PATH := "user://settings.cfg"

static var locale := "ja"


## Japanese until the button says otherwise. Reading the OS instead sounds
## better and is not: a Japanese player on an English desktop is the common
## case, and they would land on the translation
static func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var saved := str(cfg.get_value("settings", "locale", ""))
	if LOCALES.has(saved):
		locale = saved


static func en() -> bool:
	return locale == "en"


static func t(key: String) -> String:
	var entry: Dictionary = UI.get(key, {})
	if entry.is_empty():
		return key
	return str(entry.get(locale, entry.ja))


## Screens are built in code, so the caller reloads itself rather than walking
## its own labels
static func toggle() -> void:
	locale = "en" if locale == "ja" else "ja"
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "locale", locale)
	cfg.save(PATH)


## In its own language either way round, so the button needs no translating
static func other_name() -> String:
	return "日本語" if en() else "English"


const UI := {
	"menu": {"ja": "メニュー", "en": "Menu"},
	"back_menu": {"ja": "メニューへ戻る", "en": "Back to menu"},
	"confirm": {"ja": "確認", "en": "Confirm"},
	"cancel": {"ja": "やめる", "en": "Cancel"},

	"menu.tutorial": {"ja": "チュートリアル", "en": "Tutorial"},
	"menu.codex": {"ja": "物質図鑑", "en": "Material codex"},
	"menu.creative": {"ja": "クリエイティブモード", "en": "Creative mode"},
	"menu.wipe": {"ja": "スコアをリセット", "en": "Reset score"},
	"menu.wipe_ok": {"ja": "リセット", "en": "Reset"},
	"menu.wipe_ask": {"ja": "スコア %d 点をリセットします．よろしいですか．", "en": "Reset your score of %d?"},
	"menu.wipe_done": {"ja": "スコアをリセットしました", "en": "Score reset"},
	"menu.quit": {"ja": "終了", "en": "Quit"},
	"menu.score": {"ja": "スコア %d 点    最高連続正解 %d", "en": "Score %d    Best streak %d"},
	"menu.dev": {"ja": "デバッグ実行    進捗は保存されず，起動のたびに %s へ戻ります",
			"en": "Debug run    Progress is not saved and resets to %s every launch"},
	"blurb.tutorial": {"ja": "まずはここから", "en": "Start here"},
	"blurb.codex": {"ja": "すべての物質を見られる", "en": "Every material in the game"},
	"blurb.main": {"ja": "かんたん", "en": "Easy"},
	"blurb.hard": {"ja": "少し難しい", "en": "Harder"},
	"blurb.extra": {"ja": "とても難しい", "en": "Hardest"},
	"gate.hard": {"ja": "ノーマルモード Lv. %d をクリアで解放", "en": "Clear Normal Mode Lv. %d to unlock"},
	"gate.extra": {"ja": "ハードモードを全てクリアで解放", "en": "Clear all of Hard Mode to unlock"},
	"gate.hard_long": {"ja": "ノーマルモード Lv. %d をクリアすると解放されます",
			"en": "Clear Normal Mode Lv. %d to unlock this"},
	"gate.extra_long": {"ja": "ハードモードを全てクリアすると解放されます",
			"en": "Clear all of Hard Mode to unlock this"},
	"gate.level": {"ja": "%s Lv. %d をクリアすると解放されます", "en": "Clear %s Lv. %d to unlock this"},

	"tut.title": {"ja": "チュートリアル", "en": "Tutorial"},
	"tut.sub": {"ja": "まずは遊び方から．そのあとはどれから読んでも構いません",
			"en": "Start with How to play. After that, read them in any order"},
	"tut.list": {"ja": "一覧へ", "en": "To the list"},
	"tut.back": {"ja": "戻る", "en": "Back"},
	"tut.next": {"ja": "次へ", "en": "Next"},
	"tut.done": {"ja": "終わる", "en": "Finish"},
	"tut.from_air": {"ja": "空気から入る", "en": "Into the glass"},
	"tut.from_glass": {"ja": "媒質から出る", "en": "Out of the glass"},

	"game.copy": {"ja": "コピー", "en": "Copy"},
	"game.copied": {"ja": "コピー済", "en": "Copied"},
	"game.retry": {"ja": "別の問題", "en": "New problem"},
	"game.wipe_memo": {"ja": "メモを全消去", "en": "Clear notes"},
	"game.memo_keys": {"ja": "左ドラッグ\nShift + 左ドラッグ\n右ドラッグ\nZ キー",
			"en": "Left drag\nShift + left drag\nRight drag\nZ key"},
	"game.memo_acts": {"ja": "書く\n直線\n一筆消す\nひとつ戻す",
			"en": "Draw\nStraight line\nErase a stroke\nUndo"},
	"game.building": {"ja": "問題を作成中", "en": "Building a problem"},
	"game.replay": {"ja": "もう一度再生  (R)", "en": "Play it again  (R)"},
	"game.to_editor": {"ja": "エディタへ  (Space)", "en": "To the editor  (Space)"},
	"game.next_problem": {"ja": "次の問題  (Space)", "en": "Next problem  (Space)"},
	"game.try_another": {"ja": "別の問題で再挑戦  (Space)", "en": "Try another one  (Space)"},
	"game.next_level": {"ja": "次のレベルへ  (Space)", "en": "Next level  (Space)"},
	"game.to_menu": {"ja": "メニューへ  (Space)", "en": "To the menu  (Space)"},
	"game.ask_one": {"ja": "光が抜ける地点を選ぶ  (キー %s でも選択可)",
			"en": "Pick where the light leaves  (or press %s)"},
	"game.ask_one_bright": {"ja": "最も明るい光が抜ける地点を選ぶ  (キー %s でも選択可)",
			"en": "Pick where the brightest light leaves  (or press %s)"},
	"game.ask_many": {"ja": "光が抜ける地点を %d 箇所選ぶ  (%d / %d)   キー %s でも選択可",
			"en": "Pick %d points where the light leaves  (%d / %d)   or press %s"},
	"game.ask_many_bright": {"ja": "明るい方から %d 箇所選ぶ  (%d / %d)   キー %s でも選択可",
			"en": "Pick %d points, brightest first  (%d / %d)   or press %s"},
	"game.unlocked": {"ja": "%sが解放されました", "en": "%s unlocked"},
	"game.right": {"ja": "○ 正解", "en": "○ Correct"},
	"game.right_scored": {"ja": "○ 正解  +%d 点", "en": "○ Correct  +%d"},
	"game.streak": {"ja": "  (%d 連続)", "en": "  (%d in a row)"},
	"game.wrong": {"ja": "× 不正解    正解は %s", "en": "× Wrong    The answer was %s"},
	"game.wrong_scored": {"ja": "× 不正解  −%d 点    正解は %s", "en": "× Wrong  −%d    The answer was %s"},
	"game.events": {"ja": "    相互作用 %d回", "en": "    %d interactions"},
	"game.reached": {"ja": "    最も明るい出口に全体の %d%% が到達",
			"en": "    %d%% of the light reached the brightest exit"},
	"game.stats": {"ja": "スコア %d 点        連続正解 %d", "en": "Score %d        Streak %d"},
	"game.shared": {"ja": "共有ステージ", "en": "Shared stage"},
	"game.seed_custom": {"ja": "Seed: (作成ステージ)", "en": "Seed: (custom stage)"},

	"ed.title": {"ja": "クリエイティブ", "en": "Creative"},
	"ed.help": {"ja": "物体: クリックで選択  中をドラッグで移動  外周で大きさ  頂点で回転  ホイールでも回転\n光源: 枠上の2点をドラッグ (根元=位置，先端=向き)    手動時は枠付近クリックで誤答を追加\n偏光板の透過軸と勾配の傾きは，選んでから下のリストで変えます",
			"en": "Body: click to select  drag the middle to move  the rim to resize  a corner or the wheel to turn\nSource: drag the two frame points (root = place, tip = aim)    on manual, click near the frame for a wrong choice\nA sheet's axis and a gradient's slope are set in the list below, once the body is selected"},
	"ed.delete": {"ja": "削除", "en": "Delete"},
	"ed.clear": {"ja": "全消去", "en": "Clear all"},
	"ed.fresnel": {"ja": "分岐 (Fresnel)", "en": "Branching"},
	"ed.auto": {"ja": "選択肢生成", "en": "Auto choices"},
	"ed.choices": {"ja": "選択肢", "en": "Choices"},
	"ed.paste": {"ja": "コードを貼り付け", "en": "Paste a code"},
	"ed.load": {"ja": "読み込み", "en": "Load"},
	"ed.copy": {"ja": "コードをコピー", "en": "Copy code"},
	"ed.play": {"ja": "遊ぶ", "en": "Play"},
	"ed.pick_body": {"ja": "物質 (物体を選ぶ)", "en": "Material (select a body)"},
	"ed.no_material": {"ja": "物質なし", "en": "No material"},
	"ed.axis": {"ja": "透過軸 %d°", "en": "Axis %d°"},
	"ed.slope": {"ja": "勾配 %+d%%", "en": "Slope %+d%%"},
	"ed.too_many": {"ja": "物体は %d 個までです", "en": "Up to %d bodies"},
	"ed.no_room": {"ja": "空いている場所がありません", "en": "No room left for one"},
	"ed.near_handle": {"ja": "光源のハンドルに近すぎます．少し離してから置いてください",
			"en": "Too close to a source handle. Drop it a little further away"},
	"ed.too_many_choices": {"ja": "選択肢は %d 個までです", "en": "Up to %d choices"},
	"ed.fault_size": {"ja": "大きさが範囲外", "en": "sized out of range"},
	"ed.fault_outside": {"ja": "枠からはみ出している", "en": "sticking out of the frame"},
	"ed.fault_overlap": {"ja": "他の物体と重なっている", "en": "overlapping another body"},
	"ed.cannot_load": {"ja": "読み込めません: ", "en": "Cannot load: "},
	"ed.seed_failed": {"ja": "この seed からは再現できませんでした", "en": "That seed did not rebuild"},
	"ed.seed_loaded": {"ja": "Lv. %d の seed を読み込みました．編集するとこのステージは共有コードになります",
			"en": "Loaded the seed for Lv. %d. Editing it turns the stage into a shared code"},
	"ed.code_loaded": {"ja": "共有コードを読み込みました", "en": "Loaded a shared code"},
	"ed.fix_red": {"ja": "赤い物体を直してください (%d 個)", "en": "Fix the bodies marked red (%d)"},
	"ed.cannot_encode": {"ja": "コードにできません: ", "en": "Cannot encode: "},
	"ed.no_exit": {"ja": "この配置では光が抜けません (光源の向きか物体の位置を変えてください)",
			"en": "No light gets out of this layout (turn the source, or move a body)"},
	"ed.place_decoys": {"ja": "緑が正解の出口．枠のあたりをクリックして誤答の選択肢を置いてください",
			"en": "Green is the answer. Click near the frame to place the wrong choices"},
	"ed.cannot_ask": {"ja": "この配置では出題できません (選択肢が置けていないか，正解に近すぎます)",
			"en": "This layout cannot be asked (no choices fit, or they sit too near the answer)"},
	"ed.summary": {"ja": "物体 %d 個   相互作用 %d回   答える箇所 %d   コード %d文字",
			"en": "%d bodies   %d interactions   %d to answer   %d characters"},
	"ed.no_share_red": {"ja": "赤い物体があるうちは共有できません", "en": "Cannot share while a body is red"},
	"ed.copied": {"ja": "コードをクリップボードにコピーしました", "en": "Code copied to the clipboard"},
	"ed.no_play_red": {"ja": "赤い物体があるうちは遊べません", "en": "Cannot play while a body is red"},
	"ed.not_askable": {"ja": "出題できる配置になっていません", "en": "This layout cannot be asked yet"},
	"shape.mirror": {"ja": "鏡", "en": "Mirror"},
	"shape.slab": {"ja": "板", "en": "Slab"},
	"shape.circle": {"ja": "円", "en": "Circle"},
	"shape.prism": {"ja": "プリズム", "en": "Prism"},
	"shape.polarizer": {"ja": "偏光板", "en": "Polarizer"},
	"shape.gradient": {"ja": "勾配", "en": "Gradient"},
	"draw.rotation": {"ja": "旋光", "en": "rot"},

	"code.too_long": {"ja": "コードが長すぎます", "en": "The code is too long"},
	"code.bad_form": {"ja": "コードの形式が違います", "en": "That is not the shape of a code"},
	"code.bad_level": {"ja": "レベルの番号が読めません", "en": "Cannot read the level number"},
	"code.level_range": {"ja": "レベルの番号が範囲外です", "en": "The level number is out of range"},
	"code.bad_seed": {"ja": "seed が読めません", "en": "Cannot read the seed"},
	"code.broken": {"ja": "コードが壊れています", "en": "The code is damaged"},
	"code.version": {"ja": "コードのバージョンが違います", "en": "The code is from another version"},
	"code.choice_range": {"ja": "選択肢の数が範囲外です", "en": "That many choices is out of range"},
	"code.source_range": {"ja": "光源の位置が範囲外です", "en": "The source sits out of range"},
	"code.source_aim": {"ja": "光源が画面の外を向いています", "en": "The source points off the screen"},
	"code.many_objects": {"ja": "物体が多すぎます", "en": "Too many bodies"},
	"code.bad_kind": {"ja": "知らない形状が入っています", "en": "There is a shape I do not know"},
	"code.bad_material": {"ja": "知らない物質が入っています", "en": "There is a material I do not know"},
	"code.size_range": {"ja": "物体の大きさが範囲外です", "en": "A body is sized out of range"},
	"code.outside": {"ja": "物体が画面の外に出ています", "en": "A body is off the screen"},
	"code.overlap": {"ja": "物体が重なっています", "en": "Two bodies overlap"},
	"code.many_decoys": {"ja": "誤答の選択肢が多すぎます", "en": "Too many wrong choices"},
	"code.decoy_range": {"ja": "誤答の位置が範囲外です", "en": "A wrong choice sits out of range"},

	"tut.follow": {"ja": "ここから先は自分で追います", "en": "You follow it yourself from here"},
	"tut.rules_right": {"ja": "%s が正解    ここから光が出ます", "en": "%s is right    the light leaves here"},
	"tut.rules_picked": {"ja": "%s を選んでいます", "en": "You have picked %s"},
	"tut.bend": {"ja": "遅い側へ入ると，進む向きが変わります",
			"en": "Going into the slower side, the direction changes"},
	"tut.axle": {"ja": "車軸", "en": "axle"},
	"tut.wheel": {"ja": "車輪", "en": "wheel"},
	"tut.band": {"ja": "光の帯", "en": "band of light"},
	"tut.wheel_in": {"ja": "先に入った車輪が遅れます", "en": "the wheel that went in first falls behind"},
	"tut.wheel_out": {"ja": "先に出た車輪が先へ進みます", "en": "the wheel that got out first pulls ahead"},
	"tut.mirror_law": {"ja": "入射角 = 反射角", "en": "incidence = reflection"},
	"tut.incidence": {"ja": "入射角", "en": "incidence"},
	"tut.reflection": {"ja": "反射角", "en": "reflection"},
	"tut.from_normal": {"ja": "面ではなく法線から測ります", "en": "Measured from the normal, not from the surface"},
	"tut.mirror_live": {"ja": "入射角 = 反射角 = %.1f°", "en": "incidence = reflection = %.1f°"},
	"tut.normal": {"ja": "法線", "en": "normal"},
	"tut.tir": {"ja": "    全反射", "en": "    total reflection"},
	"tut.tir_critical": {"ja": "    全反射    臨界角 %.1f°", "en": "    total reflection    critical angle %.1f°"},
	"tut.critical_live": {"ja": "θ₁ = %.1f°    臨界角 %.1f°", "en": "θ₁ = %.1f°    critical angle %.1f°"},
	"tut.split_live": {"ja": "θ₁ = %.1f°    跳ね返る %.0f%%    通る %.0f%%",
			"en": "θ₁ = %.1f°    %.0f%% back    %.0f%% through"},
	"tut.split_note": {"ja": "入射角 %.0f°    跳ね返る %.0f%%", "en": "incidence %.0f°    %.0f%% back"},
	"tut.reflects": {"ja": "跳ね返る %.0f%%", "en": "%.0f%% back"},
	"tut.passes": {"ja": "通る %.0f%%", "en": "%.0f%% through"},
	"tut.natural": {"ja": "無偏光はどの向きにも振動しています", "en": "Natural light vibrates every which way"},
	"tut.bars": {"ja": "縦棒が面外 (s)，横棒が面内 (p)",
			"en": "an upright bar is out of the screen (s), a flat one is in it (p)"},
	"tut.aligned": {"ja": "抜けた光は透過軸の向きに揃います",
			"en": "What gets through lines up with the transmission axis"},
	"tut.sheet_live": {"ja": "2枚目 φ = %.0f°    通る %.0f%%", "en": "second sheet φ = %.0f°    %.0f%% through"},
	"tut.crossed": {"ja": "直交した2枚は光を通しません", "en": "Two crossed sheets pass nothing"},
	"tut.optic_axis": {"ja": "破線が光学軸", "en": "the dashed line is the optic axis"},
	"tut.crystal_note": {"ja": "結晶の向きが，どちらへ分かれるかを決めます",
			"en": "Which way the crystal points decides where the two go"},
	"tut.ordinary": {"ja": "常光線", "en": "ordinary ray"},
	"tut.extraordinary": {"ja": "異常光線", "en": "extraordinary ray"},
	"tut.crystal_live": {"ja": "光学軸 %.0f°    出口 %d 箇所", "en": "optic axis %.0f°    %d exits"},
	"tut.crystal_two": {"ja": "1本で入った光が2本になって出ていきます",
			"en": "One beam goes in and two come out"},
	"tut.spin_note": {"ja": "通った長さ %.0fpx で %.0f° 回りました", "en": "%.0f px through turned it %.0f°"},
	"tut.spin_live": {"ja": "直径 %.0fpx    回転 %.0f°    通る %.0f%%",
			"en": "diameter %.0f px    turn %.0f°    %.0f%% through"},
	"tut.grin_note": {"ja": "どちらも濃い側へ曲がります", "en": "Both curve toward the denser side"},
	"tut.grin_live": {"ja": "勾配 %+.4f / px    濃い側が %s", "en": "slope %+.4f / px    the denser side is %s"},
	"tut.below": {"ja": "下", "en": "at the bottom"},
	"tut.above": {"ja": "上", "en": "at the top"},
	"tut.grin_curve": {"ja": "屈折率が場所で変わる中では光路が曲がります",
			"en": "Where the index changes from place to place the path curves"},

	"codex.title": {"ja": "物質図鑑", "en": "Material Codex"},
	"codex.n": {"ja": "屈折率 n = %.4f", "en": "Refractive index n = %.4f"},
	"codex.speed": {"ja": "中を進む速さは v = c / n で，真空の %.1f %%",
			"en": "Inside it light runs at v = c / n, %.1f %% of its speed in vacuum"},
	"codex.critical": {"ja": "空気へ抜けるときの臨界角 %.1f°", "en": "Critical angle on the way out into air %.1f°"},
	"codex.birefringent": {"ja": "複屈折  常光線 n = %.4f，異常光線 n = %.4f  (%s)",
			"en": "Birefringent  ordinary n = %.4f, extraordinary n = %.4f  (%s)"},
	"codex.positive": {"ja": "正の結晶", "en": "positive crystal"},
	"codex.negative": {"ja": "負の結晶", "en": "negative crystal"},
	"codex.rotary": {"ja": "旋光  比旋光度 %+.3f °/mm  (%s)",
			"en": "Optically active  specific rotation %+.3f °/mm  (%s)"},
	"codex.dextro": {"ja": "右旋性", "en": "right handed"},
	"codex.levo": {"ja": "左旋性", "en": "left handed"},
	"codex.reflectance": {"ja": "反射率 %.0f %%", "en": "Reflectance %.0f %%"},
	"codex.absorbs": {"ja": "当たった光のうち %.0f %% が返り，残りは面に吸われます",
			"en": "%.0f %% of the light comes back and the surface takes the rest"},
	"codex.no_refract": {"ja": "裏へは通さないので屈折は起きず，法線を挟んだ折り返しだけが残ります",
			"en": "Nothing gets through it, so there is no refraction, only the fold across the normal"},
	"codex.hint_rotary": {"ja": "↑ ↓ で物質を選び，← → で通る長さを変えられます",
			"en": "↑ ↓ pick a material, ← → change how far the light runs through it"},
	"codex.hint_beam": {"ja": "↑ ↓ で物質を選び，枠の上の2点をドラッグ (根元 = 位置，先端 = 向き) か ← → で光を動かせます",
			"en": "↑ ↓ pick a material, drag the two points on the frame (root = place, tip = aim) or use ← → to move the light"},
	"codex.miss_ball": {"ja": "球に当たっていません", "en": "The beam misses the ball"},
	"codex.miss_mirror": {"ja": "鏡に当たっていません", "en": "The beam misses the mirror"},
	"codex.ball_live": {"ja": "入射角 %.1f°    屈折角 %.1f°    面で跳ね返る %.0f %%",
			"en": "Incidence %.1f°    Refraction %.1f°    %.0f %% bounces off the surface"},
	"codex.splits": {"ja": "    中で2本に分かれます", "en": "    Inside it becomes two beams"},
	"codex.metal_live": {"ja": "入射角 = 反射角 = %.1f°    返る光 %.0f %%",
			"en": "Incidence = reflection = %.1f°    %.0f %% comes back"},
	"codex.rotary_live": {"ja": "通る長さ %.0f px (%.0f mm)    偏光面が %.0f° 回り，直交した2枚目を %.0f %% 通ります",
			"en": "%.0f px through (%.0f mm)    the plane turns %.0f° and %.0f %% gets past the crossed second sheet"},
}

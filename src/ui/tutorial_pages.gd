class_name TutorialPages
## The tutorial text, one table per language. Every topic ends on a page that moves


const JA := {"rules": [
	{
		"title": "光がどこから出るかを当てる",
		"body": "枠のどこかから光が1本入り，鏡やガラスに当たりながら進んで，最後は枠のどこかから外へ出ます．光が出ていく点を当てるとクリアです．進み方は実際の物理法則のみで決まっており，運要素は関係しません．",
	},
	{
		"title": "見えているのは入口だけ",
		"body": "見えるのは，光が最初の物体に届くまでです．その先は物体の形と屈折率から自分で追います．出口の候補は枠のまわりに印で示され，正解は1つです．",
	},
	{
		"title": "正解すると次のレベルが解放される",
		"body": "印をクリックするか，印のキーを押すと解答になります．正解するとそのレベルがクリアになり，次が解放されます．間違えても他の問題で何度でも挑戦できます．左ドラッグで画面に書き込むことができ，メモを残せます．",
	},
	{
		"title": "選んでみる",
		"body": "ここでは印をクリックするか ← → キーで選べます．鏡だけなので跳ね返る角度を追えば届き，正解を選ぶと道すじが出ます．",
	},
], "refract": [
	{
		"title": "境界で向きが変わる",
		"body": "別の媒質へ斜めに入った光は，境界面で進む向きを変えます．これを屈折といいます．媒質中の速さは屈折率 n と光速 c から v = c / n で，n が大きいほど遅くなります．",
	},
	{
		"title": "光を帯として見る",
		"body": "曲がる向きは，光を幅のある帯として見ると追えます．帯の両端を車輪，横切る線を車軸とすると，先に遅くなった車輪の側へ車軸が傾きます．",
	},
	{
		"title": "遅い方へ入ると法線に近づく",
		"body": "斜めに入ると片方の車輪が先に遅い側へ入り，車軸が傾くぶん帯は法線に近づきます．屈折率の差が大きいほど曲がる量も増えます．",
	},
	{
		"title": "速い方へ出ると法線から離れる",
		"body": "速い側へ抜けるときは逆で，先に出た車輪が速くなって法線から離れます．入射角を大きくすると出口が無くなり，光がすべて戻ることもあります (全反射)．",
	},
	{
		"title": "式と鏡",
		"body": "式にするとスネルの法則で，n₁ sin θ₁ = n₂ sin θ₂ です．sin の比が速さの比になります．鏡は光を中へ通さないので屈折は起きず，折り返しだけが残ります．",
	},
	{
		"title": "動かして確かめる",
		"body": "ここでは画面をドラッグするか ← → キーで入射角を，ボタンで媒質を変えられます (本編では動かせません)．",
	},
], "mirror": [
	{
		"title": "角度は法線から測る",
		"body": "境界面に垂直な直線を法線といい，角度はここから測ります．入ってくる光と法線がなす角が入射角，跳ね返った光との角が反射角です．",
	},
	{
		"title": "入射角と反射角は等しい",
		"body": "滑らかな面では入射角と反射角が等しくなり，これを反射の法則といいます．鏡は光を中へ通さないので，折り返しだけが起きます．",
	},
	{
		"title": "動かして確かめる",
		"body": "ここでは画面をドラッグするか ← → キーで入射角を変えられます．法線を挟んだ反対側に，同じ角度で返ります．",
	},
], "critical": [
	{
		"title": "内側から出る光は法線から離れる",
		"body": "屈折率の大きい側から小さい側へ抜けるとき，屈折角は入射角より大きくなり，入射角より速く増えていきます．",
	},
	{
		"title": "臨界角では面に沿う",
		"body": "屈折角が 90 度になる入射角を臨界角といい，このとき光は境界面に沿います．sin θ = n₂ / n₁ で決まります．",
	},
	{
		"title": "超えると全部戻る",
		"body": "臨界角を超えると光は透過できず，すべて反射します．これが全反射で，鏡を置いていない透明な面が鏡と同じように働きます．",
	},
	{
		"title": "動かして確かめる",
		"body": "ここでは画面をドラッグするか ← → キーで入射角を変えられます．媒質を選び直すと臨界角も変わります．",
	},
], "split": [
	{
		"title": "面では光が2つに分かれる",
		"body": "透明な面では光が透過する分と反射する分に分かれます．割合はフレネルの式で決まり，足すと 1 です．反射する側は普通わずかですが，消えはしません．",
	},
	{
		"title": "浅く当たるほど跳ね返る",
		"body": "反射する割合は入射角で変わり，正面ならほとんど透過し，すれすれならほとんど反射します．屈折率の差が大きいほど反射も増えます．",
	},
	{
		"title": "動かして確かめる",
		"body": "ここでは画面をドラッグするか ← → キーで入射角を変えられます．透過と反射が入れ替わる角度を探してみてください．",
	},
], "sheet": [
	{
		"title": "光は進む向きと直角に振動している",
		"body": "光は電場と磁場の振動が伝わる波で，振動は進む向きと直角です．振動方向が一定の光を直線偏光，定まっていない光を自然光といいます．画面では縦棒が面外，横棒が面内の振動です．",
	},
	{
		"title": "板は1つの向きだけ通す",
		"body": "偏光板は決まった向きの偏光だけを通し，その向きを透過軸といいます．画面ではラベルの φ です．自然光を1枚通すと透過軸の向きの直線偏光になり，明るさは半分になります．",
	},
	{
		"title": "向きを直角にすると光が消える",
		"body": "1枚目で揃った光には，透過軸を直角にした2枚目を通れる成分が残っていません．2枚を直交させるだけで光が止まります．",
	},
	{
		"title": "動かして確かめる",
		"body": "ここでは ← → キーか画面のドラッグで2枚目の透過軸を回せます．2枚の軸がなす角 θ に対して cos²θ で通り，これをマリュスの法則といいます．",
	},
], "crystal": [
	{
		"title": "結晶には向きがある",
		"body": "方解石のような結晶では，偏光の向きによって屈折率が変わります．基準になる向きを光学軸といい，画面では破線で描いています．",
	},
	{
		"title": "入った光は2本に分かれる",
		"body": "入った光は偏光の状態で2本に分かれ，これを複屈折といいます．屈折率が向きによらない方を常光線，向きで変わる方を異常光線と呼びます．",
	},
	{
		"title": "動かして確かめる",
		"body": "ここでは ← → キーか画面のドラッグで光学軸を回せます．光が軸に沿って進むときは分かれません．",
	},
], "spin": [
	{
		"title": "偏光面が回る",
		"body": "直線偏光がある種の物質を通ると振動方向が回り，これを旋光といいます．自然光には効かないので，先に偏光板を通しておく必要があります．",
	},
	{
		"title": "回る量は長さに比例する",
		"body": "回る角度は通った長さに比例し，溶液なら濃度にも比例します．長さと濃度で割った値が比旋光度で，画面のラベルの °/mm です．",
	},
	{
		"title": "動かして確かめる",
		"body": "ここでは ← → キーで通る長さを変えられます．直交した2枚の間に置いてあるので，回った角度が 90 度に近いほど通ります．",
	},
], "grin": [
	{
		"title": "屈折率が場所で変わる",
		"body": "屈折率が場所によって違う媒質では，境界面で一度に曲がるのではなく，進みながら少しずつ向きが変わります．蜃気楼と同じ理由です．",
	},
	{
		"title": "濃い側へ曲がる",
		"body": "曲がる先は屈折率の高い側です．どちら側が高いかは，画面の塗りの濃さで分かります．",
	},
	{
		"title": "動かして確かめる",
		"body": "ここでは ← → キーで勾配の強さと向きを変えられます．0 に近づけると直進に戻り，強くすると内側で全反射することもあります．",
	},
]}

const EN := {"rules": [
	{
		"title": "Guess where the light comes out",
		"body": "One beam enters somewhere on the frame, runs into mirrors and glass on its way through, and finally leaves the frame somewhere else. Pick the point it leaves from and the level is cleared. Where it goes is decided by the real laws of optics and by nothing else, so there is no luck in it.",
	},
	{
		"title": "You only get to see the way in",
		"body": "What you can see is the light up to the first body it reaches. Past that you follow it yourself, from the shapes and their refractive indices. The candidates are marked around the frame, and exactly one of them is right.",
	},
	{
		"title": "A right answer opens the next level",
		"body": "Click a mark, or press its key, to answer. A right answer clears that level and opens the next one. Get it wrong and there are always other problems to try. Left drag to write on the screen if you want to keep notes.",
	},
	{
		"title": "Try picking one",
		"body": "Here you can pick a mark by clicking it or with the ← → keys. There is nothing but mirrors, so follow the angles it bounces at, and the path shows up once you get it right.",
	},
], "refract": [
	{
		"title": "The direction changes at a boundary",
		"body": "Light that crosses into another medium at an angle changes direction at the boundary. That is refraction. Its speed inside a medium is v = c / n from the refractive index n and the speed of light c, so a larger n means a slower one.",
	},
	{
		"title": "See the light as a band",
		"body": "Which way it bends is easier to follow if you see the light as a band with a width to it. Take the two edges of the band as wheels and a line across it as the axle: the axle tilts toward whichever wheel slowed down first.",
	},
	{
		"title": "Into the slower side, toward the normal",
		"body": "Entering at an angle, one wheel reaches the slower side first, and the band turns toward the normal by as much as the axle tilted. The bigger the difference in index, the more it bends.",
	},
	{
		"title": "Out into the faster side, away from the normal",
		"body": "Leaving into the faster side works the other way round: the wheel that got out first speeds up and the band turns away from the normal. Open the angle of incidence far enough and there is no way out left, and all of the light comes back (total reflection).",
	},
	{
		"title": "The equation, and mirrors",
		"body": "As an equation this is Snell's law, n₁ sin θ₁ = n₂ sin θ₂. The ratio of the sines is the ratio of the speeds. A mirror lets nothing inside it, so no refraction happens and only the fold is left.",
	},
	{
		"title": "Move it and see",
		"body": "Here you can drag the screen or use the ← → keys for the angle of incidence, and the buttons for the medium (none of this moves in the game itself).",
	},
], "mirror": [
	{
		"title": "Angles are measured from the normal",
		"body": "The line perpendicular to a surface is called its normal, and angles are measured from there. The angle between the incoming light and the normal is the angle of incidence, and the one to the light that bounced off is the angle of reflection.",
	},
	{
		"title": "Incidence and reflection are equal",
		"body": "On a smooth surface the angle of incidence and the angle of reflection are equal, which is the law of reflection. A mirror lets nothing inside it, so the fold is all that happens.",
	},
	{
		"title": "Move it and see",
		"body": "Here you can drag the screen or use the ← → keys for the angle of incidence. It comes back on the other side of the normal, at the same angle.",
	},
], "critical": [
	{
		"title": "On the way out, light turns away from the normal",
		"body": "Going from the side with the larger index into the smaller one, the angle of refraction is larger than the angle of incidence, and it grows faster than the angle of incidence does.",
	},
	{
		"title": "At the critical angle it runs along the surface",
		"body": "The angle of incidence at which the angle of refraction reaches 90 degrees is the critical angle, and there the light runs along the boundary itself. It is set by sin θ = n₂ / n₁.",
	},
	{
		"title": "Past it, all of it comes back",
		"body": "Past the critical angle none of the light gets through and all of it reflects. This is total reflection, and it makes a clear surface with no mirror on it work exactly like one.",
	},
	{
		"title": "Move it and see",
		"body": "Here you can drag the screen or use the ← → keys for the angle of incidence. Pick another medium and the critical angle moves with it.",
	},
], "split": [
	{
		"title": "At a surface the light splits in two",
		"body": "At a clear surface the light splits into the part that goes through and the part that comes back. The shares are set by the Fresnel equations and add up to 1. The reflected side is usually small, but it never quite disappears.",
	},
	{
		"title": "The shallower the hit, the more comes back",
		"body": "The share that reflects moves with the angle of incidence: head on almost all of it goes through, and at a grazing angle almost all of it comes back. A bigger difference in index reflects more as well.",
	},
	{
		"title": "Move it and see",
		"body": "Here you can drag the screen or use the ← → keys for the angle of incidence. See if you can find the angle where transmission and reflection swap over.",
	},
], "sheet": [
	{
		"title": "Light vibrates across the way it travels",
		"body": "Light is a wave of electric and magnetic fields, and the vibration sits at a right angle to the way it travels. Light whose vibration keeps one direction is linearly polarized, and light with no settled direction is natural light. On screen an upright bar is a vibration out of the screen and a flat one is in it.",
	},
	{
		"title": "A sheet passes one direction only",
		"body": "A polarizing sheet passes one direction of polarization and nothing else, and that direction is its transmission axis, the φ on the label here. Natural light through one sheet comes out linearly polarized along the axis, at half the brightness.",
	},
	{
		"title": "Cross them and the light is gone",
		"body": "The light the first sheet lined up has nothing left in it for a second sheet at a right angle to pass. Crossing two sheets is all it takes to stop the light.",
	},
	{
		"title": "Move it and see",
		"body": "Here the ← → keys or a drag on the screen turn the second sheet's axis. For an angle θ between the two axes, cos²θ of the light gets through, which is Malus's law.",
	},
], "crystal": [
	{
		"title": "A crystal has a direction to it",
		"body": "In a crystal like calcite the refractive index depends on which way the polarization points. The direction it is all measured against is the optic axis, drawn here as a dashed line.",
	},
	{
		"title": "The light going in splits in two",
		"body": "Light going in splits in two by its state of polarization, which is birefringence. The one whose index does not depend on direction is the ordinary ray, and the one that does is the extraordinary ray.",
	},
	{
		"title": "Move it and see",
		"body": "Here the ← → keys or a drag on the screen turn the optic axis. Light that runs along the axis does not split.",
	},
], "spin": [
	{
		"title": "The plane of polarization turns",
		"body": "Linearly polarized light through certain materials has its direction of vibration turned, which is optical rotation. It does nothing at all to natural light, so a polarizing sheet has to come first.",
	},
	{
		"title": "How far it turns goes with the distance",
		"body": "The angle it turns through is proportional to the distance travelled, and for a solution to the concentration as well. Divided out by both, that is the specific rotation, the °/mm on the label here.",
	},
	{
		"title": "Move it and see",
		"body": "Here the ← → keys change how far the light travels through it. It sits between two crossed sheets, so the nearer the turn gets to 90 degrees, the more comes through.",
	},
], "grin": [
	{
		"title": "The index changes from place to place",
		"body": "In a medium whose refractive index differs from place to place, light does not bend all at once at a surface: its direction changes a little at a time as it goes. A mirage happens for the same reason.",
	},
	{
		"title": "It curves toward the denser side",
		"body": "It curves toward whichever side has the higher index. Which side that is shows in how dark the fill is on screen.",
	},
	{
		"title": "Move it and see",
		"body": "Here the ← → keys change how steep the gradient is and which way it runs. Near 0 it goes back to a straight line, and steep enough it can reflect totally inside.",
	},
]}


static func of(topic: String) -> Array:
	var table := EN if Lang.en() else JA
	return table.get(topic, JA.rules)

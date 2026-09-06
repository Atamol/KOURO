class_name TutorialTopics
## What the tutorial covers. The rules come first, then the elements in the
## order the ladder hands them out. `hard` marks the ones that only turn up
## once hard mode is open


const LIST := [
	{"key": "rules", "title": "遊び方", "title_en": "How to play", "hard": false},
	{"key": "mirror", "title": "反射", "title_en": "Reflection", "hard": false},
	{"key": "refract", "title": "屈折", "title_en": "Refraction", "hard": false},
	{"key": "critical", "title": "全反射", "title_en": "Total reflection", "hard": false},
	{"key": "split", "title": "部分反射", "title_en": "Partial reflection", "hard": true},
	{"key": "sheet", "title": "偏光板", "title_en": "Polarizing sheets", "hard": true},
	{"key": "crystal", "title": "複屈折", "title_en": "Birefringence", "hard": true},
	{"key": "spin", "title": "旋光性", "title_en": "Optical rotation", "hard": true},
	{"key": "grin", "title": "屈折率勾配", "title_en": "Index gradient", "hard": true},
]


static func at(key: String) -> Dictionary:
	for t: Dictionary in LIST:
		if t.key == key:
			return t
	return LIST[0]


static func title_of(topic: Dictionary) -> String:
	return str(topic.title_en) if Lang.en() else str(topic.title)

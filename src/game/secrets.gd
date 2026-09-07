class_name Secrets
## Read from a .env beside the project file.
##
## This keeps a key out of version control, not out of a build: the game has to
## hold the signing key to sign with it, so anything here ships inside the pack
## and can be pulled back out


const PATH := "res://.env"


## No file means whatever wanted the value stays switched off
static func read(key: String, fallback := "") -> String:
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		return fallback
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var at := line.find("=")
		if at < 0 or line.substr(0, at).strip_edges() != key:
			continue
		return line.substr(at + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
	return fallback

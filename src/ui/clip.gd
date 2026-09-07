class_name Clip
## DisplayServer.clipboard_set is the whole story on desktop. On the web it fills
## Godot's own buffer and nothing else, so without the browser's own call a code
## copied in the game pastes back into the game and nowhere else


## Defined rather than run inline, so the text is handed over as an argument and
## never spliced into source. The modern call wants a secure context and can be
## refused inside a frame, which unityroom puts the game in, so the deprecated
## one stays as the way through when it is
const BRIDGE := """
window.kouroCopy = function (text) {
	var fallback = function () {
		var box = document.createElement('textarea');
		box.value = text;
		box.style.position = 'fixed';
		box.style.opacity = '0';
		document.body.appendChild(box);
		box.focus();
		box.select();
		try { document.execCommand('copy'); } catch (e) {}
		document.body.removeChild(box);
	};
	try {
		if (navigator.clipboard && navigator.clipboard.writeText) {
			navigator.clipboard.writeText(text).catch(fallback);
			return;
		}
	} catch (e) {}
	fallback();
};
"""


## Godot answers Ctrl+V itself and calls preventDefault, so the browser never
## gets as far as pasting and the event below never fires. Taking the key away
## from it while the code field waits is what makes the rest work.
##
## Reading the clipboard outright would be the obvious way and is not open to a
## page: Chrome asks permission for it and Firefox refuses outright
const CATCH := """
if (!window.kouroPasteHooked) {
	window.kouroPasteHooked = true;
	window.kouroPasted = '';
	window.kouroWantPaste = false;
	window.addEventListener('keydown', function (e) {
		if (window.kouroWantPaste && (e.ctrlKey || e.metaKey) && (e.key === 'v' || e.key === 'V')) {
			e.stopImmediatePropagation();
		}
	}, true);
	document.addEventListener('paste', function (e) {
		try {
			window.kouroPasted = (e.clipboardData || window.clipboardData).getData('text');
		} catch (err) {}
	}, true);
}
"""


static func put(text: String) -> void:
	DisplayServer.clipboard_set(text)
	if OS.get_name() != "Web":
		return
	JavaScriptBridge.eval(BRIDGE, true)
	var page := JavaScriptBridge.get_interface("window")
	if page != null:
		page.kouroCopy(text)


## Call once from a screen that has somewhere to paste into
static func listen() -> void:
	if OS.get_name() == "Web":
		JavaScriptBridge.eval(CATCH, true)


## Whether a paste should go to the browser rather than to Godot
static func want_paste(on: bool) -> void:
	if OS.get_name() != "Web":
		return
	var page := JavaScriptBridge.get_interface("window")
	if page != null:
		page.kouroWantPaste = on


## What the browser has handed over since this was last asked, or "" for nothing.
## Godot's own paste only ever reaches its internal buffer on the web, so this is
## what a code copied from anywhere else arrives through
static func taken() -> String:
	if OS.get_name() != "Web":
		return ""
	var page := JavaScriptBridge.get_interface("window")
	if page == null:
		return ""
	var text := str(page.kouroPasted)
	if not text.is_empty():
		page.kouroPasted = ""
	return text

extends SceneTree

const COVER_PATHS := [
	"res://assets/songs/covers/aurora_demo.png",
	"res://assets/songs/covers/night_drive.png",
	"res://assets/songs/covers/pulse_grid.png",
]


func _init() -> void:
	# Keeps library artwork compact and pixel-crisp after regeneration.
	for path in COVER_PATHS:
		var image := Image.load_from_file(path)
		if image == null or image.is_empty():
			push_error("Could not load song cover: %s" % path)
			continue
		image.resize(512, 512, Image.INTERPOLATE_NEAREST)
		var error := image.save_png(path)
		if error != OK:
			push_error("Could not save song cover: %s" % path)
	quit()

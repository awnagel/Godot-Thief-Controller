extends AudioStreamPlayer
class_name ThiefPlayerAudio

enum Types {
	TYPE_FOOTSTEP,
	TYPE_LANDING,
	TYPE_BREATHE_IN,
	TYPE_BREATHE_OUT,
}

var _footstep_sounds : Array = []
var _landing_sounds : Array = []
var _clamber_sounds : Dictionary = {
	"in" : [],
	"out" : []
}

var _current_sound_dir : String = ""

func load_sounds(library: ThiefAudioLibrary):
	if library == null:
		return

	for dir in library.footstep_sound_dirs:
		_footstep_sounds.append_array(_load_directory(dir))
	
	for dir in library.landing_sound_dirs:
		_landing_sounds.append_array(_load_directory(dir))

	for dir in library.breathe_in_sound_dirs:
		_clamber_sounds["in"].append_array(_load_directory(dir))

	for dir in library.breathe_out_sound_dirs:
		_clamber_sounds["out"].append_array(_load_directory(dir))

func load_sound_folder(path: String, type: int):
	match type:
		Types.TYPE_FOOTSTEP:
			_footstep_sounds.append_array(_load_directory(path))
		Types.TYPE_LANDING:
			_landing_sounds.append_array(_load_directory(path))
		Types.TYPE_BREATHE_IN:
			_clamber_sounds["in"].append_array(_load_directory(path))
		Types.TYPE_BREATHE_OUT:
			_clamber_sounds["out"].append_array(_load_directory(path))

func _load_directory(path) -> Array:
	var dir := Directory.new()
	dir.open(path)
	dir.list_dir_begin(true)
	
	var array := []

	var snd = dir.get_next()
	while snd != "":
		if snd.ends_with(".wav"):
			array.append(load(path + "/" + snd))
		snd = dir.get_next()
	return array


func play_footstep_sound():
	if _footstep_sounds.size() > 0:
		_footstep_sounds.shuffle()
		stream = _footstep_sounds.front()
		play()


func play_land_sound():
	_landing_sounds.shuffle()
	stream = _landing_sounds.front()
	play()


func play_clamber_sound(clamber_in : bool) -> void:
	if clamber_in:
		if not stream in _clamber_sounds["in"]:
				_clamber_sounds["in"].shuffle()
				stream = _clamber_sounds["in"].front()
				play()
	else:
		if !playing:
				_clamber_sounds["out"].shuffle()
				stream = _clamber_sounds["out"].front()
				play()

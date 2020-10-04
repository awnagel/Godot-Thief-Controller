extends AudioStreamPlayer
class_name PlayerAudio

var _footstep_sounds : Array = []
var _landing_sounds : Array = []
var _clamber_sounds : Dictionary = {
	"in" : [],
	"out" : []
}

var _current_sound_dir : String = ""

func load_footstep_sounds(sound_dir, type : int) -> void:
	if sound_dir == "":
		return
		
	if _current_sound_dir == sound_dir:
		return
		
	_current_sound_dir = sound_dir
	
	if sound_dir.ends_with("/"):
		sound_dir.erase(sound_dir.length() - 1, 1)
		
	if not "res://" in sound_dir:
		sound_dir = "res://" + sound_dir
	
	var snd_dir = Directory.new()
	snd_dir.open(sound_dir)
	snd_dir.list_dir_begin(true)
	
	var sound = snd_dir.get_next()
	while sound != "":
		if not sound.ends_with(".import"):
			if type == 0:
				_footstep_sounds.append(load(sound_dir + "/" + sound))
			elif type == 1:
				if "in" in sound:
					_clamber_sounds["in"].append(load(sound_dir + "/" + sound))
				elif "out" in sound:
					_clamber_sounds["out"].append(load(sound_dir + "/" + sound))
			elif type == 2:
				_landing_sounds.append(load(sound_dir + "/" + sound))
		sound = snd_dir.get_next()


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

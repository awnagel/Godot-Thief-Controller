extends AudioStreamPlayer

var footstep_sounds : Array = []
var landing_sounds : Array = []
var clamber_sounds : Dictionary = {
	"in" : [],
	"out" : []
}

var current_sound_dir : String = ""

func load_footstep_sounds(sound_dir, type : int) -> void:
	if sound_dir == "":
		return
		
	if current_sound_dir == sound_dir:
		return
		
	current_sound_dir = sound_dir
	
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
				footstep_sounds.append(load(sound_dir + "/" + sound))
			elif type == 1:
				if "in" in sound:
					clamber_sounds["in"].append(load(sound_dir + "/" + sound))
				elif "out" in sound:
					clamber_sounds["out"].append(load(sound_dir + "/" + sound))
			elif type == 2:
				landing_sounds.append(load(sound_dir + "/" + sound))
		sound = snd_dir.get_next()

func play_footstep_sound():
	if footstep_sounds.size() > 0:
		footstep_sounds.shuffle()
		stream = footstep_sounds.front()
		play()

func play_land_sound():
	landing_sounds.shuffle()
	stream = landing_sounds.front()
	play()

func play_clamber_sound(clamber_in : bool) -> void:
	if clamber_in:
		if not stream in clamber_sounds["in"]:
				clamber_sounds["in"].shuffle()
				stream = clamber_sounds["in"].front()
				play()
	else:
		if !playing:
				clamber_sounds["out"].shuffle()
				stream = clamber_sounds["out"].front()
				play()

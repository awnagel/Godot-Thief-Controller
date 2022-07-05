extends Resource
class_name ThiefSoundLibrary

# Add texture and the path of the folder with the corresponding sound files
# Don't include res://
export(Array, Resource) var library = []

func has(name: String) -> bool:
	for pair in library:
		if pair.texture_file_name == name:
			return true

	return false

func get(name: String):
	for pair in library:
		if pair.texture_file_name == name:
			return pair
	
	return null

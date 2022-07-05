extends Spatial
class_name ThiefLightDetector

onready var _octahedron = $Octahedron
onready var _viewport_top = $Viewport
onready var _viewport_bottom = $Viewport2
onready var _cam_top = $Viewport/CameraTop
onready var _cam_bottom = $Viewport2/CameraBottom

export var light_detect_interval : float = 0.25
export var ambient_light_correction : Color = Color.black
var _last_time_since_detect : float = 0.0

var _player : ThiefPlayer = null

func _ready() -> void:
	_player = get_parent()


func _get_time() -> float:
	return OS.get_ticks_msec() / 1000.0


func _process(_delta) -> void:
	var new_pos = _player.global_transform.origin
	
	_octahedron.global_transform.origin = new_pos
	_cam_top.global_transform.origin = new_pos
	_cam_bottom.global_transform.origin = new_pos
	
	if _last_time_since_detect + light_detect_interval > _get_time() and _last_time_since_detect != 0.0:
		return
	
	var thl = get_light_level(true)
	var bhl = get_light_level(false)
	var level = max(thl, bhl)
	if _player.state == _player.State.STATE_CROUCHING:
		level *= (1 - pow(1 - level, 3))
	_player.light_level = level
	_last_time_since_detect = _get_time()


func get_light_level(top : bool = true) -> float:
	var img = null
	if top:
		img = _viewport_top.get_texture().get_data()
	else:
		img = _viewport_bottom.get_texture().get_data()
	
	img.flip_y()
	
	img.lock()
	
	var p0 = img.get_pixel(0, 0)
	var hl = luminance(p0.r, p0.b, p0.g)				
	
	for y in img.get_height():
		for x in img.get_width():
			var p = img.get_pixel(x, y)
			var l = luminance(p.r, p.b, p.g)
			if l > hl:
				hl = l
	
	return hl

func luminance(r: float, g: float, b: float) -> float:
	var base = Color(r, g, b, 1)
	var adjusted = base - ambient_light_correction
	return 0.2126 * adjusted.r + 0.7152 * adjusted.g + 0.0722 * adjusted.b

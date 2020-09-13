extends Spatial

onready var octahedron = $Octahedron
onready var viewport_top = $Viewport
onready var viewport_bottom = $Viewport2
onready var cam_top = $Viewport/CameraTop
onready var cam_bottom = $Viewport2/CameraBottom

export var light_detect_interval : float = 0.25
var last_time_since_detect : float = 0.0

var player : Node = null

func _ready() -> void:
	player = get_tree().get_root().get_child(0).get_node("Player")

func get_time() -> float:
	return OS.get_ticks_msec() / 1000.0

func _process(_delta) -> void:
	var new_pos = player.global_transform.origin + Vector3.UP * 0.5
	
	octahedron.global_transform.origin = new_pos
	cam_top.global_transform.origin = new_pos
	cam_bottom.global_transform.origin = new_pos
	
	if last_time_since_detect + light_detect_interval > get_time() and last_time_since_detect != 0.0:
		return
	
	var thl = get_light_level(true)
	var bhl = get_light_level(false)
	var level = max(thl, bhl)
	if player.state == player.CROUCHING:
		level *= (1 - pow(1 - level, 3))
	player.light_level = level
	last_time_since_detect = get_time()

func get_light_level(top : bool = true) -> float:
	var img = null
	if top:
		img = viewport_top.get_texture().get_data()
	else:
		img = viewport_bottom.get_texture().get_data()
	
	img.flip_y()
	
	img.lock()
	
	var p0 = img.get_pixel(0, 0)
	var hl = 0.2126 * p0.r + 0.7152 * p0.g + 0.0722 * p0.b				
	
	for y in img.get_height():
		for x in img.get_width():
			var p = img.get_pixel(x, y)
			var l = 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b
			if l > hl:
				hl = l
	
	return hl

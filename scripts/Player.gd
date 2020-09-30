extends KinematicBody

onready var camera = $Camera
onready var collider = $Collider
onready var light_indicator = $Camera/CanvasLayer/LightIndicator
onready var surface_detector = $SurfaceDetector
onready var sound_emitter = $SoundEmitter
onready var audio_player = $Audio

enum {
	WALKING,
	LEANING,
	CROUCHING
}

var state = WALKING

export var speed : float = 1.0
export var mouse_sens : float = 0.5
export var lock_mouse : bool = true
export var head_bob_enabled : bool = true
export var footstep_sounds_folder : String = ""

var light_level : float = 0.0

var velocity : Vector3 = Vector3.ZERO

var bob_reset : float = 0.0

var footstep_sounds : Array = []

var camera_pos_normal : Vector3 = Vector3.ZERO
var collision_normal_height : float = 0.0
var collision_normal_offset : float = 0.0

func _ready() -> void:
	bob_reset = camera.global_transform.origin.y
	
	collision_normal_height = collider.shape.height
	collision_normal_offset = collider.global_transform.origin.y
	
	load_footstep_sounds(footstep_sounds_folder)
	
	if lock_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
var current_sound_dir : String = ""
	
func load_footstep_sounds(sound_dir) -> void:
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
			footstep_sounds.append(load(sound_dir + "/" + sound))
		sound = snd_dir.get_next()
	
func get_surface_texture() -> Dictionary:
	if surface_detector.get_collider():
		var mesh = null
		for node in surface_detector.get_collider().get_children():
			if node is MeshInstance:
				if node.mesh != null:
					mesh = node
		
		if !mesh:
			return {}
		
		if mesh.get_surface_material(0) != null:
				var path = mesh.get_surface_material(0).albedo_texture.resource_path.split("/")
				var n = path[path.size() - 1].split(".")[0]
				if TEXTURE_SOUND_LIB.has(n):
					return TEXTURE_SOUND_LIB[n]
					
	return {}
		
func handle_player_sound_emission() -> void:
	var result = get_surface_texture()
	
	if result.size() == 0:
		return
	
	sound_emitter.radius = result["amplifier"]
	
	if result.sfx_folder != "":
		load_footstep_sounds(result.sfx_folder)
		
func _input(event) -> void:
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * mouse_sens
		camera.rotation_degrees.x -= event.relative.y * mouse_sens
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -90, 90)

func _physics_process(delta) -> void:
	if Input.is_action_just_released("ui_cancel"):
		get_tree().quit()
		
	camera_pos_normal = global_transform.origin + Vector3.UP * bob_reset	
	
	light_indicator.value = light_level
	sound_emitter.radius = get_surface_texture()
	
	match state:
		WALKING:
			if Input.is_action_pressed("lean"):
				state = LEANING
				return
				
			if Input.is_action_pressed("crouch"):
				state = CROUCHING
				return
			
			if Input.is_action_pressed("sneak"):
				walk(delta, 0.5)
				return
			
			walk(delta)
		
		CROUCHING:
			crouch()
			walk(delta, 0.5)
			
		LEANING:
			lean()
			
func walk(delta, speed_mod : float = 1.0) -> void:
	var move_dir = Vector3()
	move_dir.x = (Input.get_action_strength("right") - Input.get_action_strength("left"))
	move_dir.z = (Input.get_action_strength("back") - Input.get_action_strength("forward"))
	move_dir = move_dir.normalized()	
	move_dir = move_dir.rotated(Vector3.UP, rotation.y)
	
	velocity += speed * move_dir - velocity + Vector3.DOWN * 60 * delta
	velocity = move_and_slide((velocity * speed_mod) + get_floor_velocity(), Vector3.UP, false, 4, PI, false)
	
	handle_player_sound_emission()
	
	if head_bob_enabled and state == WALKING:
		head_bob(delta)
		
	if velocity.length() > 0.1 and not audio_player.playing:
		play_footstep_audio()

var time = 0.0
		
func head_bob(delta : float) -> void:
	if velocity.length() == 0.0:
		camera.global_transform.origin = global_transform.origin + Vector3.UP * bob_reset

	time += delta
	var y_bob = sin(time * (4 * PI)) * velocity.length() * (speed / 1000.0)
	camera.global_transform.origin.y += y_bob

func play_footstep_audio() -> void:
	if footstep_sounds.size() > 0:
		footstep_sounds.shuffle()
		audio_player.stream = footstep_sounds.front()
		audio_player.play()
	
func crouch() -> void:
	var from = collider.shape.height
	var to = collision_normal_height - (collision_normal_height * 0.7)
	collider.shape.height = lerp(from, to, 0.1)
	
	from = camera.global_transform.origin.y
	to = bob_reset - (bob_reset * 0.2)
	camera.global_transform.origin.y = lerp(from, to, 0.1)
	
	if !Input.is_action_pressed("crouch"):
		camera.global_transform.origin = global_transform.origin + Vector3.UP * bob_reset
		state = WALKING
		return

func lean() -> void:
	var axis = (Input.get_action_strength("right") - Input.get_action_strength("left"))
	
	var from = camera.global_transform.origin
	var to = camera_pos_normal + (camera.global_transform.basis.x * 0.2 * axis)
	camera.global_transform.origin = lerp(from, to, 0.1)
	
	from = camera.rotation_degrees.z
	to = -10.0 * axis
	camera.rotation_degrees.z = lerp(from, to, 0.1)
	
	var diff = camera.global_transform.origin - camera_pos_normal
	if axis == 0 and diff.length() <= 0.01:
		state = WALKING
		return

#Replace the placeholder with the full path of the folder where the specific sound files are stored
#Don't include res://
const TEXTURE_SOUND_LIB = {
	"checkerboard" : {
		"amplifier" : 5.0,
		"sfx_folder" : "sfx/footsteps/"
	}
}

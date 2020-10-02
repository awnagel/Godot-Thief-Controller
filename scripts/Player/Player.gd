extends KinematicBody

onready var camera = $Camera
onready var collider = $Collider
onready var light_indicator = $Camera/CanvasLayer/LightIndicator
onready var surface_detector = $SurfaceDetector
onready var sound_emitter = $SoundEmitter
onready var audio_player = $Audio
onready var frob_raycast = $Camera/FrobCast
var clamber = null

enum {
	WALKING,
	LEANING,
	CROUCHING,
	CLAMBERING_RISE,
	CLAMBERING_LEDGE
}

var state = WALKING

export var speed : float = 1.0
export var gravity : float = 60.0
export var jump_force : float = 10.0
export var drag : float = 0.2
export(float, -45.0, -8.0, 1.0) var max_lean = -10.0
export var interact_distance : float = 0.75
export var mouse_sens : float = 0.5
export var lock_mouse : bool = true
export var head_bob_enabled : bool = true

var clamber_destination : Vector3 = Vector3.ZERO

var light_level : float = 0.0

var velocity : Vector3 = Vector3.ZERO

var bob_reset : float = 0.0

var camera_pos_normal : Vector3 = Vector3.ZERO
var collider_normal_radius : float = 0.0
var collider_normal_height : float = 0.0
var collision_normal_offset : float = 0.0

#Replace the placeholder with the full path of the folder where the specific sound files are stored
#Don't include res://
const TEXTURE_SOUND_LIB = {
	"checkerboard" : {
		"amplifier" : 5.0,
		"sfx_folder" : "sfx/footsteps"
	}
}

func _ready() -> void:
	bob_reset = camera.global_transform.origin.y
	
	frob_raycast.cast_to * interact_distance
	
	clamber = clamber_manager.new(self, camera, get_world())
	
	collider_normal_radius = collider.shape.radius
	collider_normal_height = collider.shape.height
	collision_normal_offset = collider.global_transform.origin.y
	
	audio_player.load_footstep_sounds("sfx/breathe", 1)
	audio_player.load_footstep_sounds("sfx/landing", 2)
	
	if lock_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	
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
		audio_player.load_footstep_sounds(result.sfx_folder, 0)
		
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
	
	match state:
		WALKING:
			process_frob_and_drag()
			if Input.is_action_pressed("lean"):
				state = LEANING
				return
				
			if Input.is_action_pressed("crouch"):
				state = CROUCHING
				return
			
			if Input.is_action_pressed("sneak"):
				walk(delta, 0.75)
				return
			
			walk(delta)
		
		CROUCHING:
			process_frob_and_drag()
			crouch()
			walk(delta, 0.75)
			
		LEANING:
			process_frob_and_drag()
			lean()
			
		CLAMBERING_RISE:
			var pos = global_transform.origin
			var target = Vector3(pos.x, clamber_destination.y, pos.z)
			global_transform.origin = lerp(pos, target, 0.1)
			crouch()
			
			var from = camera.rotation_degrees.x
			var to = pos.angle_to(target)
			camera.rotation_degrees.x = lerp(from, to, 0.1)
			
			var d = pos - target
			if d.length() < 0.1:
				state = CLAMBERING_LEDGE
				return
		
		CLAMBERING_LEDGE:
			audio_player.play_clamber_sound(false)
			global_transform.origin = lerp(global_transform.origin, clamber_destination, 0.1)
			crouch()
			
			var from = camera.rotation_degrees.x
			var to = global_transform.origin.angle_to(clamber_destination)
			camera.rotation_degrees.x = lerp(from, to, 0.1)
			
			var d = global_transform.origin - clamber_destination
			if d.length() < 0.1:
				global_transform.origin = clamber_destination
				state = CROUCHING
				return
		
var jumping : bool = false
			
#Needs some refining
func walk(delta, speed_mod : float = 1.0) -> void:
	var move_dir = Vector3()
	move_dir.x = (Input.get_action_strength("right") - Input.get_action_strength("left"))
	move_dir.z = (Input.get_action_strength("back") - Input.get_action_strength("forward"))
	move_dir = move_dir.normalized()	
	move_dir = move_dir.rotated(Vector3.UP, rotation.y)
	
	var y_velo = velocity.y
	
	velocity += speed * move_dir - velocity * Vector3(drag, 0, drag) + Vector3.DOWN * gravity * delta
	
	velocity = move_and_slide((velocity * speed_mod) + get_floor_velocity(), Vector3.UP, true, 4, PI, false)
	
	var grounded = is_on_floor()
	
	if !grounded and y_velo < velocity.y:
		velocity.y = y_velo
		
	if grounded:
		velocity.y = -0.01
		
		if jumping:
			audio_player.play_land_sound()
		
		jumping = false
	if grounded and Input.is_action_just_pressed("clamber") and state == WALKING:
		# Check for clamber
		var c = clamber.attempt_clamber()
		if c != Vector3.ZERO:
			clamber_destination = c
			state = CLAMBERING_RISE
			audio_player.play_clamber_sound(true)
			return
			
		# If no clamber, jump
		velocity.y = jump_force
		jumping = true
		return
		
	handle_player_sound_emission()
	
	if head_bob_enabled and grounded and state == WALKING:
		head_bob(delta)
		
	if velocity.length() > 0.1 and grounded and not audio_player.playing and is_on_floor():
		audio_player.play_footstep_sound()

var time : float = 0.0
		
func head_bob(delta : float) -> void:
	if velocity.length() == 0.0:
		camera.global_transform.origin = global_transform.origin + Vector3.UP * bob_reset

	time += delta
	var y_bob = sin(time * (4 * PI)) * velocity.length() * (speed / 1000.0)
	var z_bob = sin(time * (2 * PI)) * velocity.length() * 0.2
	camera.global_transform.origin.y += y_bob
	camera.rotation_degrees.z = z_bob
	
var drag_object : RigidBody = null
var click_timer : float = 0.0
var throw_wait_time : float = 400	
	
func process_frob_and_drag():
	if Input.is_action_just_pressed("mouse_left") and click_timer == 0.0 and drag_object != null:
		click_timer = OS.get_ticks_msec()
		
	if Input.is_action_pressed("mouse_left"):
		if click_timer + throw_wait_time < OS.get_ticks_msec() and click_timer != 0.0:
			click_timer = 0.0
			throw(camera, drag_object)
			drag_object = null
		
	if Input.is_action_just_released("mouse_left"):	
		if drag_object != null:
			if click_timer + throw_wait_time > OS.get_ticks_msec() and click_timer != 0.0:
				drag_object = null
				click_timer = 0.0
		elif frob_raycast.is_colliding():
			var c = frob_raycast.get_collider()
			if drag_object == null and c is RigidBody and c.scale < (Vector3.ONE * 5):
				drag_object = c
				drag_object.linear_velocity = Vector3.ZERO
			elif c.has_method("on_frob"):
				c.on_frob()
				
	if Input.is_action_just_pressed("mouse_right") and drag_object != null:
		drag_object.rotation_degrees.y += 45
		drag_object.rotation_degrees.x = 90
				
	if drag_object != null:
		drag()
		
		if camera.global_transform.origin.distance_to(drag_object.global_transform.origin) > interact_distance + 0.35:
			drag_object = null
	
func drag(damping : float = 0.5, s2ms : int = 15) -> void:
	var dest = frob_raycast.global_transform.origin - frob_raycast.global_transform.basis.z.normalized() * interact_distance
	var d1 = (dest - drag_object.global_transform.origin)
	drag_object.angular_velocity = Vector3.ZERO
	
	var v1 = velocity * damping + drag_object.linear_velocity * damping
	var v2 = (d1 * s2ms) * (1.0 - damping) / drag_object.mass
	
	drag_object.linear_velocity = v1 + v2
	
func throw(camera, drag, throw_force : float = 10.0) -> void:
	drag.apply_central_impulse(-camera.global_transform.basis.z * throw_force)
	
func crouch() -> void:
	var from = collider.shape.height
	var to = collider_normal_height * 0.5
	collider.shape.height = lerp(from, to, 0.1)
	from = collider.shape.radius
	to = collider_normal_radius * 0.5
	collider.shape.radius = lerp(from, to, 0.1)
	collider.rotation_degrees.x = 0
	
	from = camera.global_transform.origin
	to = camera_pos_normal + (Vector3.DOWN * bob_reset * 0.4)
	camera.global_transform.origin = lerp(from, to, 0.1)
	
	if !Input.is_action_pressed("crouch") and state == CROUCHING:
		var pos = global_transform.origin
		var space = get_world().direct_space_state
		if !space.intersect_ray(pos, pos + Vector3.UP * bob_reset + Vector3.UP * 0.2, [self]):
			state = WALKING
			camera.global_transform.origin = pos + Vector3.UP * bob_reset
			collider.shape.height = collider_normal_height
			collider.shape.radius = collider_normal_radius
			collider.rotation_degrees.x = 90
			return
		
func lean() -> void:
	var axis = (Input.get_action_strength("right") - Input.get_action_strength("left"))
	
	var from = camera.global_transform.origin
	var to = camera_pos_normal + (camera.global_transform.basis.x * 0.2 * axis)
	camera.global_transform.origin = lerp(from, to, 0.1)
	
	from = camera.rotation_degrees.z
	to = max_lean * axis
	camera.rotation_degrees.z = lerp(from, to, 0.1)
	
	var diff = camera.global_transform.origin - camera_pos_normal
	if axis == 0 and diff.length() <= 0.01:
		state = WALKING
		return		

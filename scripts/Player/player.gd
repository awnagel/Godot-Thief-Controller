class_name Player
extends KinematicBody

enum State {
	STATE_WALKING,
	STATE_LEANING,
	STATE_CROUCHING,
	STATE_CLAMBERING_RISE,
	STATE_CLAMBERING_LEDGE,
	STATE_CLAMBERING_VENT,
}

# Add texture and the path of the folder with the corresponding sound files
# Don't include res://
const TEXTURE_SOUND_LIB = {
	"checkerboard" : {
		"amplifier" : 5.0,
		"sfx_folder" : "sfx/footsteps"
	}
}

export var speed : float = 0.5
export var gravity : float = 40.0
export var jump_force : float = 9.0
export var move_drag : float = 0.2
export(float, -45.0, -8.0, 1.0) var max_lean = -10.0
export var interact_distance : float = 0.75
export var mouse_sens : float = 0.5
export var lock_mouse : bool = true
export var head_bob_enabled : bool = true

var state = State.STATE_WALKING
var clamber_destination : Vector3 = Vector3.ZERO
var light_level : float = 0.0
var velocity : Vector3 = Vector3.ZERO
var drag_object : RigidBody = null

var _clamber_m = null
var _bob_reset : float = 0.0
var _camera_pos_normal : Vector3 = Vector3.ZERO
var _collider_normal_radius : float = 0.0
var _collider_normal_height : float = 0.0
var _collision_normal_offset : float = 0.0
var _click_timer : float = 0.0
var _throw_wait_time : float = 400	
var _jumping : bool = false
var _bob_time : float = 0.0

onready var _camera : Camera = $Camera
onready var _collider : CollisionShape = $Collider
onready var _light_indicator : ProgressBar = $Camera/CanvasLayer/LightIndicator
onready var _surface_detector : RayCast = $SurfaceDetector
onready var _sound_emitter : PlayerSoundEmitter = $SoundEmitter
onready var _audio_player : PlayerAudio = $Audio
onready var _frob_raycast : RayCast = $Camera/FrobCast

func _ready() -> void:
	_bob_reset = _camera.global_transform.origin.y
	
	_frob_raycast.cast_to *= interact_distance
	
	_clamber_m = ClamberManager.new(self, _camera, get_world())
	
	_collider_normal_radius = _collider.shape.radius
	_collider_normal_height = _collider.shape.height
	_collision_normal_offset = _collider.global_transform.origin.y
	
	_audio_player.load_footstep_sounds("sfx/breathe", 1)
	_audio_player.load_footstep_sounds("sfx/landing", 2)
	
	if lock_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event) -> void:
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * mouse_sens
		_camera.rotation_degrees.x -= event.relative.y * mouse_sens
		_camera.rotation_degrees.x = clamp(_camera.rotation_degrees.x, -90, 90)


func _physics_process(delta) -> void:
	#if Input.is_action_just_released("ui_cancel"):
	#	get_tree().quit()
		
	_camera_pos_normal = global_transform.origin + Vector3.UP * _bob_reset	
	
	_light_indicator.value = light_level
	
	match state:
		State.STATE_WALKING:
			_process_frob_and_drag()
			if Input.is_action_pressed("lean"):
				state = State.STATE_LEANING
				return
				
			if Input.is_action_pressed("crouch"):
				state = State.STATE_CROUCHING
				return
			
			if Input.is_action_pressed("sneak"):
				_walk(delta, 0.75)
				return
			
			_walk(delta)
		
		State.STATE_CROUCHING:
			_process_frob_and_drag()
			_crouch()
			_walk(delta, 0.75)
			
		State.STATE_LEANING:
			_process_frob_and_drag()
			_lean()
			
		State.STATE_CLAMBERING_RISE:
			var pos = global_transform.origin
			var target = Vector3(pos.x, clamber_destination.y, pos.z)
			global_transform.origin = lerp(pos, target, 0.1)
			_crouch()
			
			var from = _camera.rotation_degrees.x
			var to = pos.angle_to(target)
			_camera.rotation_degrees.x = lerp(from, to, 0.1)
			
			var d = pos - target
			if d.length() < 0.1:
				state = State.STATE_CLAMBERING_LEDGE
				return
		
		State.STATE_CLAMBERING_LEDGE:
			_audio_player.play_clamber_sound(false)
			var pos = global_transform.origin
			global_transform.origin = lerp(pos, clamber_destination, 0.1)
			_crouch()
			
			var from = _camera.rotation_degrees.x
			var to = global_transform.origin.angle_to(clamber_destination)
			_camera.rotation_degrees.x = lerp(from, to, 0.1)
			
			var d = global_transform.origin - clamber_destination
			if d.length() < 0.1:
				global_transform.origin = clamber_destination
				state = State.STATE_CROUCHING
				return
	
func _get_surface_texture() -> Dictionary:
	if _surface_detector.get_collider():
		var mesh = null
		for node in _surface_detector.get_collider().get_children():
			if node is MeshInstance:
				if node.mesh != null:
					mesh = node
		
		if !mesh:
			return {}
		
		if mesh.get_surface_material(0) != null:
				var tex = mesh.get_surface_material(0).albedo_texture
				var path = tex.resource_path.split("/")
				var n = path[path.size() - 1].split(".")[0]
				if TEXTURE_SOUND_LIB.has(n):
					return TEXTURE_SOUND_LIB[n]
					
	return {}
		
		
func _handle_player_sound_emission() -> void:
	var result = _get_surface_texture()
	
	if result.size() == 0:
		return
	
	_sound_emitter.radius = result["amplifier"]
	
	if result.sfx_folder != "":
		_audio_player.load_footstep_sounds(result.sfx_folder, 0)


#TODO: Add in flight clambering
func _walk(delta, speed_mod : float = 1.0) -> void:
	var move_dir = Vector3()
	move_dir.x = (Input.get_action_strength("right") - Input.get_action_strength("left"))
	move_dir.z = (Input.get_action_strength("back") - Input.get_action_strength("forward"))
	move_dir = move_dir.normalized()	
	move_dir = move_dir.rotated(Vector3.UP, rotation.y)
	
	var y_velo = velocity.y
	
	var v1 = speed * move_dir - velocity * Vector3(move_drag, 0, move_drag)
	var v2 = Vector3.DOWN * gravity * delta
	
	velocity += v1 + v2
	
	var grounded = is_on_floor()
	
	velocity = move_and_slide((velocity * speed_mod) + get_floor_velocity(),
			Vector3.UP, true, 4, PI, false)
	
	if is_on_floor() and !grounded:
		_audio_player.play_land_sound()

	grounded = is_on_floor()
	
	if !grounded and y_velo < velocity.y:
		velocity.y = y_velo
		
	if grounded:
		velocity.y = -0.01
		
		_jumping = false
	if grounded and Input.is_action_just_pressed("clamber"):
		if state != State.STATE_WALKING or _jumping:
			return
		
		# Check for clamber
		var c = _clamber_m.attempt_clamber()
		if c != Vector3.ZERO:
			clamber_destination = c
			state = State.STATE_CLAMBERING_RISE
			_audio_player.play_clamber_sound(true)
			return
			
		# If no clamber, jump
		velocity.y = jump_force
		_jumping = true
		return
		
	_handle_player_sound_emission()
	
	if head_bob_enabled and grounded and state == State.STATE_WALKING:
		_head_bob(delta)
		
	if velocity.length() > 0.1 and grounded and not _audio_player.playing:
		_audio_player.play_footstep_sound()

		
func _head_bob(delta : float) -> void:
	if velocity.length() == 0.0:
		var br = Vector3(0, _bob_reset, 0)
		_camera.global_transform.origin = global_transform.origin + br

	_bob_time += delta
	var y_bob = sin(_bob_time * (4 * PI)) * velocity.length() * (speed / 1000.0)
	var z_bob = sin(_bob_time * (2 * PI)) * velocity.length() * 0.2
	_camera.global_transform.origin.y += y_bob
	_camera.rotation_degrees.z = z_bob
	
	
# There seems to be an issue
# where if the plane the player is on is too thin
# the player intersects with the floor.	
func _crouch() -> void:
	var from = _collider.shape.height
	var to = _collider_normal_height * 0.5
	_collider.shape.height = lerp(from, to, 0.1)
	from = _collider.shape.radius
	to = _collider_normal_radius * 0.5
	_collider.shape.radius = lerp(from, to, 0.1)
	_collider.rotation_degrees.x = 0
	
	from = _camera.global_transform.origin
	to = _camera_pos_normal + (Vector3.DOWN * _bob_reset * 0.4)
	_camera.global_transform.origin = lerp(from, to, 0.1)
	
	if !Input.is_action_pressed("crouch") and state == State.STATE_CROUCHING:
		var pos = global_transform.origin
		var space = get_world().direct_space_state
		
		var r_up = space.intersect_ray(pos, 
				pos + Vector3.UP * _bob_reset + Vector3.UP * 0.2, [self])
		
		if !r_up:
			state = State.STATE_WALKING
			_camera.global_transform.origin = pos + Vector3.UP * _bob_reset
			_collider.shape.height = _collider_normal_height
			_collider.shape.radius = _collider_normal_radius
			_collider.rotation_degrees.x = 90
			return
		
		
func _lean() -> void:
	var axis = (Input.get_action_strength("right") - Input.get_action_strength("left"))
	
	var from = _camera.global_transform.origin
	var to = _camera_pos_normal + (_camera.global_transform.basis.x * 0.2 * axis)
	_camera.global_transform.origin = lerp(from, to, 0.1)
	
	from = _camera.rotation_degrees.z
	to = max_lean * axis
	_camera.rotation_degrees.z = lerp(from, to, 0.1)
	
	var diff = _camera.global_transform.origin - _camera_pos_normal
	if axis == 0 and diff.length() <= 0.01:
		state = State.STATE_WALKING
		return		

	
func _process_frob_and_drag():
	if Input.is_action_just_pressed("mouse_left") and _click_timer == 0.0 and drag_object != null:
		_click_timer = OS.get_ticks_msec()
		
	if Input.is_action_pressed("mouse_left"):
		if _click_timer + _throw_wait_time < OS.get_ticks_msec():
			if _click_timer == 0.0:
				return
			
			_click_timer = 0.0
			_throw()
			drag_object = null
		
	if Input.is_action_just_released("mouse_left"):	
		if drag_object != null:
			if _click_timer + _throw_wait_time > OS.get_ticks_msec():
				if _click_timer == 0.0:
					return
				
				drag_object = null
				_click_timer = 0.0
		elif _frob_raycast.is_colliding():
			var c = _frob_raycast.get_collider()
			if drag_object == null and c is RigidBody:
				if c.scale > (Vector3.ONE * 5):
					return
				
				drag_object = c
				drag_object.linear_velocity = Vector3.ZERO
			elif c.has_method("on_frob"):
				c.on_frob()
				
	if Input.is_action_just_pressed("mouse_right") and drag_object != null:
		drag_object.rotation_degrees.y += 45
		drag_object.rotation_degrees.x = 90
				
	if drag_object != null:
		_drag()
		
		var d = _camera.global_transform.origin.distance_to(drag_object.global_transform.origin)
		if  d > interact_distance + 0.35:
			drag_object = null
	
	
func _drag(damping : float = 0.5, s2ms : int = 15) -> void:
	var d = _frob_raycast.global_transform.basis.z.normalized()
	var dest = _frob_raycast.global_transform.origin - d * interact_distance
	var d1 = (dest - drag_object.global_transform.origin)
	drag_object.angular_velocity = Vector3.ZERO
	
	var v1 = velocity * damping + drag_object.linear_velocity * damping
	var v2 = (d1 * s2ms) * (1.0 - damping) / drag_object.mass
	
	drag_object.linear_velocity = v1 + v2
	
	
func _throw(throw_force : float = 10.0) -> void:
	var d = -_camera.global_transform.basis.z.normalized()
	drag_object.apply_central_impulse(d * throw_force)

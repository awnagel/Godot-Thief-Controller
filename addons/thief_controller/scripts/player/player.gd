extends ThiefCharacterController
class_name ThiefPlayer

enum State {
	STATE_WALKING,
	STATE_LEANING,
	STATE_CROUCHING,
	STATE_CLAMBERING_RISE,
	STATE_CLAMBERING_LEDGE,
	STATE_CLAMBERING_VENT,
	STATE_NOCLIP,
}

export var interact_distance : float = 1.5
export(float, 0.1, 1.0) var mouse_sens : float = 0.5
export(float, -45.0, -8.0, 1.0) var max_lean = -10.0
export(float, 0.1, 1.0) var crouch_rate = 0.5
export(Resource) var settings
export(Resource) var texture_sound_library
export(Resource) var audio_library

var state = State.STATE_WALKING setget _set_state
var light_level : float = 0.0
var drag_object : RigidBody = null
var clamber_destination : Vector3 = Vector3.ZERO

var _click_timer : float = 0.0
var _throw_wait_time : float = 400

var _collider_normal_radius : float = 0.0
var _collider_normal_height : float = 0.0
var _normal_collision_layer_and_mask : int = 1

var _clamber : ThiefClamberManager

onready var _frob_raycast : RayCast = $Camera/FrobCast
onready var _collider : CollisionShape = $Collider
onready var _surface_detector : RayCast = $SurfaceDetector
onready var _sound_emitter : ThiefSoundEmitter = $SoundEmitter
onready var _audio_player : ThiefPlayerAudio = $Audio
onready var _light_indicator : ProgressBar = $Camera/CanvasLayer/PlayerUI/LightIndicator

func _ready():
	# Check for null resources
	if texture_sound_library == null or not texture_sound_library is ThiefSoundLibrary:
		texture_sound_library = ThiefSoundLibrary.new()
		print("Warning: No sound library given, using empty!")
	
	if audio_library == null or not audio_library is ThiefAudioLibrary:
		audio_library = ThiefAudioLibrary.new()
		print("Warning: No audio library given, using empty!")

	if settings == null or not settings is ThiefSettings:
		settings = ThiefSettings.new()
		print("Warning: No settings given, using default!")

	_camera = get_node("Camera")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_frob_raycast.cast_to = Vector3.FORWARD * interact_distance

	_camera.set_crosshair_state("normal")

	_audio_player.load_sounds(audio_library)

	_collider_normal_radius = _collider.shape.radius
	_collider_normal_height = _collider.shape.height

	_normal_collision_layer_and_mask = collision_layer
	
	_clamber = ThiefClamberManager.new(self, _camera, ThiefClamberSettings.new())

	var _c0 = connect("landed", self, "_land")


func _set_state(new_value):
	match new_value:
		State.STATE_WALKING:
			pass
		State.STATE_LEANING:
			if !settings.leaning_enabled:
				return
		State.STATE_CROUCHING:
			if !settings.crouching_enabled:
				return
		State.STATE_NOCLIP:
			if !settings.noclip_enabled:
				return
		State.STATE_CLAMBERING_LEDGE:
			if !settings.clambering_enabled:
				return
		State.STATE_CLAMBERING_RISE:
			if !settings.clambering_enabled:
				return
		State.STATE_CLAMBERING_VENT:
			if !settings.clambering_enabled:
				return

	state = new_value


func _input(event):
	if event is InputEventMouseMotion:

		if (state == State.STATE_CLAMBERING_LEDGE 
			or state == State.STATE_CLAMBERING_RISE 
			or state == State.STATE_CLAMBERING_VENT):
			return
		
		var m = 1.0
		
		if _camera.state == _camera.CameraState.STATE_ZOOM:
			m = _camera.zoom_camera_sens_mod
		
		_camera.rotation_degrees.y -= event.relative.x * mouse_sens * m
		
		_camera.rotation_degrees.x -= event.relative.y * mouse_sens * m
		_camera.rotation_degrees.x = clamp(_camera.rotation_degrees.x, -90, 90)

		_camera._camera_rotation_reset = _camera.rotation_degrees


func _process(_delta):
	_light_indicator.value = light_level

	match state:
		State.STATE_WALKING:
			speed_modifier = 1.0

			_process_frob_and_drag()

			if Input.is_action_pressed("lean"):
				_set_state(State.STATE_LEANING)
				return
				
			if Input.is_action_pressed("crouch"):
				_set_state(State.STATE_CROUCHING)
				return
			
			if Input.is_action_just_pressed("noclip"):
				_set_state(State.STATE_NOCLIP)
				return

			if Input.is_action_pressed("zoom"):
				_camera.state = _camera.CameraState.STATE_ZOOM
			else:
				_camera.state = _camera.CameraState.STATE_NORMAL
			
			_walk()

		State.STATE_LEANING:
			_process_frob_and_drag()
			_lean()

		State.STATE_CROUCHING:
			speed_modifier = 0.67

			if Input.is_action_pressed("zoom"):
				_camera.state = _camera.CameraState.STATE_ZOOM
			else:
				_camera.state = _camera.CameraState.STATE_NORMAL

			_process_frob_and_drag()
			_crouch()
			_walk()

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
				_set_state(State.STATE_CLAMBERING_LEDGE)
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
				_set_state(State.STATE_CROUCHING)
				return


		State.STATE_NOCLIP:
			if Input.is_action_just_pressed("noclip"):
				_set_state(State.STATE_WALKING)
				return

			collision_layer = 2
			collision_mask = 2
			_noclip_walk()


func _get_surface_texture() -> ThiefSoundPair:
	if _surface_detector.get_collider():
		var mesh = null
		for node in _surface_detector.get_collider().get_children():
			if node is MeshInstance:
				if node.mesh != null:
					mesh = node
		
		if !mesh:
			return null
		
		if mesh.get_surface_material(0) != null:
				var tex = mesh.get_surface_material(0).albedo_texture
				
				if !tex:
					return null
				
				var path = tex.resource_path.split("/")
				var n = path[path.size() - 1].split(".")[0]
				if texture_sound_library.has(n):
					return texture_sound_library.get(n)
					
	return null
		
		
func _handle_player_sound_emission() -> void:
	var result = _get_surface_texture()
	
	if result == null:
		return
	
	_sound_emitter.radius = result.amplifier
	
	if result.sfx_folder != "":
		_audio_player.load_sound_folder(result.sfx_folder, ThiefPlayerAudio.Types.TYPE_FOOTSTEP)


func get_forward() -> Vector3:
	var transform = Transform()
	transform = transform.rotated(Vector3.UP, deg2rad(_camera.rotation_degrees.y))
	return -transform.basis.z.normalized()


func _noclip_walk() -> void:
	_wishdir.x = (Input.get_action_strength("right") - Input.get_action_strength("left"))
	_wishdir.z = (Input.get_action_strength("back") - Input.get_action_strength("forward"))


func _walk():
	collision_layer = _normal_collision_layer_and_mask
	collision_mask = _normal_collision_layer_and_mask

	_wishdir.x = (Input.get_action_strength("right") - Input.get_action_strength("left"))
	_wishdir.z = (Input.get_action_strength("back") - Input.get_action_strength("forward"))

	if is_on_floor and Input.is_action_just_pressed("clamber"):
		if state != State.STATE_WALKING or _jumping:
			return

		# Check for clamber
		var c = _clamber.attempt_clamber()
		if c != Vector3.ZERO:
			clamber_destination = c
			_set_state(State.STATE_CLAMBERING_RISE)
			_audio_player.play_clamber_sound(true)
			return

		# No clamber, jump
		_jumping = true
		return
	
	_handle_player_sound_emission()

	if linear_velocity.length() > 0.1 and is_on_floor and not _audio_player.playing:
		_audio_player.play_footstep_sound()


func _lean() -> void:
	var axis = (Input.get_action_strength("right") - Input.get_action_strength("left"))
	
	var from = _camera.translation
	var to = Vector3.UP * camera_height + (_camera.transform.basis.x * 0.2 * axis)
	_camera.translation = lerp(from, to, 0.1)
	
	from = _camera.rotation_degrees.z
	to = max_lean * axis
	_camera.rotation_degrees.z = lerp(from, to, 0.1)
	
	var diff = _camera.translation - Vector3.UP * camera_height
	if axis == 0 and diff.length() <= 0.01:
		_set_state(State.STATE_WALKING)
		return

# There seems to be an issue
# where if the plane the player is on is too thin
# the player intersects with the floor.	
func _crouch() -> void:
	crouch_rate = clamp(crouch_rate, 0.11, 1.0)

	var from = _collider.shape.height
	var to = _collider_normal_height * crouch_rate
	_collider.shape.height = lerp(from, to, 0.1)
	
	from = _collider.shape.radius
	to = _collider_normal_radius * crouch_rate
	_collider.shape.radius = lerp(from, to, 0.1)
	
	from = Vector3.UP * camera_height
	to = Vector3.UP * crouch_rate
	_camera.translation = Vector3.UP * camera_height * (crouch_rate - 0.1)
	
	if !Input.is_action_pressed("crouch") and state == State.STATE_CROUCHING:
		var pos = global_transform.origin
		var space = get_world().direct_space_state
		
		var r_up = space.intersect_ray(pos, 
				_camera.global_transform.origin + Vector3.UP * 0.8, [self])
		
		if !r_up:
			_set_state(State.STATE_WALKING)
			_camera.translation = Vector3.UP * camera_height
			_collider.shape.height = _collider_normal_height
			_collider.shape.radius = _collider_normal_radius
			return


func _land():
	if state == State.STATE_CROUCHING or _camera.stress > 0.1:
		return

	_audio_player.play_land_sound()
	_camera.add_stress(0.1)


func _process_frob_and_drag():
	if (Input.is_action_just_pressed("mouse_left") 
		and _click_timer == 0.0 
		and drag_object != null):
		_click_timer = OS.get_ticks_msec()
		
	if Input.is_action_pressed("mouse_left"):
		if _click_timer + _throw_wait_time < OS.get_ticks_msec():
			if _click_timer == 0.0:
				return
			
			_camera.set_crosshair_state("normal")
			_click_timer = 0.0
			_throw()
			drag_object = null
	
	if _frob_raycast.is_colliding():
		var c = _frob_raycast.get_collider()
		if drag_object == null and c is RigidBody:
			if c.scale > (Vector3.ONE * 5):
				return
				
			var w = get_world().direct_space_state
			var r = w.intersect_ray(c.global_transform.origin,
					c.global_transform.origin + Vector3.UP * 0.5)
						
			if r and r.collider == self:
				return

			_camera.set_crosshair_state("interact")
				
			if Input.is_action_just_released("mouse_left"):
				_camera.set_crosshair_state("dragging")
				drag_object = c
				drag_object.linear_velocity = Vector3.ZERO
		elif c.has_method("on_frob"):
			#_camera.set_crosshair_state("interact")
			
			if Input.is_action_just_released("mouse_left"):
				_camera.set_crosshair_state("normal")
				c.on_frob()	
		
	if Input.is_action_just_released("mouse_left"):
		if drag_object != null:
			if _click_timer + _throw_wait_time > OS.get_ticks_msec():
				if _click_timer == 0.0:
					return
				
				_camera.set_crosshair_state("normal")
				drag_object = null
				_click_timer = 0.0
				
	if Input.is_action_just_pressed("mouse_right") and drag_object != null:
		drag_object.rotation_degrees.y += 45
		drag_object.rotation_degrees.x = 90
				
	if drag_object:
		_drag()
		
		var d = _camera.global_transform.origin.distance_to(drag_object.global_transform.origin)
		if  d > interact_distance + 0.35:
			drag_object = null
	
	if !drag_object and not _frob_raycast.is_colliding():
		_camera.set_crosshair_state("normal")
	

func _drag(damping : float = 0.5, s2ms : int = 15) -> void:
	var d = _frob_raycast.global_transform.basis.z.normalized()
	var dest = _frob_raycast.global_transform.origin - d * interact_distance
	var d1 = (dest - drag_object.global_transform.origin)
	drag_object.angular_velocity = Vector3.ZERO
	
	var v1 = linear_velocity * damping + drag_object.linear_velocity * damping
	var v2 = (d1 * s2ms) * (1.0 - damping) / drag_object.mass
	
	drag_object.linear_velocity = v1 + v2
	
	
func _throw(throw_force : float = 10.0) -> void:
	var d = -_camera.global_transform.basis.z.normalized()
	drag_object.apply_central_impulse(d * throw_force)
	_camera.add_stress(0.2)

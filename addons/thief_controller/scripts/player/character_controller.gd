extends RigidBody
class_name ThiefCharacterController

signal landed()

export var custom_friction : float = 6.0
export var accelerate : float = 64.0
export var max_velocity : float = 96.0
export var gravity : float = -40.0
export var jump_force : float = 1024.0
export var slide_along_walls : bool = false
export var head_bob_enabled : bool = true

export var camera_height : float = 0.5

export var camera_bob_time : float = 4.0
export var camera_bob_strength : float = 0.01

var is_on_floor := false
var is_on_floor_prev := false
var speed_modifier = 1.0

var _camera : Camera

var _wishdir := Vector3.ZERO
var _bob_cycle := 0.0
var _jumping := false

func _ready():
	custom_integrator = true
	mode = RigidBody.MODE_CHARACTER
	_camera = get_viewport().get_camera()

# Camera handling

func calc_view_bob(push_vel: Vector3, delta: float) -> float:
	var l = push_vel
	l.y = 0
	var speed = l.length()
	
	if speed < 0.005:
		return 0.0
	
	_bob_cycle += delta
	
	return sin(_bob_cycle * PI * camera_bob_time) * speed * camera_bob_strength

# Movement handling

func accelerate(accel_dir: Vector3, prev_vel: Vector3, accelerate: float, max_vel: float, state: PhysicsDirectBodyState):
	var proj_vel = prev_vel.dot(accel_dir)
	var accel_vel = accelerate * state.step
	
	if (proj_vel + accel_vel > max_vel):
		accel_vel = max_vel - proj_vel	

	return prev_vel + accel_dir * accel_vel
	

func move_ground(accel_dir: Vector3, prev_vel: Vector3, state: PhysicsDirectBodyState):
	var speed = prev_vel.length()
	if speed != 0:
		var drop = speed * custom_friction * state.step
		prev_vel *= max(speed - drop, 0) / speed
	
	return accelerate(accel_dir, prev_vel, accelerate, max_velocity, state)


func slide_wall(velocity: Vector3, state: PhysicsDirectBodyState):
	var space = state.get_space_state()
	for vector in [global_transform.basis.x * 0.75, Vector3.ZERO, -global_transform.basis.x * 0.75]:
		var start = global_transform.origin + vector
		var result = space.intersect_ray(start, start + velocity.normalized(), [self])
		if !result.empty():
			var ortho : Vector3 = result.normal.cross(velocity.normalized())
			var new_move : Vector3 = result.normal.cross(ortho)
			new_move = new_move.normalized()
			
			if new_move.dot(velocity) < 0:
				new_move *= -1.0
				
			if new_move.dot(velocity) > 0.5:
				new_move *= velocity.length()
				velocity = new_move
			
			break
	
	return velocity


func floor_check(radius: float, ray_count: int, depth: float, state: PhysicsDirectBodyState):
	var space = state.get_space_state()
	var total = Vector3.ZERO
	var origin = state.transform.origin
	
	for i in ray_count:
		var angle = 2.0 * PI * i / ray_count
		var pos = origin + Vector3(cos(angle), 0, sin(angle)) * radius
		
		var ray = space.intersect_ray(pos, pos + Vector3.DOWN * depth, [self])
		if !ray.empty():
			total += ray.position
	
	return total / ray_count


func _integrate_forces(state):
	# Ground movement
	# From: https://adrianb.io/2015/02/14/bunnyhop.html
	var target_vel = move_ground(_wishdir.rotated(Vector3.UP, _camera.rotation.y), linear_velocity, state)

	# Slide along walls
	# From: https://etodd.io/2015/04/03/poor-mans-character-controller/
	if slide_along_walls:
		target_vel = slide_wall(target_vel, state)
	
	# Ground check
	# From: https://www.patreon.com/posts/21343562
	var ground = floor_check(0.5, 4, 0.8, state)

	if ground != Vector3.ZERO and _jumping:
		target_vel.y = jump_force * state.step
		_jumping = false
	elif ground != Vector3.ZERO and !_jumping:
		if !is_on_floor:
			emit_signal("landed")

		if head_bob_enabled:
			_camera.translation.y = camera_height + calc_view_bob(target_vel, state.step)
		target_vel.y = ground.y * state.step
	elif ground == Vector3.ZERO:
		target_vel.y += gravity * state.step

	is_on_floor = ground != Vector3.ZERO or is_on_floor_prev	
	is_on_floor_prev = ground != Vector3.ZERO

	linear_velocity = target_vel * speed_modifier


extends Object

#Having clamber as a seperate class let's any object use the clamber function, it just needs a clamber manager
class_name clamber_manager

var camera : Camera = null
var world : World = null
var user : KinematicBody = null

func _init(User : KinematicBody, Current_Camera : Camera, User_World : World):
	camera = Current_Camera
	user = User
	world = User_World

func get_world():
	return world

func attempt_clamber() -> Vector3:
	if camera.rotation_degrees.x < 20.0:
		var v = test_clamber_vent()
		if v != Vector3.ZERO:
			return v
		v = test_clamber_ledge()
		if v != Vector3.ZERO:
			return v
	elif camera.rotation_degrees.x > 20.0:
		var v = test_clamber_ledge()
		if v != Vector3.ZERO:
			return v
		v = test_clamber_vent()
		if v != Vector3.ZERO:
			return v
	return Vector3.ZERO
		
func test_clamber_ledge() -> Vector3:
	var space = get_world().direct_space_state
	var pos = user.global_transform.origin
	var d1 = pos + Vector3.UP * 1.25
	var d2 = d1 -user.global_transform.basis.z.normalized()
	var d3 = d2 + Vector3.DOWN * 16
	
	if not space.intersect_ray(pos, d1):
		for i in range(5):
			if not space.intersect_ray(d1, d2 - user.global_transform.basis.z.normalized() * i):
				for j in range(5):
					d2 = d1 + -user.global_transform.basis.z.normalized() * (j + 1)
					var r = space.intersect_ray(d2, d3)
					if r:
						var ground_check = space.intersect_ray(pos, pos + Vector3.DOWN * 2)
				
						if ground_check.collider == r.collider:
							return Vector3.ZERO
				
						var offset = check_clamber_box(r.position + Vector3.UP * 0.175)
						if offset == -Vector3.ONE:
							return Vector3.ZERO
				
						if r.position.y < pos.y:
							return Vector3.ZERO
				
						#Start clamber animation
						return r.position + offset
						return Vector3.ZERO		
				
	return Vector3.ZERO
	
func test_clamber_vent() -> Vector3:
	var space = get_world().direct_space_state
	var pos = user.global_transform.origin
	var d1 = camera.global_transform.origin - camera.global_transform.basis.z.normalized() * 0.4
	var d2 = d1 + Vector3.DOWN * 6
	
	if not space.intersect_ray(pos, d1, [self]):
		for i in range(5):
			var r = space.intersect_ray(d1 - camera.global_transform.basis.z.normalized() * 0.4 * i, d2, [self])
			if r:
				var ground_check = space.intersect_ray(pos, pos + Vector3.DOWN * 2)
			
				if ground_check and ground_check.collider == r.collider:
					return Vector3.ZERO
				
				var offset = check_clamber_box(r.position + Vector3.UP * 0.175)
				if offset == -Vector3.ONE:
					return Vector3.ZERO
				
				if r.position.y < pos.y:
					return Vector3.ZERO
				
				return r.position + offset
				
	return Vector3.ZERO
	
#Nudging may need some refining
func check_clamber_box(pos : Vector3, box_size : float = 0.15) -> Vector3:
	var state = get_world().direct_space_state
	var shape = BoxShape.new()
	shape.extents = Vector3.ONE * box_size
	
	var params = PhysicsShapeQueryParameters.new()
	params.set_shape(shape)
	params.transform.origin = pos
	var result = state.intersect_shape(params)
	
	for i in range(result.size() - 1):
		if result[i].collider == self:
			result.remove(i)	
	
	if result.size() == 1 and result[0].collider.global_transform.origin.y < pos.y:
		return Vector3.ZERO
	
	if result.size() == 0:
		return Vector3.ZERO
	
	if !check_gap(pos + Vector3.FORWARD * 0.15):
		return -Vector3.ONE

	if !check_gap(pos + Vector3.BACK * 0.15):
		return -Vector3.ONE
		
	if !check_gap(pos):
		return -Vector3.ONE
		
	var offset = Vector3.ZERO
	var checkPos = Vector3.ZERO
	
	var dir = -camera.global_transform.basis.z.normalized()
	dir.y = 0
		
	for i in range(4):
		var j = (i + 1) * 0.4
		checkPos = pos + dir * j
		params.transform.origin = checkPos
		var r = state.intersect_shape(params)
		if r.size() == 0:
			offset = dir * j
			break
	
	if checkPos != Vector3.ZERO:
		if state.intersect_ray(checkPos, checkPos + Vector3.DOWN * 2):
			return offset
	
	return -Vector3.ONE
	
func check_gap(pos : Vector3) -> bool:
	var space = get_world().direct_space_state
	
	var c = 0
	
	for i in range(4):
		var r = i * 90
		var v = Vector3.UP.rotated(Vector3.FORWARD, deg2rad(r))
		var result = space.intersect_ray(pos, pos + v, [self])
		if result and (result.position - pos).length() < 0.2:
			c += 1
			
	if c >= 2:
		return false
	
	return true

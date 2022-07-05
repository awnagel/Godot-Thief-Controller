extends Object
class_name ThiefClamberManager

# Having clamber as a seperate class let's any object use the clamber function,
# it just needs a clamber manager.

var _clamber_forward = 1.5
var _clamber_down = 6.0
var _clamber_up = 4.0

var _camera : Camera = null
var _world : World = null
var _user : Spatial = null

func _init(user: Spatial, camera: Camera, settings: ThiefClamberSettings):
	_user = user
	_camera = camera
	_world = user.get_world()

	_clamber_forward = settings.forward_distance
	_clamber_down = settings.down_distance
	_clamber_up = settings.up_distance


func _get_world():
	return _world


func attempt_clamber() -> Vector3:
	if _camera.rotation_degrees.x < 20.0:
		var v = _test_clamber_vent()
		if v != Vector3.ZERO:
			return v
		v = _test_clamber_ledge()
		if v != Vector3.ZERO:
			return v
	elif _camera.rotation_degrees.x > 20.0:
		var v = _test_clamber_ledge()
		if v != Vector3.ZERO:
			return v
		v = _test_clamber_vent()
		if v != Vector3.ZERO:
			return v
	return Vector3.ZERO
	
		
func _test_clamber_ledge() -> Vector3:
	var user_forward = _user.get_forward() * _clamber_forward
	var space = _get_world().direct_space_state
	var pos = _user.global_transform.origin
	var d1 = pos + Vector3.UP * _clamber_up
	var d2 = d1 + user_forward
	var d3 = d2 + Vector3.DOWN * 16
	
	if not space.intersect_ray(pos, d1):
		for i in range(5):
			if not space.intersect_ray(d1, d2 + user_forward * i):
				for j in range(5):
					d2 = d1 + user_forward * (j + 1)
					d3 = d2 + Vector3.DOWN * _clamber_down
					var r = space.intersect_ray(d2, d3)
					if r:
						var ground_check = space.intersect_ray(pos, 
								pos + Vector3.DOWN, [_user])
								
						if ground_check.empty():
							return Vector3.ZERO
				
						if ground_check.collider == r.collider:
							return Vector3.ZERO
				
						var offset = _check_clamber_box(r.position + Vector3.UP * 0.175)
						if offset == -Vector3.ONE:
							return Vector3.ZERO
				
						if r.position.y < pos.y:
							return Vector3.ZERO
				
						return r.position + offset
				
	return Vector3.ZERO
	
	
func _test_clamber_vent() -> Vector3:
	var cam_forward = -_camera.global_transform.basis.z.normalized() * _clamber_forward 
	var space = _get_world().direct_space_state
	var pos = _user.global_transform.origin
	var d1 = _camera.global_transform.origin + cam_forward
	var d2 = d1 + Vector3.DOWN * 16
	
	if not space.intersect_ray(pos, d1, [self]):
		for i in range(5):
			var r = space.intersect_ray(d1 + cam_forward * i, d2, [self])
			if r:
				var ground_check = space.intersect_ray(pos,
						pos + Vector3.DOWN * 2)
			
				if ground_check and ground_check.collider == r.collider:
					return Vector3.ZERO
				
				var offset = _check_clamber_box(r.position + Vector3.UP * 0.175)
				if offset == -Vector3.ONE:
					return Vector3.ZERO
				
				if r.position.y < pos.y:
					return Vector3.ZERO
				
				return r.position + offset
				
	return Vector3.ZERO
	
	
# Nudging may need some refining
func _check_clamber_box(pos : Vector3, box_size : float = 0.15) -> Vector3:
	var state = _get_world().direct_space_state
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
	
	if !_check_gap(pos + Vector3.FORWARD * 0.15):
		return -Vector3.ONE

	if !_check_gap(pos + Vector3.BACK * 0.15):
		return -Vector3.ONE
		
	if !_check_gap(pos):
		return -Vector3.ONE
		
	var offset = Vector3.ZERO
	var checkPos = Vector3.ZERO
	
	var dir = -_camera.global_transform.basis.z.normalized()
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
	
func _check_gap(pos : Vector3) -> bool:
	var space = _get_world().direct_space_state
	
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

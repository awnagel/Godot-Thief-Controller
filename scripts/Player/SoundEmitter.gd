extends Area

var radius = 1.0

func _process(_delta):
	if not $CollisionShape.shape is SphereShape:
		$CollisionShape.shape = SphereShape.new()
	
	for body in get_overlapping_bodies():
		if body.has_method("listen"):
			body.listen(get_parent())
	
	if $CollisionShape.shape:
		$CollisionShape.shape.radius = radius

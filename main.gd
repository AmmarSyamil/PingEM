extends Node3D

@onready var camera = $Camera3D
@onready var ball = $Ball
@onready var paddle = $Paddle
#@onready var 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#print("mambo")
	
	if Input.is_action_just_pressed("ballz"):
		#ball.translate(Vector3(0, 1, 0))
		ball.get_node("RigidBody3D").global_position = Vector3(0,1,0)
		ball.get_node("RigidBody3D").linear_velocity = Vector3(0, 0, 0)
		print("go back")
		
	
	#if Input.is_action_just_pressed("ballz"):
	var mouse_pos = get_viewport().get_mouse_position()
		
	# Ray 
	var start_ray = camera.project_ray_origin(mouse_pos)
	var dir_ray = camera.project_ray_normal(mouse_pos)
	var len_ray = 1000
		
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start_ray, start_ray + dir_ray *len_ray)
	#query.collide_with_areas = false
	#query.collide_with_bodies = true
	query.collision_mask = 1 << 1
	var result = space_state.intersect_ray(query)
	
	#print("sybau")
	if result.size() > 0:
		var col = result["collider"]
		#print("Hit:", col.name)
		if col is StaticBody3D:
			#print("H/it at:", result.collider.name)
			var hit_at = result.position
			var offset_pos = hit_at - dir_ray * 0.1
			paddle.global_position = offset_pos
		
	pass

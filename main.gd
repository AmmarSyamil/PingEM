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
		ball.get_node("RigidBody3D").global_position = Vector3(-1,1,0)
		ball.get_node("RigidBody3D").linear_velocity = Vector3(0, 0, 0)
		print("go back")
	
	#pass
	

func _physics_process(delta: float) -> void:
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
			
			# Going back from the ray line a bit so its not coliding with the table
			var offset_pos = hit_at - dir_ray * 0.3
			
			# Going to the designated plce
			var dir = (offset_pos - paddle.global_position).normalized()
			#paddle.apply_central_impulse(dir * 5)
			paddle.velocity = dir * 5.0
			paddle.move_and_slide()
			
			if paddle.global_position.distance_to(offset_pos) < 0.1:
				paddle.velocity = Vector3.ZERO
				
			# Should be like this but velocuty
			#paddle.global_position = offset_pos
			
			
			# Draw ray line
			DebugDraw3D.draw_line(start_ray, hit_at, Color.RED)
			
			# Change the paddle dir/andle so that the front part is allign with the ray 
			paddle.look_at(hit_at, Vector3.UP)
			paddle.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
			#paddle.linear_velocity = Vector3(0, 0, 0)
			
		# Detect at rest
		#print(paddle.linear_velocity)
		print(paddle.velocity)
		if paddle.velocity == Vector3(0,0,0):
			print("sybau")
		else:
			print(paddle.velocity)
		#if paddle.linear_velocity == Vector3(0,0,0):
			#print("chill")
		#else:
			#print(paddle.linear_velocity)

		
	pass

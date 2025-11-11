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
	var ball_top = ball.get_node("Ball").global_transform.origin
	var up_dir = ball.get_node("Ball").global_transform.basis.y.normalized()
	var rotation_veloccity = ball.get_node("Ball").angular_velocity
	
	DebugDraw3D.draw_line(ball_top, ball_top + up_dir*0.5, Color.AQUAMARINE, 0.0)
	
	print(rotation_veloccity)
	
	if Input.is_action_just_pressed("ballz"):
		#ball.translate(Vector3(0, 1, 0))
		ball.get_node("Ball").global_position = Vector3(-1,1,0)
		ball.get_node("Ball").linear_velocity = Vector3(0, 0, 0)
		#rotation_veloccity = Vector3(0,0,0)
		ball.get_node("Ball").angular_velocity = Vector3(0,0,0)
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
	
	#Add debug line for the paddle pointing at
	var forward = paddle.global_transform.basis.y.normalized() * -1
	var origin = paddle.global_position
	DebugDraw3D.draw_line(origin, origin + forward * 0.5, Color.AQUAMARINE)
	
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
			
			paddle.velocity = dir * (pow(paddle.global_position.distance_to(offset_pos),1.1661) * 45.7)
			paddle.move_and_slide()
			#print(paddle.global_position.distance_to(offset_pos))
			
			#if paddle.global_position.distance_to(offset_pos) < 0.3:
				#paddle.velocity = Vector3.ZERO
			#else:
				#pa/ss
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
		#print(paddle.velocity)
		if paddle.velocity.length() > 0.1 and paddle.velocity.length() <0.3:
			#print("sybau")
			DebugDraw3D.draw_sphere(paddle.global_position, 0.01, Color.RED, 4)
			
			
			#make a blob
			#var pos_hit = ball.get_node("Ball").global_position
			#var dir_hit = ball.get_node("Ball").global_rotation
			#DebugDraw3D.draw_line(paddle.global_position, pos_hit + dir_hit * 0.5, Color.AQUAMARINE, 4)
			#var dir_hit = ball
			
			
		else:
			pass
			#print(paddle.velocity)
			
			

		# Get collision of paddle
		var paddle_collison = paddle.get_slide_collision_count()
		for i in range(paddle_collison):
			var coll = paddle.get_slide_collision(i)
			var collider = coll.get_collider()
			
			if collider.name == "Ball":
				print("hit ball", paddle.velocity)
				DebugDraw3D.draw_sphere(paddle.global_position, 0.01, Color.BLUE, 4)
				
				# See tracjectory
				var pos_hit = ball.get_node("Ball").global_position
				#var dir_hit = -ball.get_node("Ball").global_transform.basis.z.normalized()
				var dir_hit = ball.get_node("Ball").linear_velocity
				DebugDraw3D.draw_line(pos_hit, pos_hit + dir_hit * 0.1, Color.AQUAMARINE, 4)
			
			else:
				pass
				#print(collider.name)
				
			# Increase the force fo the paddl to yeet the ball further
			if collider is RigidBody3D:
				#print("hit sybau")
				var push_dir = coll.get_normal() * -1
				var force = 10
				
				collider.apply_central_impulse(push_dir * paddle.velocity.length() )


		
	pass

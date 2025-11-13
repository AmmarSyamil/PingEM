extends Node3D

@onready var camera = $Camera3D
@onready var ball = $Ball
@onready var paddle = $Paddle
#@onready var 
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#ball.get_node("Ball").body_entered.connect(_ball_coll)
	paddle.get_node("Collision detect").connect("body_entered", Callable(self, "_ball_coll"))
	pass 
	# Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#print("mambo")
	var ball_top = ball.get_node("Ball").global_transform.origin
	var up_dir = ball.get_node("Ball").global_transform.basis.y.normalized()
	var rotation_veloccity = ball.get_node("Ball").angular_velocity
	
	# Draw line at top of the ball to see the top part of the ball
	DebugDraw3D.draw_line(ball_top, ball_top + up_dir*0.5, Color.AQUAMARINE, 0.0)
	
	#print(rotation_veloccity)
	
	if Input.is_action_just_pressed("ballz"):
		#ball.translate(Vector3(0, 1, 0))
		ball.get_node("Ball").global_position = Vector3(-1,1,0)
		ball.get_node("Ball").linear_velocity = Vector3(0, 0, 0)
		#rotation_veloccity = Vector3(0,0,0)
		ball.get_node("Ball").angular_velocity = Vector3(0,0,0)
		print("go back")
	
	#pass
	

func _physics_process(delta: float) -> void:
	air_movement()
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
	# Basic movement using ray and go back a bit
	if result.size() > 0:
		
		var col = result["collider"]

		# For basic movement of the paddle
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
			
			# Draw ray line,=, main line of sight
			DebugDraw3D.draw_line(start_ray, hit_at, Color.RED)
			
			# Change the paddle dir/andle so that the front part is allign with the ray 
			paddle.look_at(hit_at, Vector3.UP)
			paddle.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
			#paddle.linear_velocity = Vector3(0, 0, 0)
	
	
	
	if paddle.velocity.length() > 0.1 and paddle.velocity.length() <0.3:
		DebugDraw3D.draw_sphere(paddle.global_position, 0.01, Color.RED, 4)
	else:
		pass
			#print(paddle.velocity)
			
	
	# Collision via slide
	var paddle_collison = paddle.get_slide_collision_count()
	
	for i in range(paddle_collison):
		var coll = paddle.get_slide_collision(i)
		var collider = coll.get_collider()
		
		if collider.name == "Ball":
			#print("hit ball", paddle.velocity)
			DebugDraw3D.draw_sphere(paddle.global_position, 0.01, Color.BLUE, 4)
		else:
			pass
			
		### Increase the force fo the paddl to yeet the ball further
		#if collider is RigidBody3D:
			##print("hit sybau")
			#var push_dir = coll.get_normal() * -1
			#var force = 10
				#
			#collider.apply_central_impulse(push_dir * paddle.velocity.length() )
				
	# Makesure it isnt too fast
	for i in ["x","y","z"]:
		var data = ball.get_node("Ball").linear_velocity[i]
		if data >5:
			print(i, " to fast")
			ball.get_node("Ball").linear_velocity[i] = 5
			pass
	
	pass
		
	
	
# Function to detect any colision of the paddle i think
func _ball_coll(body):
	var pos = ball.get_node("Ball").global_position
	var vel = ball.get_node("Ball").linear_velocity
	
	#var v_normal = normal * vel.dot(normal)
	
	ball.get_node("Ball").contact_monitor = true
	ball.get_node("Ball").max_contacts_reported = 4
	print(body, "here")

	if body == ball.get_node("Ball"):
		DebugDraw3D.draw_sphere(ball.get_node("Ball").global_position, 0.01, Color.CYAN, 4)
		
		# Find the approximaate direction of the ball after colision with the paddle
		DebugDraw3D.draw_line(pos, pos + vel * 0.1, Color.SALMON, 2)
		print("line aproximate runned")
		
		# run the handle ball collision function for more precise coliding stuff
		var normal = -paddle.transform.basis.z.normalized()
		handle_ball_coll(ball, paddle, normal)
		
		
		
		
	else:
		print("tes")
	
	pass
	
	
# Function to handle all coollision whatsoever, so the physict will al be in hear like hte bouncy part you know it
func handle_ball_coll(ball, paddle, normal):
	
	var ball_v = ball.get_node("Ball").linear_velocity
	var paddle_v = paddle.velocity
	
	# v = normal + tangent 
	var normal_v = normal * ball_v.dot(normal)
	var tangent_v = ball_v - normal_v
	
	var restitution = 1
	var friction = 0.8
	var update_v = (-normal_v * restitution) + (tangent_v * friction)
	
	update_v += paddle_v * 0.5
	
	var max_speed = 10
	if update_v.length() > max_speed:
		update_v = update_v.normalized() * max_speed
		
	ball.get_node("Ball").linear_velocity = update_v
	
	# spin effect
	
	var tangent_speed = tangent_v.length()
	var spin_dir = tangent_v.normalized()
	if tangent_v.length() > 0.0001:
		var tangent_dir = tangent_v.normalized()
		var spin_axis = normal.cross(tangent_dir)
		var spin_factor = 1
		
		if spin_axis.length() > 0.0001:
			spin_axis = spin_axis.normalized()
			var ball_radius = ball.get_node("Ball").get_node("CSGSphere3D").radius
			var updated_angular_v = spin_axis * (tangent_speed / ball_radius) * spin_factor
			ball.get_node("Ball").angular_velocity = updated_angular_v
		
	
	
	
	pass
	
func air_movement():
	
	var C_d = 1 # drag coefisciesnt
	var k_m = 1	 # magnus coeficient
	var v = ball.get_node("Ball").linear_velocity
	var F_drag = -C_d * v.length() * v
	var F_magnus = k_m * ball.get_node("Ball").angular_velocity.cross(ball.get_node("Ball").linear_velocity)
	var updated = (F_drag + F_magnus)
	
	ball.get_node("Ball").apply_central_force(updated)
	
	pass

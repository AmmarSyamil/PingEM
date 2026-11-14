extends Node3D
## PingEM: sampled-swing paddle controller and deterministic ball shots.
## Drop-in replacement for the repository's res://main.gd (Godot 4.4+).
## Keeps the existing scene and its "Collision detect" Area3D.

@export_group("Paddle movement")
@export_range(1.0, 30.0, 0.5) var paddle_max_speed: float = 14.0
@export_range(0.02, 0.20, 0.005) var swing_sample_delay: float = 0.06

@export_group("Ball shots")
@export_range(0.0, 5.0, 0.05) var min_swing_speed: float = 0.35
@export_range(0.1, 4.0, 0.1) var swing_to_ball_speed: float = 1.6
@export_range(0.1, 10.0, 0.1) var min_ball_speed: float = 2.0
@export_range(1.0, 25.0, 0.5) var max_ball_speed: float = 10.0
@export_range(0.0, 1.0, 0.05) var minimum_outward_component: float = 0.20
@export_range(0.02, 0.5, 0.01) var hit_cooldown: float = 0.12

@export_group("Optional flight physics")
@export_range(0.0, 1.0, 0.005) var drag_coefficient: float = 0.0
@export_range(0.0, 1.0, 0.005) var magnus_coefficient: float = 0.0
@export_range(0.0, 1.0, 0.05) var spin_transfer: float = 0.0

@export_group("Debug")
@export var show_swing_debug: bool = true

@onready var camera: Camera3D = $Camera3D
@onready var paddle: CharacterBody3D = $Paddle
@onready var paddle_area: Area3D = $"Paddle/Collision detect"
@onready var ball_body: RigidBody3D = $Ball/Ball

var _clock: float = 0.0
var _last_hit_time: float = -10.0
var _history_positions: Array[Vector3] = []
var _history_times: Array[float] = []
var _last_shot_origin: Vector3 = Vector3.ZERO
var _last_shot_direction: Vector3 = Vector3.ZERO
var _last_shot_time: float = -10.0


func _ready() -> void:
	# CharacterBody3D's physical collider previously interfered with the shot.
	# The Area3D is independent and can continue to detect the RigidBody3D ball.
	paddle.collision_layer = 0
	paddle.collision_mask = 0
	paddle.get_node("CollisionShape3D").set_deferred("disabled", true)

	paddle_area.monitoring = true
	paddle_area.collision_mask = 1  # Ball is on the default physics layer.
	paddle_area.body_entered.connect(_on_paddle_area_body_entered)

	_remember_paddle_position()


func _physics_process(delta: float) -> void:
	_clock += delta

	if Input.is_action_just_pressed("ballz"):
		ball_body.linear_velocity = Vector3.ZERO
		ball_body.angular_velocity = Vector3.ZERO
		ball_body.global_position = Vector3(-1.0, 1.0, 0.0)
		ball_body.sleeping = false

	_move_paddle_from_mouse(delta)
	_remember_paddle_position()
	_apply_air_forces()

	if show_swing_debug:
		_draw_debug_vectors()


func _move_paddle_from_mouse(delta: float) -> void:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ray_origin, ray_origin + ray_direction * 1000.0
	)
	query.collision_mask = 1 << 1  # Same table/aiming layer as the original.
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		paddle.velocity = Vector3.ZERO
		return

	var aim_point: Vector3 = hit["position"]
	var target_position: Vector3 = aim_point - ray_direction * 0.30
	var previous_position: Vector3 = paddle.global_position

	# Direct mouse-follow motion: the ball cannot physically push the paddle.
	# Keep motion speed limited so one large mouse jump does not produce a huge shot.
	paddle.global_position = previous_position.move_toward(
		target_position, paddle_max_speed * delta
	)
	paddle.velocity = (paddle.global_position - previous_position) / maxf(delta, 0.0001)

	# Preserve the orientation behavior used by the original PingEM paddle.
	if paddle.global_position.distance_squared_to(aim_point) > 0.000001:
		paddle.look_at(aim_point, Vector3.UP)
		paddle.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))


func _remember_paddle_position() -> void:
	_history_times.append(_clock)
	_history_positions.append(paddle.global_position)

	# Keep enough history for the configured sampling interval.
	var oldest_allowed: float = _clock - swing_sample_delay - 0.10
	while _history_times.size() > 2 and _history_times[1] < oldest_allowed:
		_history_times.remove_at(0)
		_history_positions.remove_at(0)


func _past_paddle_position() -> Vector3:
	if _history_times.is_empty():
		return paddle.global_position

	var target_time: float = _clock - swing_sample_delay
	if target_time <= _history_times[0]:
		return _history_positions[0]

	for i in range(1, _history_times.size()):
		if _history_times[i] >= target_time:
			var start_time: float = _history_times[i - 1]
			var end_time: float = _history_times[i]
			var alpha: float = clampf(
				(target_time - start_time) / maxf(end_time - start_time, 0.0001),
				0.0, 1.0
			)
			return _history_positions[i - 1].lerp(_history_positions[i], alpha)

	return _history_positions.back()


func _on_paddle_area_body_entered(body: Node3D) -> void:
	if body != ball_body:
		return
	if _clock - _last_hit_time < hit_cooldown:
		return
	_last_hit_time = _clock

	var prior_position: Vector3 = _past_paddle_position()
	var contact_position: Vector3 = paddle.global_position
	var swing_displacement: Vector3 = contact_position - prior_position
	var swing_velocity: Vector3 = swing_displacement / maxf(swing_sample_delay, 0.001)
	var paddle_front: Vector3 = -paddle.global_transform.basis.z.normalized()

	var outgoing_direction: Vector3
	var outgoing_speed: float

	if swing_velocity.length() >= min_swing_speed:
		# The direction is based on a REAL displacement between two times,
		# not on the physics engine's collision reaction.
		outgoing_direction = swing_velocity.normalized()

		# The hit must exit the paddle's front face. Preserve the lateral aim,
		# while keeping at least a little velocity away from the paddle.
		if outgoing_direction.dot(paddle_front) < minimum_outward_component:
			outgoing_direction = (
				outgoing_direction.slide(paddle_front)
				+ paddle_front * minimum_outward_component
			).normalized()

		outgoing_speed = clampf(
			min_ball_speed + swing_velocity.length() * swing_to_ball_speed,
			min_ball_speed, max_ball_speed
		)
	else:
		# Still let a stationary paddle block/reflect an incoming ball.
		var incoming_velocity: Vector3 = ball_body.linear_velocity
		outgoing_direction = incoming_velocity.bounce(paddle_front).normalized()
		if outgoing_direction.dot(paddle_front) <= 0.0:
			outgoing_direction = paddle_front
		outgoing_speed = clampf(
			incoming_velocity.length(), min_ball_speed, max_ball_speed
		)

	ball_body.linear_velocity = outgoing_direction * outgoing_speed
	ball_body.sleeping = false

	# Spin is OFF by default, so the straight-line shot is easy to verify.
	# Enable the optional controls later to reintroduce table-tennis spin.
	ball_body.angular_velocity = Vector3.ZERO
	if spin_transfer > 0.0:
		var tangential_swing: Vector3 = swing_velocity.slide(paddle_front)
		if tangential_swing.length_squared() > 0.0001:
			var spin_axis: Vector3 = paddle_front.cross(tangential_swing).normalized()
			ball_body.angular_velocity = spin_axis * minf(
				tangential_swing.length() * spin_transfer / 0.05156,
				30.0
			)

	_last_shot_time = _clock
	_last_shot_origin = ball_body.global_position
	_last_shot_direction = outgoing_direction

	if show_swing_debug:
		DebugDraw3D.draw_sphere(prior_position, 0.022, Color.YELLOW, 0.4)
		DebugDraw3D.draw_sphere(contact_position, 0.022, Color.CYAN, 0.4)
		DebugDraw3D.draw_line(prior_position, contact_position, Color.CYAN, 0.4)
		DebugDraw3D.draw_line(
			_last_shot_origin,
			_last_shot_origin + outgoing_direction * 0.8,
			Color.ORANGE, 0.6
		)

	print(
		"PingEM hit | swing=", snappedf(swing_velocity.length(), 0.01),
		" m/s | ball=", snappedf(outgoing_speed, 0.01),
		" m/s | direction=", outgoing_direction
	)


func _apply_air_forces() -> void:
	if drag_coefficient <= 0.0 and magnus_coefficient <= 0.0:
		return

	var velocity: Vector3 = ball_body.linear_velocity
	var air_force: Vector3 = -drag_coefficient * velocity.length() * velocity
	air_force += magnus_coefficient * ball_body.angular_velocity.cross(velocity)
	ball_body.apply_central_force(air_force)


func _draw_debug_vectors() -> void:
	var past_position: Vector3 = _past_paddle_position()
	var current_position: Vector3 = paddle.global_position
	DebugDraw3D.draw_sphere(past_position, 0.012, Color.YELLOW)
	DebugDraw3D.draw_sphere(current_position, 0.012, Color.CYAN)
	DebugDraw3D.draw_line(past_position, current_position, Color.CYAN)

	if _clock - _last_shot_time < 0.6:
		DebugDraw3D.draw_line(
			_last_shot_origin,
			_last_shot_origin + _last_shot_direction * 0.8,
			Color.ORANGE
		)

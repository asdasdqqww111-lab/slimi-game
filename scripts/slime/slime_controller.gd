class_name SlimeController
extends CharacterBody3D
## المتحكم الفيزيائي والسلوكي لشخصية سلايمي ثلاثية الأبعاد.

signal slime_interacted(interaction_type: StringName, world_pos: Vector3)

@export var max_room_radius: float = 2.25
@export var hop_vertical_speed: float = 4.35
@export var hop_horizontal_speed: float = 2.35
@export var turn_speed: float = 7.5

var deformer: SlimeDeformer
var face_rig: SlimeFaceRig
var mood_system: PersonalityMoodSystem
var ai_brain: Node
var body_mesh_instance: MeshInstance3D

var look_target_world := Vector3(0.0, 1.1, 3.2)
var is_being_dragged: bool = false

var _was_on_floor: bool = true
var _pre_land_vy: float = 0.0
var _gravity: float = 13.5
var _pet_sound_cooldown: float = 0.0
var _spin_velocity_y: float = 0.0


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 13.5))
	body_mesh_instance = get_node_or_null("VisualRoot/SlimeBodyMesh") as MeshInstance3D
	var face_node := get_node_or_null("VisualRoot/FaceAnchor") as SlimeFaceRig
	var crown_node := get_node_or_null("VisualRoot/DropletCrown") as Node3D

	face_rig = face_node
	deformer = get_node_or_null("SlimeDeformer") as SlimeDeformer
	mood_system = get_node_or_null("PersonalityMoodSystem") as PersonalityMoodSystem
	ai_brain = get_node_or_null("AutonomousBehaviorAI")

	if deformer != null:
		deformer.setup(body_mesh_instance, face_rig, crown_node)

	if mood_system != null:
		mood_system.mood_changed.connect(_on_mood_changed)
		_sync_mood_visuals(mood_system.current_mood)

	if QualityManager != null:
		QualityManager.quality_changed.connect(_on_quality_changed)
		_on_quality_changed(QualityManager.current_preset, QualityManager.get_current_profile())


func _physics_process(delta: float) -> void:
	if _pet_sound_cooldown > 0.0:
		_pet_sound_cooldown = maxf(0.0, _pet_sound_cooldown - delta)

	if not is_on_floor():
		_pre_land_vy = velocity.y
		velocity.y -= _gravity * delta
	else:
		if not _was_on_floor and _pre_land_vy < -0.8:
			# انضغاط مرن لطيف عند الهبوط على الأرض
			var impact: float = clampf(-_pre_land_vy * 0.62, 0.6, 3.4)
			if deformer != null:
				deformer.add_vertical_impulse(-impact)
			AudioManager.play_sfx(&"squish_poke", -0.14, -6.0)
		velocity.x = move_toward(velocity.x, 0.0, 9.5 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 9.5 * delta)

	_was_on_floor = is_on_floor()
	move_and_slide()
	_clamp_within_room()
	_update_orientation_and_gaze(delta)


func hop_toward(target_world_pos: Vector3, power_scale: float = 1.0) -> bool:
	if not is_on_floor() or is_being_dragged:
		return false
	if mood_system != null and mood_system.is_sleeping:
		return false

	var flat_delta := Vector3(
		target_world_pos.x - global_position.x,
		0.0,
		target_world_pos.z - global_position.z
	)
	var dist: float = flat_delta.length()
	var dir: Vector3 = flat_delta.normalized() if dist > 0.05 else Vector3.ZERO
	var bounce_trait: float = mood_system.personality.bounciness if (mood_system != null and mood_system.personality != null) else 1.0

	var horiz_speed: float = minf(dist * 2.4, hop_horizontal_speed) * clampf(power_scale, 0.45, 1.45)
	velocity.x = dir.x * horiz_speed
	velocity.z = dir.z * horiz_speed
	velocity.y = hop_vertical_speed * clampf(power_scale, 0.55, 1.35) * bounce_trait

	look_target_world = Vector3(target_world_pos.x, global_position.y + 0.55, target_world_pos.z)

	if deformer != null:
		deformer.add_vertical_impulse(2.85 * power_scale)
		var local_dir: Vector3 = global_transform.basis.inverse() * (-dir)
		deformer.add_jiggle_impulse(local_dir * 1.4)

	AudioManager.play_sfx(&"boing_hop", 0.0, -2.5)
	return true


func perform_happy_bounce() -> void:
	if mood_system != null and mood_system.is_sleeping:
		mood_system.set_sleeping(false)
	if is_on_floor():
		velocity.y = hop_vertical_speed * 1.12
		_spin_velocity_y = TAU * 1.35
	if deformer != null:
		deformer.add_vertical_impulse(3.2)
	if face_rig != null:
		face_rig.set_expression(SlimeFaceRig.FaceExpression.PLAYFUL)
	AudioManager.play_voice(&"happy_chirp")


func on_poked(world_hit_pos: Vector3, _world_normal: Vector3) -> void:
	var local_hit: Vector3 = to_local(world_hit_pos)
	if deformer != null:
		deformer.trigger_poke(local_hit, 0.92)

	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var result: Dictionary = {}
	if mood_system != null:
		result = mood_system.register_poke(now_sec)

	if bool(result.get("became_dizzy", false)):
		AudioManager.play_voice(&"dizzy_wobble")
	else:
		AudioManager.play_sfx(&"squish_poke")
		if int(result.get("rapid_count", 1)) >= 2 and is_on_floor():
			velocity.y = hop_vertical_speed * 0.62

	if ai_brain != null and ai_brain.has_method("notify_player_interaction"):
		ai_brain.call("notify_player_interaction", 3.5)

	AndroidPlatformManager.trigger_haptic(14)
	slime_interacted.emit(&"poke", world_hit_pos)


func on_petted(world_hit_pos: Vector3, stroke_intensity: float = 1.0) -> void:
	var local_hit: Vector3 = to_local(world_hit_pos)
	if deformer != null:
		deformer.add_jiggle_impulse(Vector3(local_hit.x * 0.6, 0.0, local_hit.z * 0.6) * stroke_intensity)
		deformer.add_vertical_impulse(-0.35 * stroke_intensity)

	if mood_system != null:
		mood_system.register_pet(clampf(stroke_intensity, 0.25, 1.25))

	if _pet_sound_cooldown <= 0.0:
		_pet_sound_cooldown = 0.62
		AudioManager.play_voice(&"purr_pet", 0.0, -2.0)

	if ai_brain != null and ai_brain.has_method("notify_player_interaction"):
		ai_brain.call("notify_player_interaction", 4.0)

	slime_interacted.emit(&"pet", world_hit_pos)


func on_pull_drag(world_drag_delta: Vector3) -> void:
	is_being_dragged = true
	var local_delta: Vector3 = global_transform.basis.inverse() * world_drag_delta
	if deformer != null:
		deformer.set_pull_offset(local_delta)
	if face_rig != null and mood_system != null and not mood_system.is_sleeping:
		face_rig.set_expression(SlimeFaceRig.FaceExpression.SURPRISED)
	if ai_brain != null and ai_brain.has_method("notify_player_interaction"):
		ai_brain.call("notify_player_interaction", 3.0)


func on_pull_release() -> void:
	if not is_being_dragged:
		return
	is_being_dragged = false
	if deformer != null:
		deformer.release_pull()
	if mood_system != null:
		_sync_mood_visuals(mood_system.current_mood)
	AudioManager.play_sfx(&"boing_hop", 0.12, -3.0)
	AndroidPlatformManager.trigger_haptic(18)


func feed_treat(treat_world_pos: Vector3) -> void:
	look_target_world = treat_world_pos
	hop_toward(treat_world_pos, 0.80)
	if mood_system != null:
		mood_system.register_feed()
	if deformer != null:
		deformer.add_vertical_impulse(2.1)
	AudioManager.play_voice(&"eat_nom")
	AndroidPlatformManager.trigger_haptic(20)
	slime_interacted.emit(&"feed", treat_world_pos)


func play_together() -> void:
	if mood_system != null:
		mood_system.register_play()
	perform_happy_bounce()
	AndroidPlatformManager.trigger_haptic(22)
	slime_interacted.emit(&"play", global_position)


func toggle_nap() -> void:
	if mood_system == null:
		return
	var next_sleep: bool = not mood_system.is_sleeping
	mood_system.set_sleeping(next_sleep)
	if deformer != null:
		deformer.is_resting_flat = next_sleep
	if next_sleep:
		AudioManager.play_voice(&"sleepy_yawn")
	else:
		AudioManager.play_voice(&"happy_chirp")
		if deformer != null:
			deformer.add_vertical_impulse(2.0)


func call_to_front(front_spot: Vector3, camera_pos: Vector3) -> void:
	if mood_system != null and mood_system.is_sleeping:
		mood_system.set_sleeping(false)
		if deformer != null:
			deformer.is_resting_flat = false
	hop_toward(front_spot, 1.05)
	look_target_world = camera_pos
	AudioManager.play_voice(&"curious_coo")


func _update_orientation_and_gaze(delta: float) -> void:
	if absf(_spin_velocity_y) > 0.05:
		rotation.y += _spin_velocity_y * delta
		_spin_velocity_y = lerpf(_spin_velocity_y, 0.0, minf(1.0, delta * 5.0))
	else:
		var flat_to_target := Vector3(
			look_target_world.x - global_position.x,
			0.0,
			look_target_world.z - global_position.z
		)
		if flat_to_target.length_squared() > 0.02:
			var desired_yaw: float = atan2(flat_to_target.x, flat_to_target.z)
			rotation.y = lerp_angle(rotation.y, desired_yaw, minf(1.0, delta * turn_speed))

	if face_rig != null:
		var local_look: Vector3 = to_local(look_target_world).normalized()
		face_rig.set_look_direction_local(local_look)


func _clamp_within_room() -> void:
	var horiz := Vector2(global_position.x, global_position.z)
	if horiz.length() > max_room_radius:
		var clamped: Vector2 = horiz.normalized() * max_room_radius
		global_position.x = clamped.x
		global_position.z = clamped.y
		velocity.x *= -0.35
		velocity.z *= -0.35


func _on_mood_changed(new_mood: int, _mood_key: String) -> void:
	_sync_mood_visuals(new_mood)


func _sync_mood_visuals(mood_val: int) -> void:
	if face_rig != null:
		face_rig.set_expression(mood_val)
	if deformer != null and mood_system != null:
		deformer.is_resting_flat = mood_system.is_sleeping
		deformer.set_mood_tint(mood_system.get_mood_tint())


func _on_quality_changed(_preset: int, profile: Dictionary) -> void:
	if body_mesh_instance != null and body_mesh_instance.mesh is SphereMesh:
		var sm := body_mesh_instance.mesh as SphereMesh
		sm.radial_segments = int(profile.get("slime_radial_segments", 36))
		sm.rings = int(profile.get("slime_rings", 24))
	if deformer != null:
		deformer.set_shader_detail(int(profile.get("shader_detail", 1)))

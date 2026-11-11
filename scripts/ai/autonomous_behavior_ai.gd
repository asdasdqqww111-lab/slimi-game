class_name AutonomousBehaviorAI
extends Node
## الذكاء الاصطناعي للسلوك المستقل لسلايمي (Utility-Weighted FSM):
## يجعل سلايمي يتجول، يراقب الكاميرا، يستكشف أثاث الغرفة، يلعب، يطلب الانتباه، أو يأخذ غفوة تلقائياً.

signal state_changed(new_state: int, state_name: StringName)

enum State {
	IDLE_OBSERVE = 0,
	WANDER_HOP = 1,
	CURIOUS_INSPECT = 2,
	PLAY_BOUNCE = 3,
	SEEK_ATTENTION = 4,
	REST_NAP = 5,
	REACTING = 6,
}

const STATE_NAMES: Dictionary = {
	State.IDLE_OBSERVE: &"idle_observe",
	State.WANDER_HOP: &"wander_hop",
	State.CURIOUS_INSPECT: &"curious_inspect",
	State.PLAY_BOUNCE: &"play_bounce",
	State.SEEK_ATTENTION: &"seek_attention",
	State.REST_NAP: &"rest_nap",
	State.REACTING: &"reacting",
}

@export var autonomous_enabled: bool = true

var controller: SlimeController
var mood_system: PersonalityMoodSystem
var room_ref: Node3D
var camera_ref: Camera3D

var current_state: int = State.IDLE_OBSERVE
var time_since_player_touch: float = 0.0

var _decision_timer: float = 2.6
var _reaction_hold_timer: float = 0.0
var _wander_target := Vector3.ZERO
var _wander_hops_left: int = 0
var _hop_cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	controller = get_parent() as SlimeController
	if controller != null:
		mood_system = controller.get_node_or_null("PersonalityMoodSystem") as PersonalityMoodSystem


func bind_environment(room_node: Node3D, cam: Camera3D) -> void:
	room_ref = room_node
	camera_ref = cam


func notify_player_interaction(hold_seconds: float = 3.2) -> void:
	time_since_player_touch = 0.0
	_reaction_hold_timer = maxf(_reaction_hold_timer, hold_seconds)
	_transition_to(State.REACTING)


func command_move_to(world_point: Vector3) -> void:
	time_since_player_touch = 0.0
	_wander_target = world_point
	_wander_hops_left = 3
	_hop_cooldown = 0.05
	if mood_system != null:
		mood_system.register_curiosity_focus(3.2)
	_transition_to(State.WANDER_HOP)


func get_state_name() -> StringName:
	return STATE_NAMES.get(current_state, &"idle_observe")


func _process(delta: float) -> void:
	if not autonomous_enabled or controller == null:
		return

	time_since_player_touch += delta

	if _hop_cooldown > 0.0:
		_hop_cooldown = maxf(0.0, _hop_cooldown - delta)

	if current_state == State.REACTING:
		_reaction_hold_timer -= delta
		if camera_ref != null:
			controller.look_target_world = camera_ref.global_position
		if _reaction_hold_timer <= 0.0 and not controller.is_being_dragged:
			_transition_to(State.IDLE_OBSERVE)
			_decision_timer = 1.8
		return

	if mood_system != null and mood_system.is_sleeping:
		if current_state != State.REST_NAP:
			_transition_to(State.REST_NAP)
		return

	_tick_active_state(delta)

	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_choose_next_behavior()


func _tick_active_state(delta: float) -> void:
	match current_state:
		State.IDLE_OBSERVE:
			if camera_ref != null and _rng.randf() < delta * 0.8:
				var jitter := Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.15, 0.2), 0.0)
				controller.look_target_world = camera_ref.global_position + jitter

		State.WANDER_HOP, State.SEEK_ATTENTION:
			var dist_xz: float = Vector2(
				_wander_target.x - controller.global_position.x,
				_wander_target.z - controller.global_position.z
			).length()
			if dist_xz > 0.28 and _wander_hops_left > 0 and _hop_cooldown <= 0.0 and controller.is_on_floor():
				controller.hop_toward(_wander_target, 0.82)
				_wander_hops_left -= 1
				_hop_cooldown = 0.95
			elif dist_xz <= 0.28 or _wander_hops_left <= 0:
				if current_state == State.SEEK_ATTENTION and camera_ref != null:
					controller.look_target_world = camera_ref.global_position

		State.CURIOUS_INSPECT:
			controller.look_target_world = _wander_target


func _choose_next_behavior() -> void:
	if mood_system == null:
		_decision_timer = 3.0
		return

	# إذا انخفضت الطاقة كثيراً، يأخذ سلايمي غفوة لطيفة تلقائياً
	if mood_system.energy < 18.0:
		mood_system.set_sleeping(true)
		if controller.deformer != null:
			controller.deformer.is_resting_flat = true
		AudioManager.play_voice(&"sleepy_yawn")
		_transition_to(State.REST_NAP)
		_decision_timer = 6.0
		return

	# أوزان المنفعة (Utility Scoring)
	var w_idle: float = 1.0
	var w_wander: float = 1.15 * mood_system.personality.curiosity_bias
	var w_curious: float = 0.95 * mood_system.personality.curiosity_bias
	var w_play: float = (1.35 if mood_system.happiness > 70.0 and mood_system.energy > 55.0 else 0.3) * mood_system.personality.playfulness
	var w_attention: float = (1.85 if time_since_player_touch > 16.0 else 0.25) * mood_system.personality.sociability

	var total_w: float = w_idle + w_wander + w_curious + w_play + w_attention
	var pick: float = _rng.randf() * total_w

	if pick < w_idle:
		_transition_to(State.IDLE_OBSERVE)
		if camera_ref != null:
			controller.look_target_world = camera_ref.global_position
		_decision_timer = _rng.randf_range(2.6, 4.4)
		return
	pick -= w_idle

	if pick < w_wander:
		_wander_target = _pick_room_point()
		_wander_hops_left = _rng.randi_range(1, 2)
		_hop_cooldown = 0.15
		_transition_to(State.WANDER_HOP)
		_decision_timer = _rng.randf_range(3.2, 5.0)
		return
	pick -= w_wander

	if pick < w_curious:
		_wander_target = _pick_poi_or_random()
		mood_system.register_curiosity_focus(3.2)
		AudioManager.play_voice(&"curious_coo", 0.0, -4.0)
		if time_since_player_touch > 9.0 and _rng.randf() < 0.45:
			mood_system.thought_triggered.emit("bubble_curious")
		_transition_to(State.CURIOUS_INSPECT)
		_decision_timer = _rng.randf_range(2.8, 4.2)
		return
	pick -= w_curious

	if pick < w_play:
		controller.perform_happy_bounce()
		_transition_to(State.PLAY_BOUNCE)
		_decision_timer = _rng.randf_range(2.5, 4.0)
		return

	# طلب انتباه اللاعب بلطف بالاقتراب من مقدمة الغرفة
	_wander_target = Vector3(0.0, 0.0, 0.65)
	_wander_hops_left = 2
	_hop_cooldown = 0.1
	if mood_system.fullness < 32.0:
		mood_system.thought_triggered.emit("bubble_hungry")
	else:
		mood_system.thought_triggered.emit("bubble_lonely")
	AudioManager.play_voice(&"curious_coo")
	_transition_to(State.SEEK_ATTENTION)
	_decision_timer = _rng.randf_range(4.0, 5.8)


func _pick_room_point() -> Vector3:
	var angle: float = _rng.randf() * TAU
	var radius: float = _rng.randf_range(0.35, 1.65)
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius * 0.85)


func _pick_poi_or_random() -> Vector3:
	if room_ref != null and room_ref.has_method("get_points_of_interest"):
		var pois: Array = room_ref.call("get_points_of_interest")
		if not pois.is_empty():
			var idx: int = _rng.randi_range(0, pois.size() - 1)
			var val: Variant = pois[idx]
			if val is Vector3:
				return val as Vector3
	return _pick_room_point()


func _transition_to(next_state: int) -> void:
	if current_state == next_state:
		return
	current_state = next_state
	state_changed.emit(current_state, get_state_name())

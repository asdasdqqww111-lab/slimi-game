class_name TouchInteractionSystem
extends Node
## نظام التفاعل باللمس المتعدد وتتبع الأشعة ثلاثي الأبعاد (Android Touch + Mouse Fallback).

signal slime_touched(kind: StringName, world_pos: Vector3)
signal floor_tapped(world_pos: Vector3)

enum TouchMode {
	NONE = 0,
	ON_SLIME = 1,
	ON_ROOM = 2,
}

const TAP_MAX_DRAG_PX: float = 24.0
const PET_STEP_PX: float = 32.0
const PULL_ACTIVATE_PX: float = 44.0
const PULL_NET_DISTANCE_PX: float = 135.0

@export var camera_pivot: Node3D
@export var camera: Camera3D
@export var slime: SlimeController
@export var room: Node3D

var _active_pointer_id: int = -1
var _touch_mode: int = TouchMode.NONE
var _press_screen_pos := Vector2.ZERO
var _last_screen_pos := Vector2.ZERO
var _press_hit_world := Vector3.ZERO
var _press_hit_normal := Vector3.UP
var _press_time_msec: int = 0
var _accum_drag_px: float = 0.0
var _pet_dist_px: float = 0.0

var _target_cam_yaw: float = 0.0
var _target_cam_pitch: float = -0.24
var _emulate_touch: bool = true


func _ready() -> void:
	_emulate_touch = bool(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", true))
	if camera_pivot != null:
		_target_cam_yaw = camera_pivot.rotation.y
		_target_cam_pitch = camera_pivot.rotation.x


func _process(delta: float) -> void:
	if camera_pivot != null:
		camera_pivot.rotation.y = lerpf(camera_pivot.rotation.y, _target_cam_yaw, minf(1.0, delta * 7.5))
		camera_pivot.rotation.x = lerpf(camera_pivot.rotation.x, _target_cam_pitch, minf(1.0, delta * 7.5))


func reset_camera_view() -> void:
	_target_cam_yaw = 0.0
	_target_cam_pitch = -0.24


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _active_pointer_id == -1:
				_active_pointer_id = st.index
				handle_pointer_down(st.position)
		else:
			if st.index == _active_pointer_id:
				handle_pointer_up(st.position)
				_active_pointer_id = -1
		return

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _active_pointer_id:
			handle_pointer_move(sd.position, sd.relative)
		return

	# مسار الفأرة الاحتياطي إذا كان emulate_touch_from_mouse معطلاً
	if not _emulate_touch:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed and _active_pointer_id == -1:
					_active_pointer_id = 0
					handle_pointer_down(mb.position)
				elif not mb.pressed and _active_pointer_id == 0:
					handle_pointer_up(mb.position)
					_active_pointer_id = -1
		elif event is InputEventMouseMotion and _active_pointer_id == 0:
			var mm := event as InputEventMouseMotion
			handle_pointer_move(mm.position, mm.relative)


func handle_pointer_down(screen_pos: Vector2) -> void:
	_press_screen_pos = screen_pos
	_last_screen_pos = screen_pos
	_press_time_msec = Time.get_ticks_msec()
	_accum_drag_px = 0.0
	_pet_dist_px = 0.0

	var hit: Dictionary = raycast_from_screen(screen_pos)
	if hit.is_empty():
		_touch_mode = TouchMode.ON_ROOM
		_press_hit_world = Vector3.ZERO
		return

	var collider: Object = hit.get("collider")
	_press_hit_world = hit.get("position", Vector3.ZERO)
	_press_hit_normal = hit.get("normal", Vector3.UP)

	if collider == slime:
		_touch_mode = TouchMode.ON_SLIME
	else:
		_touch_mode = TouchMode.ON_ROOM


func handle_pointer_move(screen_pos: Vector2, relative: Vector2) -> void:
	var step_len: float = relative.length()
	if step_len <= 0.001:
		step_len = screen_pos.distance_to(_last_screen_pos)
	_last_screen_pos = screen_pos
	_accum_drag_px += step_len

	if _touch_mode == TouchMode.ON_SLIME and slime != null:
		var hit: Dictionary = raycast_from_screen(screen_pos)
		var still_on_slime: bool = (not hit.is_empty() and hit.get("collider") == slime)
		var net_pull_px: float = screen_pos.distance_to(_press_screen_pos)
		var should_pull: bool = (
			slime.is_being_dragged
			or net_pull_px >= PULL_NET_DISTANCE_PX
			or (not still_on_slime and _accum_drag_px >= PULL_ACTIVATE_PX)
		)

		if not should_pull and still_on_slime:
			_pet_dist_px += step_len
			var hit_pos: Vector3 = hit.get("position", slime.global_position)
			slime.look_target_world = camera.global_position if camera != null else hit_pos
			if _pet_dist_px >= PET_STEP_PX:
				var intensity: float = clampf(_pet_dist_px / 48.0, 0.45, 1.15)
				_pet_dist_px = 0.0
				slime.on_petted(hit_pos, intensity)
				slime_touched.emit(&"pet", hit_pos)
		elif should_pull:
			var world_cur: Vector3 = _project_onto_slime_plane(screen_pos)
			var drag_delta: Vector3 = (world_cur - _press_hit_world) * 0.55
			slime.on_pull_drag(drag_delta)

	elif _touch_mode == TouchMode.ON_ROOM:
		if _accum_drag_px > 12.0:
			_target_cam_yaw = clampf(_target_cam_yaw - relative.x * 0.0042, -0.52, 0.52)
			_target_cam_pitch = clampf(_target_cam_pitch - relative.y * 0.0025, -0.40, -0.10)


func handle_pointer_up(screen_pos: Vector2) -> void:
	if _touch_mode == TouchMode.ON_SLIME and slime != null:
		if slime.is_being_dragged:
			slime.on_pull_release()
			slime_touched.emit(&"pull_release", slime.global_position)
		elif _accum_drag_px < TAP_MAX_DRAG_PX:
			slime.on_poked(_press_hit_world, _press_hit_normal)
			slime_touched.emit(&"poke", _press_hit_world)

	elif _touch_mode == TouchMode.ON_ROOM:
		var held_ms: int = Time.get_ticks_msec() - _press_time_msec
		if _accum_drag_px < TAP_MAX_DRAG_PX and held_ms < 500:
			var hit: Dictionary = raycast_from_screen(screen_pos)
			if not hit.is_empty() and hit.get("collider") != slime:
				var pos: Vector3 = hit.get("position", Vector3.ZERO)
				if pos.y < 0.35:
					var target := Vector3(pos.x, 0.0, pos.z).limit_length(2.05)
					if slime != null:
						if slime.ai_brain != null and slime.ai_brain.has_method("command_move_to"):
							slime.ai_brain.call("command_move_to", target)
						slime.hop_toward(target, 0.90)
					if room != null and room.has_method("spawn_floor_tap_ring"):
						room.call("spawn_floor_tap_ring", target)
					floor_tapped.emit(target)

	_touch_mode = TouchMode.NONE


func raycast_from_screen(screen_pos: Vector2) -> Dictionary:
	if camera == null or slime == null:
		return {}
	var world_3d: World3D = slime.get_world_3d()
	if world_3d == null:
		return {}
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if space_state == null:
		return {}

	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 20.0)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space_state.intersect_ray(query)


func _project_onto_slime_plane(screen_pos: Vector2) -> Vector3:
	if camera == null or slime == null:
		return _press_hit_world
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var plane_normal: Vector3 = (camera.global_position - slime.global_position).normalized()
	var plane := Plane(plane_normal, _press_hit_world)
	var intersection: Variant = plane.intersects_ray(origin, dir)
	if intersection is Vector3:
		return intersection as Vector3
	return _press_hit_world

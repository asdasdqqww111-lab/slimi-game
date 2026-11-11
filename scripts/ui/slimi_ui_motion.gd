class_name SlimiUIMotion
extends RefCounted
## محرك الحركة والانتقالات الموحد لواجهة SLIMI (Motion Design Engine):
## يوفر انتقالات Fade / Scale / Slide محسوبة، استجابة لمسية للأزرار، منع الضغط المتكرر،
## واحترام إعداد تقليل الحركة (Reduce Motion).


static func is_reduce_motion() -> bool:
	return bool(SaveManager.get_section("ui_preferences").get("reduce_motion", false))


static func animate_sheet_open(panel: Control) -> void:
	if panel == null:
		return
	panel.visible = true
	if is_reduce_motion() or not panel.is_inside_tree():
		panel.modulate.a = 1.0
		panel.scale = Vector2.ONE
		return

	panel.pivot_offset = Vector2(panel.size.x * 0.5, panel.size.y)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)
	var tw: Tween = panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func animate_sheet_close(panel: Control) -> void:
	if panel == null:
		return
	panel.visible = false
	panel.modulate.a = 1.0
	panel.scale = Vector2.ONE


static func animate_press_bounce(ctrl: Control) -> void:
	if ctrl == null or is_reduce_motion() or not ctrl.is_inside_tree():
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	var tw: Tween = ctrl.create_tween()
	tw.tween_property(ctrl, "scale", Vector2(0.94, 0.94), 0.05)
	tw.tween_property(ctrl, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func attach_interactive_feedback(btn: BaseButton, debounce_ms: int = 130) -> void:
	if btn == null:
		return
	btn.pressed.connect(func() -> void:
		var now_ms: int = Time.get_ticks_msec()
		var last_ms: int = int(btn.get_meta("_last_tap_ms", 0))
		if now_ms - last_ms < debounce_ms:
			return
		btn.set_meta("_last_tap_ms", now_ms)
		animate_press_bounce(btn)
		AudioManager.play_sfx(&"ui_click", 0.0, -5.0)
		AndroidPlatformManager.trigger_haptic(10)
	)

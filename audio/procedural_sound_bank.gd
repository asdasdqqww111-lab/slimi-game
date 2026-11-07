class_name ProceduralSoundBank
extends RefCounted
## مصرف صوتي إجرائي يولّد مؤثرات سلايمي المرحة بصيغة PCM 16-bit دون أي ملفات ثنائية خارجية.

const DEFAULT_RATE: int = 22050


static func build_all_streams(sample_rate: int = DEFAULT_RATE) -> Dictionary:
	var rate: int = clampi(sample_rate, 11025, 44100)
	return {
		&"boing_hop": _make_boing_hop(rate),
		&"squish_poke": _make_squish_poke(rate),
		&"purr_pet": _make_purr_pet(rate),
		&"happy_chirp": _make_happy_chirp(rate),
		&"curious_coo": _make_curious_coo(rate),
		&"sleepy_yawn": _make_sleepy_yawn(rate),
		&"eat_nom": _make_eat_nom(rate),
		&"dizzy_wobble": _make_dizzy_wobble(rate),
		&"ui_click": _make_ui_click(rate),
		&"ambient_pad": _make_ambient_pad(rate),
	}


static func _pack_pcm16(samples: PackedFloat32Array, sample_rate: int, looped: bool = false) -> AudioStreamWAV:
	var count: int = samples.size()
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	var prev: float = 0.0
	for i in range(count):
		# تنعيم خفيف لتجنب الترددات الحادة على سماعات الهواتف
		var filtered: float = lerpf(samples[i], prev, 0.16)
		prev = filtered
		var clamped: float = clampf(filtered, -0.96, 0.96)
		var pcm_val: int = int(round(clamped * 32767.0))
		bytes.encode_s16(i * 2, pcm_val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = bytes
	return stream


static func _envelope(t: float, duration: float, attack: float, release: float) -> float:
	if t < 0.0 or t > duration:
		return 0.0
	var env: float = 1.0
	if attack > 0.0001 and t < attack:
		env *= 0.5 - 0.5 * cos(PI * (t / attack))
	if release > 0.0001 and t > duration - release:
		var rel_t: float = (duration - t) / release
		env *= 0.5 - 0.5 * cos(PI * clampf(rel_t, 0.0, 1.0))
	return env


static func _make_boing_hop(rate: int) -> AudioStreamWAV:
	var duration: float = 0.28
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var norm: float = t / duration
		var freq: float = 230.0 + 310.0 * sin(norm * PI * 0.88) + 38.0 * sin(norm * TAU * 3.5)
		phase += TAU * freq / float(rate)
		var sample: float = sin(phase) * 0.68 + sin(phase * 2.0) * 0.22
		var decay: float = exp(-norm * 3.2)
		out[i] = sample * decay * _envelope(t, duration, 0.008, 0.05) * 0.78
	return _pack_pcm16(out, rate)


static func _make_squish_poke(rate: int) -> AudioStreamWAV:
	var duration: float = 0.20
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var norm: float = t / duration
		var bubble: float = sin(norm * TAU * 6.5) * 95.0
		var freq: float = lerpf(340.0, 520.0, norm * norm) + bubble
		phase += TAU * freq / float(rate)
		var sample: float = sin(phase) * 0.65 + sin(phase * 2.4) * 0.25
		out[i] = sample * exp(-norm * 2.6) * _envelope(t, duration, 0.005, 0.04) * 0.76
	return _pack_pcm16(out, rate)


static func _make_purr_pet(rate: int) -> AudioStreamWAV:
	var duration: float = 0.44
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var p1: float = 0.0
	var p2: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var trill: float = 1.0 + 0.045 * sin(t * TAU * 13.5)
		p1 += TAU * (245.0 * trill) / float(rate)
		p2 += TAU * (367.5 * trill) / float(rate)
		var am: float = 0.72 + 0.28 * sin(t * TAU * 13.5)
		var sample: float = (sin(p1) * 0.62 + sin(p2) * 0.32) * am
		out[i] = sample * _envelope(t, duration, 0.05, 0.10) * 0.55
	return _pack_pcm16(out, rate)


static func _make_happy_chirp(rate: int) -> AudioStreamWAV:
	var duration: float = 0.34
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	var notes := [523.25, 659.25, 783.99]
	for i in range(total):
		var t: float = float(i) / float(rate)
		var norm: float = t / duration
		var idx: int = mini(int(norm * 3.0), 2)
		var target_f: float = notes[idx] * (1.0 + 0.03 * sin(t * TAU * 9.0))
		phase += TAU * target_f / float(rate)
		var local_t: float = fmod(norm * 3.0, 1.0)
		var note_env: float = sin(clampf(local_t, 0.0, 1.0) * PI)
		var sample: float = (sin(phase) * 0.72 + sin(phase * 2.0) * 0.18) * (0.35 + 0.65 * note_env)
		out[i] = sample * _envelope(t, duration, 0.01, 0.05) * 0.68
	return _pack_pcm16(out, rate)


static func _make_curious_coo(rate: int) -> AudioStreamWAV:
	var duration: float = 0.27
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var norm: float = t / duration
		var freq: float = lerpf(350.0, 590.0, smoothstep(0.1, 0.92, norm))
		phase += TAU * freq / float(rate)
		var sample: float = sin(phase) * 0.75 + sin(phase * 1.5) * 0.16
		out[i] = sample * _envelope(t, duration, 0.025, 0.06) * 0.64
	return _pack_pcm16(out, rate)


static func _make_sleepy_yawn(rate: int) -> AudioStreamWAV:
	var duration: float = 0.55
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var norm: float = t / duration
		var freq: float = lerpf(430.0, 225.0, smoothstep(0.0, 1.0, norm))
		phase += TAU * freq / float(rate)
		var sample: float = sin(phase) * 0.7 + sin(phase * 2.0) * 0.14
		out[i] = sample * _envelope(t, duration, 0.08, 0.16) * 0.52
	return _pack_pcm16(out, rate)


static func _make_eat_nom(rate: int) -> AudioStreamWAV:
	var duration: float = 0.30
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var bite_idx: int = 0 if t < 0.15 else 1
		var local: float = (t if bite_idx == 0 else (t - 0.15)) / 0.15
		var base_f: float = 310.0 if bite_idx == 0 else 390.0
		var freq: float = base_f + 160.0 * local
		phase += TAU * freq / float(rate)
		var bite_env: float = sin(clampf(local, 0.0, 1.0) * PI)
		out[i] = (sin(phase) * 0.7 + sin(phase * 2.2) * 0.22) * bite_env * 0.72
	return _pack_pcm16(out, rate)


static func _make_dizzy_wobble(rate: int) -> AudioStreamWAV:
	var duration: float = 0.42
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var freq: float = 370.0 + 85.0 * sin(t * TAU * 10.5)
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.68 + sin(phase * 2.0) * 0.2) * _envelope(t, duration, 0.02, 0.08) * 0.62
	return _pack_pcm16(out, rate)


static func _make_ui_click(rate: int) -> AudioStreamWAV:
	var duration: float = 0.065
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var norm: float = t / duration
		var freq: float = lerpf(640.0, 920.0, norm)
		phase += TAU * freq / float(rate)
		out[i] = sin(phase) * exp(-norm * 3.8) * _envelope(t, duration, 0.003, 0.015) * 0.55
	return _pack_pcm16(out, rate)


static func _make_ambient_pad(rate: int) -> AudioStreamWAV:
	# دورة متصلة 2.0 ثانية بترددات صحيحة الدورات لضمان تكرار سلس بلا طقطقة
	var duration: float = 2.0
	var total: int = rate * 2
	var out := PackedFloat32Array()
	out.resize(total)
	for i in range(total):
		var t: float = float(i) / float(rate)
		var c1: float = sin(TAU * 174.5 * t) * 0.38
		var c2: float = sin(TAU * 220.0 * t) * 0.28
		var c3: float = sin(TAU * 261.5 * t) * 0.22
		var breath: float = 0.82 + 0.18 * sin(TAU * 0.5 * t)
		out[i] = (c1 + c2 + c3) * breath * 0.22
	return _pack_pcm16(out, rate, true)

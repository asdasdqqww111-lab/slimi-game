class_name ProceduralSoundBank
extends RefCounted
## مصرف صوتي أصلي متعدد الطبقات لشخصية SLIMI:
## يولّد أصواتاً رقيقة ودافئة ومحببة (ضحكات، دهشة، حزن، فضول، نعاس، ملل، قبلات، ومقاطع كلامية نغمية ناعمة)
## بصيغة PCM 16-bit صافية دون أي ضجيج أو ملفات ثنائية خارجية.

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
		# طبقة التعبيرات الصوتية الرقيقة الجديدة (SLIMI VOICE Layer A)
		&"giggle_soft": _make_giggle_soft(rate),
		&"laugh_long": _make_laugh_long(rate),
		&"joy_sparkle": _make_joy_sparkle(rate),
		&"sad_whimper": _make_sad_whimper(rate),
		&"surprise_gasp": _make_surprise_gasp(rate),
		&"bored_sigh": _make_bored_sigh(rate),
		&"puzzled_hum": _make_puzzled_hum(rate),
		&"shy_squeak": _make_shy_squeak(rate),
		&"scared_tremble": _make_scared_tremble(rate),
		&"kiss_mwah": _make_kiss_mwah(rate),
		&"proud_tada": _make_proud_tada(rate),
		&"jelly_wobble_soft": _make_jelly_wobble_soft(rate),
	}


## يولّد دفقاً صوتياً كلامياً ناعماً ولطيفاً يطابق طول ومقاطع الجملة المنطوقة ونبرة الشعور
static func synthesize_speech_phrase(text: String, base_pitch_hz: float = 430.0, tempo_scale: float = 1.0, sample_rate: int = DEFAULT_RATE) -> Dictionary:
	var rate: int = clampi(sample_rate, 11025, 44100)
	var cleaned: String = text.strip_edges()
	if cleaned.is_empty():
		cleaned = "همم"

	# استخراج المقاطع الصوتية لتوليد كلام نغمي دافئ + جدول حركة الفم (Visemes)
	var words: PackedStringArray = cleaned.split(" ", false)
	var syllable_count: int = clampi(words.size() * 2, 2, 18)
	var syl_dur: float = clampf(0.105 / clampf(tempo_scale, 0.7, 1.4), 0.07, 0.15)
	var gap_dur: float = 0.024
	var total_dur: float = float(syllable_count) * (syl_dur + gap_dur) + 0.04
	var total_samples: int = maxi(256, int(total_dur * float(rate)))

	var out := PackedFloat32Array()
	out.resize(total_samples)

	var visemes: Array[Dictionary] = []
	var is_question: bool = cleaned.ends_with("؟") or cleaned.ends_with("?")
	var is_excited: bool = cleaned.ends_with("!") or cleaned.contains("ياي") or cleaned.contains("هييه")

	var phase1: float = 0.0
	var phase2: float = 0.0

	for s_idx in range(syllable_count):
		var char_seed: int = cleaned.unicode_at(s_idx % cleaned.length()) + s_idx * 17
		var vowel_kind: int = char_seed % 4 # 0=A(open), 1=I(smile), 2=U(round), 3=E(mid)
		var start_t: float = float(s_idx) * (syl_dur + gap_dur)
		var end_t: float = start_t + syl_dur

		# منحنى نبرة طبيعي ومحبب (يرتفع في نهاية السؤال أو الحماس)
		var phrase_u: float = float(s_idx) / float(maxi(1, syllable_count - 1))
		var intonation: float = 1.0 + 0.07 * sin(phrase_u * PI)
		if is_question and phrase_u > 0.65:
			intonation += (phrase_u - 0.65) * 0.65
		elif is_excited:
			intonation += 0.08 * cos(phrase_u * TAU)

		var note_offsets := [1.0, 1.122, 1.26, 0.944]
		var f0: float = base_pitch_hz * float(note_offsets[char_seed % 4]) * intonation
		var f_formant: float = f0 * (2.0 if vowel_kind != 2 else 1.5)

		var open_amt: float = [0.92, 0.55, 0.72, 0.78][vowel_kind]
		var wide_amt: float = [0.75, 1.15, 0.42, 0.95][vowel_kind]
		visemes.append({
			"start": start_t,
			"end": end_t,
			"open": open_amt,
			"wide": wide_amt,
			"vowel": vowel_kind,
		})

		var i_start: int = clampi(int(start_t * float(rate)), 0, total_samples - 1)
		var i_end: int = clampi(int(end_t * float(rate)), i_start, total_samples)
		for i in range(i_start, i_end):
			var local_t: float = float(i - i_start) / float(rate)
			var u: float = local_t / maxf(syl_dur, 0.01)
			var vibrato: float = 1.0 + 0.016 * sin(local_t * TAU * 6.5)
			var glide: float = lerpf(0.96, 1.03, smoothstep(0.0, 0.5, u))
			phase1 += TAU * (f0 * vibrato * glide) / float(rate)
			phase2 += TAU * (f_formant * vibrato) / float(rate)
			var env: float = _envelope(local_t, syl_dur, 0.016, 0.032)
			# موجة صوتية حريرية ناعمة ودافئة تشبه صوت كائن صغير لطيف
			var tone: float = sin(phase1) * 0.68 + sin(phase2) * 0.20 + sin(phase1 * 3.0) * 0.05
			out[i] = tone * env * 0.50

	return {
		"stream": _pack_pcm16(out, rate, false),
		"duration": total_dur,
		"visemes": visemes,
	}


static func _pack_pcm16(samples: PackedFloat32Array, sample_rate: int, looped: bool = false) -> AudioStreamWAV:
	var count: int = samples.size()
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	var prev: float = 0.0
	for i in range(count):
		var filtered: float = lerpf(samples[i], prev, 0.20)
		prev = filtered
		var clamped: float = clampf(filtered, -0.95, 0.95)
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
		var freq: float = 240.0 + 300.0 * sin(norm * PI * 0.88) + 34.0 * sin(norm * TAU * 3.5)
		phase += TAU * freq / float(rate)
		var sample: float = sin(phase) * 0.70 + sin(phase * 2.0) * 0.20
		out[i] = sample * exp(-norm * 3.0) * _envelope(t, duration, 0.01, 0.05) * 0.74
	return _pack_pcm16(out, rate)


static func _make_squish_poke(rate: int) -> AudioStreamWAV:
	var duration: float = 0.21
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var norm: float = t / duration
		var freq: float = lerpf(350.0, 540.0, norm * norm) + sin(norm * TAU * 6.0) * 80.0
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.68 + sin(phase * 2.2) * 0.22) * exp(-norm * 2.5) * _envelope(t, duration, 0.006, 0.04) * 0.72
	return _pack_pcm16(out, rate)


static func _make_purr_pet(rate: int) -> AudioStreamWAV:
	var duration: float = 0.46
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var p1: float = 0.0
	var p2: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var trill: float = 1.0 + 0.04 * sin(t * TAU * 12.5)
		p1 += TAU * (260.0 * trill) / float(rate)
		p2 += TAU * (390.0 * trill) / float(rate)
		var am: float = 0.74 + 0.26 * sin(t * TAU * 12.5)
		out[i] = (sin(p1) * 0.64 + sin(p2) * 0.30) * am * _envelope(t, duration, 0.05, 0.11) * 0.54
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
		var target_f: float = notes[idx] * (1.0 + 0.025 * sin(t * TAU * 9.0))
		phase += TAU * target_f / float(rate)
		var note_env: float = sin(clampf(fmod(norm * 3.0, 1.0), 0.0, 1.0) * PI)
		out[i] = (sin(phase) * 0.74 + sin(phase * 2.0) * 0.16) * (0.35 + 0.65 * note_env) * _envelope(t, duration, 0.01, 0.05) * 0.64
	return _pack_pcm16(out, rate)


static func _make_curious_coo(rate: int) -> AudioStreamWAV:
	var duration: float = 0.28
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var norm: float = t / duration
		var freq: float = lerpf(370.0, 620.0, smoothstep(0.08, 0.92, norm))
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.76 + sin(phase * 1.5) * 0.15) * _envelope(t, duration, 0.025, 0.06) * 0.60
	return _pack_pcm16(out, rate)


static func _make_sleepy_yawn(rate: int) -> AudioStreamWAV:
	var duration: float = 0.62
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var norm: float = t / duration
		var arch: float = sin(norm * PI * 0.85)
		var freq: float = lerpf(460.0, 240.0, smoothstep(0.15, 1.0, norm)) + arch * 45.0
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.72 + sin(phase * 2.0) * 0.14) * _envelope(t, duration, 0.09, 0.18) * 0.50
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
		var freq: float = (330.0 if bite_idx == 0 else 410.0) + 150.0 * local
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.72 + sin(phase * 2.1) * 0.20) * sin(clampf(local, 0.0, 1.0) * PI) * 0.68
	return _pack_pcm16(out, rate)


static func _make_dizzy_wobble(rate: int) -> AudioStreamWAV:
	var duration: float = 0.42
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var freq: float = 390.0 + 80.0 * sin(t * TAU * 9.5)
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.70 + sin(phase * 2.0) * 0.18) * _envelope(t, duration, 0.02, 0.08) * 0.58
	return _pack_pcm16(out, rate)


static func _make_giggle_soft(rate: int) -> AudioStreamWAV:
	# ضحكة رقيقة ثلاثية النبضات "هي-هي-هي!"
	var duration: float = 0.38
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	var hops := [540.0, 610.0, 680.0]
	for i in range(total):
		var t: float = float(i) / float(rate)
		var u: float = t / duration
		var idx: int = mini(int(u * 3.0), 2)
		var pulse: float = sin(clampf(fmod(u * 3.0, 1.0), 0.0, 1.0) * PI)
		var freq: float = float(hops[idx]) + pulse * 55.0
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.74 + sin(phase * 2.0) * 0.18) * pulse * _envelope(t, duration, 0.01, 0.05) * 0.60
	return _pack_pcm16(out, rate)


static func _make_laugh_long(rate: int) -> AudioStreamWAV:
	# ضحكة مرحة طويلة خماسية النبضات
	var duration: float = 0.68
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	var notes := [520.0, 585.0, 640.0, 695.0, 620.0]
	for i in range(total):
		var t: float = float(i) / float(rate)
		var u: float = t / duration
		var idx: int = mini(int(u * 5.0), 4)
		var pulse: float = pow(sin(clampf(fmod(u * 5.0, 1.0), 0.0, 1.0) * PI), 0.85)
		var freq: float = float(notes[idx]) + pulse * 65.0
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.72 + sin(phase * 2.0) * 0.18) * pulse * _envelope(t, duration, 0.015, 0.08) * 0.62
	return _pack_pcm16(out, rate)


static func _make_joy_sparkle(rate: int) -> AudioStreamWAV:
	var duration: float = 0.44
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	var chord := [523.25, 659.25, 783.99, 1046.5]
	for i in range(total):
		var t: float = float(i) / float(rate)
		var u: float = t / duration
		var idx: int = mini(int(u * 4.0), 3)
		phase += TAU * float(chord[idx]) / float(rate)
		var pulse: float = 0.45 + 0.55 * sin(clampf(fmod(u * 4.0, 1.0), 0.0, 1.0) * PI)
		out[i] = (sin(phase) * 0.72 + sin(phase * 2.0) * 0.16) * pulse * _envelope(t, duration, 0.01, 0.07) * 0.60
	return _pack_pcm16(out, rate)


static func _make_sad_whimper(rate: int) -> AudioStreamWAV:
	var duration: float = 0.48
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var u: float = t / duration
		var freq: float = lerpf(440.0, 295.0, smoothstep(0.0, 1.0, u)) * (1.0 + 0.02 * sin(t * TAU * 6.5))
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.78 + sin(phase * 2.0) * 0.12) * _envelope(t, duration, 0.04, 0.14) * 0.50
	return _pack_pcm16(out, rate)


static func _make_surprise_gasp(rate: int) -> AudioStreamWAV:
	var duration: float = 0.24
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var u: float = t / duration
		var freq: float = lerpf(410.0, 760.0, pow(u, 0.55))
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.74 + sin(phase * 2.0) * 0.18) * _envelope(t, duration, 0.01, 0.06) * 0.62
	return _pack_pcm16(out, rate)


static func _make_bored_sigh(rate: int) -> AudioStreamWAV:
	var duration: float = 0.52
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var u: float = t / duration
		var freq: float = lerpf(380.0, 265.0, u)
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.76 + sin(phase * 2.0) * 0.12) * _envelope(t, duration, 0.06, 0.16) * 0.48
	return _pack_pcm16(out, rate)


static func _make_puzzled_hum(rate: int) -> AudioStreamWAV:
	var duration: float = 0.34
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var u: float = t / duration
		var freq: float = 390.0 - 45.0 * sin(u * PI) + 165.0 * smoothstep(0.45, 0.96, u)
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.74 + sin(phase * 2.0) * 0.18) * _envelope(t, duration, 0.02, 0.06) * 0.56
	return _pack_pcm16(out, rate)


static func _make_shy_squeak(rate: int) -> AudioStreamWAV:
	var duration: float = 0.26
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var u: float = t / duration
		var freq: float = lerpf(510.0, 640.0, sin(u * PI))
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.78 + sin(phase * 2.0) * 0.14) * _envelope(t, duration, 0.02, 0.07) * 0.52
	return _pack_pcm16(out, rate)


static func _make_scared_tremble(rate: int) -> AudioStreamWAV:
	var duration: float = 0.36
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var u: float = t / duration
		var trem: float = 1.0 + 0.06 * sin(t * TAU * 18.0)
		var freq: float = lerpf(560.0, 420.0, u) * trem
		phase += TAU * freq / float(rate)
		out[i] = sin(phase) * _envelope(t, duration, 0.015, 0.09) * 0.50
	return _pack_pcm16(out, rate)


static func _make_kiss_mwah(rate: int) -> AudioStreamWAV:
	var duration: float = 0.25
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var u: float = t / duration
		var freq: float = (340.0 + 360.0 * smoothstep(0.25, 0.85, u))
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.72 + sin(phase * 2.0) * 0.20) * _envelope(t, duration, 0.015, 0.05) * 0.58
	return _pack_pcm16(out, rate)


static func _make_proud_tada(rate: int) -> AudioStreamWAV:
	var duration: float = 0.46
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var freq: float = 523.25 if t < 0.14 else 698.46
		phase += TAU * freq / float(rate)
		out[i] = (sin(phase) * 0.72 + sin(phase * 2.0) * 0.20) * _envelope(t, duration, 0.01, 0.10) * 0.62
	return _pack_pcm16(out, rate)


static func _make_jelly_wobble_soft(rate: int) -> AudioStreamWAV:
	var duration: float = 0.30
	var total: int = int(duration * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var phase: float = 0.0
	for i in range(total):
		var t: float = float(i) / float(rate)
		var freq: float = 290.0 + 70.0 * sin(t * TAU * 8.0)
		phase += TAU * freq / float(rate)
		out[i] = sin(phase) * _envelope(t, duration, 0.02, 0.08) * 0.52
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
		out[i] = sin(phase) * exp(-norm * 3.8) * _envelope(t, duration, 0.003, 0.015) * 0.52
	return _pack_pcm16(out, rate)


static func _make_ambient_pad(rate: int) -> AudioStreamWAV:
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
		out[i] = (c1 + c2 + c3) * breath * 0.20
	return _pack_pcm16(out, rate, true)

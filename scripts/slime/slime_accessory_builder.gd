class_name SlimeAccessoryBuilder
extends RefCounted
## يبني تفاصيل شخصية سلايمي المرجعية بدقة ثلاثية الأبعاد عالية:
## قرن النجمة الهلامي الوردي، القبعة الصوفية الصفراء المحبوكة مع الكرة البيضاء والوردة الملونة والقلب،
## الكفّان الهلاميان اللامعان على البطن، والفقاعات الهلامية المعلقة داخل الجسم.


static func build_reference_accessories(visual_root: Node3D) -> Dictionary:
	var refs: Dictionary = {}
	if visual_root == null:
		return refs

	var jelly_acc_mat := _create_glossy_jelly_part_material()
	var knit_dome_mat := _create_knit_material(26.0, 20.0)
	var knit_cuff_mat := _create_knit_material(36.0, 14.0)
	var bubble_mat := _create_bubble_material()

	# 1. قرن النجمة الهلامي الوردي اللامع (أعلى يسار الرأس كما في الصورة المرجعية)
	var antenna_root := Node3D.new()
	antenna_root.name = "StarAntenna"
	antenna_root.position = Vector3(-0.185, 0.415, 0.05)
	visual_root.add_child(antenna_root)

	var stalk_inst := MeshInstance3D.new()
	stalk_inst.name = "AntennaStalk"
	stalk_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stalk_inst.mesh = _build_curved_antenna_stalk()
	stalk_inst.material_override = jelly_acc_mat
	antenna_root.add_child(stalk_inst)

	var star_pivot := Node3D.new()
	star_pivot.name = "StarCharmPivot"
	star_pivot.position = Vector3(-0.315, 0.045, 0.055)
	star_pivot.rotation_degrees = Vector3(0.0, 8.0, 14.0)
	antenna_root.add_child(star_pivot)

	var star_inst := MeshInstance3D.new()
	star_inst.name = "StarCharmMesh"
	star_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star_inst.mesh = _build_plump_five_star_mesh(0.108, 0.052, 0.036)
	star_inst.material_override = jelly_acc_mat
	star_pivot.add_child(star_inst)

	refs["antenna_root"] = antenna_root
	refs["star_pivot"] = star_pivot

	# 2. القبعة الصوفية الصفراء المحبوكة المائلة بلطف (أعلى يمين الرأس)
	var beanie_root := Node3D.new()
	beanie_root.name = "KnitBeanie"
	beanie_root.position = Vector3(0.185, 0.405, 0.015)
	beanie_root.rotation_degrees = Vector3(5.0, -8.0, -24.0)
	visual_root.add_child(beanie_root)

	var dome_inst := MeshInstance3D.new()
	dome_inst.name = "BeanieDome"
	dome_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 0.315
	dome_mesh.height = 0.47
	dome_mesh.is_hemisphere = true
	dome_mesh.radial_segments = 36
	dome_mesh.rings = 18
	dome_inst.mesh = dome_mesh
	dome_inst.position = Vector3(0.0, -0.01, 0.0)
	dome_inst.material_override = knit_dome_mat
	beanie_root.add_child(dome_inst)

	var cuff_inst := MeshInstance3D.new()
	cuff_inst.name = "BeanieCuff"
	cuff_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cuff_torus := TorusMesh.new()
	cuff_torus.inner_radius = 0.225
	cuff_torus.outer_radius = 0.365
	cuff_torus.rings = 36
	cuff_torus.ring_segments = 18
	cuff_inst.mesh = cuff_torus
	cuff_inst.scale = Vector3(1.04, 1.38, 0.98)
	cuff_inst.position = Vector3(0.0, 0.015, 0.0)
	cuff_inst.material_override = knit_cuff_mat
	beanie_root.add_child(cuff_inst)

	# الكرة الصوفية البيضاء المنفوشة أعلى القبعة (Fluffy Pom-Pom)
	var pom_root := Node3D.new()
	pom_root.name = "PomPom"
	pom_root.position = Vector3(0.0, 0.275, -0.01)
	beanie_root.add_child(pom_root)

	var pom_mat := _create_soft_unshaded_mat(Color(1.0, 0.985, 0.98, 1.0), Color(0.95, 0.91, 0.94, 1.0))
	var pom_core := MeshInstance3D.new()
	pom_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pom_sphere := SphereMesh.new()
	pom_sphere.radius = 0.112
	pom_sphere.height = 0.215
	pom_sphere.radial_segments = 24
	pom_sphere.rings = 14
	pom_core.mesh = pom_sphere
	pom_core.material_override = pom_mat
	pom_root.add_child(pom_core)

	var tuft_mesh := SphereMesh.new()
	tuft_mesh.radius = 0.048
	tuft_mesh.height = 0.092
	tuft_mesh.radial_segments = 12
	tuft_mesh.rings = 8
	var tuft_dirs: Array[Vector3] = [
		Vector3(0.08, 0.04, 0.04), Vector3(-0.08, 0.04, 0.04),
		Vector3(0.04, 0.08, 0.05), Vector3(-0.04, 0.08, -0.04),
		Vector3(0.0, 0.095, 0.0), Vector3(0.07, -0.02, 0.07),
		Vector3(-0.07, -0.02, 0.07), Vector3(0.0, 0.03, 0.09),
	]
	for i in range(tuft_dirs.size()):
		var t_inst := MeshInstance3D.new()
		t_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t_inst.mesh = tuft_mesh
		t_inst.position = tuft_dirs[i]
		t_inst.material_override = pom_mat
		pom_root.add_child(t_inst)

	# وردة الخيوط الملونة على حافة القبعة (Yarn Flower Brooch)
	var flower_root := Node3D.new()
	flower_root.name = "YarnFlower"
	flower_root.position = Vector3(0.095, 0.085, 0.315)
	flower_root.rotation_degrees = Vector3(-14.0, 16.0, 0.0)
	beanie_root.add_child(flower_root)

	var petal_colors: Array[Color] = [
		Color(0.42, 0.86, 0.42, 1.0), # أخضر نعناعي
		Color(0.68, 0.46, 0.96, 1.0), # بنفسجي ناعم
		Color(1.0, 0.84, 0.28, 1.0),  # أصفر مشرق
		Color(0.92, 0.70, 0.77, 1.0), # وردي دافئ
	]
	var petal_offsets: Array[Vector3] = [
		Vector3(-0.042, 0.038, 0.0),
		Vector3(0.042, 0.040, 0.0),
		Vector3(0.044, -0.036, 0.0),
		Vector3(-0.040, -0.038, 0.0),
	]
	var petal_sphere := SphereMesh.new()
	petal_sphere.radius = 0.038
	petal_sphere.height = 0.062
	petal_sphere.radial_segments = 16
	petal_sphere.rings = 10
	for p_idx in range(petal_colors.size()):
		var p_inst := MeshInstance3D.new()
		p_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p_inst.mesh = petal_sphere
		p_inst.position = petal_offsets[p_idx]
		p_inst.scale = Vector3(1.08, 0.96, 0.68)
		p_inst.material_override = _create_soft_unshaded_mat(petal_colors[p_idx], petal_colors[p_idx].darkened(0.18))
		flower_root.add_child(p_inst)

	var center_bead := MeshInstance3D.new()
	center_bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	center_bead.mesh = petal_sphere
	center_bead.scale = Vector3(0.65, 0.65, 0.62)
	center_bead.position = Vector3(0.002, 0.002, 0.016)
	center_bead.material_override = pom_mat
	flower_root.add_child(center_bead)

	# دبوس القلب الوردي اللامع على يمين حافة القبعة (Glossy Pink Heart Pin)
	var heart_inst := MeshInstance3D.new()
	heart_inst.name = "HeartPin"
	heart_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	heart_inst.mesh = _build_plump_heart_mesh(0.062)
	heart_inst.position = Vector3(0.245, 0.015, 0.245)
	heart_inst.rotation_degrees = Vector3(0.0, 34.0, -12.0)
	heart_inst.material_override = jelly_acc_mat
	beanie_root.add_child(heart_inst)

	refs["beanie_root"] = beanie_root
	refs["pom_root"] = pom_root

	# 3. الكفّان الهلاميان اللامعان على البطن (Translucent Glossy Jelly Paws)
	var paws_anchor := Node3D.new()
	paws_anchor.name = "JellyPaws"
	paws_anchor.position = Vector3(0.0, -0.145, 0.545)
	visual_root.add_child(paws_anchor)

	var bean_mesh := _build_bean_paw_mesh()

	var left_paw := MeshInstance3D.new()
	left_paw.name = "LeftPaw"
	left_paw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	left_paw.mesh = bean_mesh
	left_paw.position = Vector3(-0.132, 0.0, 0.0)
	left_paw.rotation_degrees = Vector3(-8.0, -14.0, 16.0)
	left_paw.material_override = jelly_acc_mat
	paws_anchor.add_child(left_paw)

	var right_paw := MeshInstance3D.new()
	right_paw.name = "RightPaw"
	right_paw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	right_paw.mesh = bean_mesh
	right_paw.position = Vector3(0.132, 0.0, 0.0)
	right_paw.scale = Vector3(-1.0, 1.0, 1.0)
	right_paw.rotation_degrees = Vector3(-8.0, 14.0, -16.0)
	right_paw.material_override = jelly_acc_mat
	paws_anchor.add_child(right_paw)

	refs["paws_anchor"] = paws_anchor
	refs["left_paw"] = left_paw
	refs["right_paw"] = right_paw

	# 4. الفقاعات الهلامية اللامعة المعلقة داخل وحول حواف السلايم (Internal Glossy Bubbles)
	var bubbles_root := Node3D.new()
	bubbles_root.name = "InnerBubbles"
	visual_root.add_child(bubbles_root)

	var unit_bubble := SphereMesh.new()
	unit_bubble.radius = 1.0
	unit_bubble.height = 2.0
	unit_bubble.radial_segments = 16
	unit_bubble.rings = 10

	var bubble_specs: Array[Vector4] = [
		Vector4(-0.44, -0.26, 0.34, 0.068),
		Vector4(-0.14, -0.36, 0.48, 0.056),
		Vector4(0.45, -0.27, 0.33, 0.074),
		Vector4(0.32, -0.35, 0.42, 0.044),
		Vector4(-0.49, -0.05, 0.28, 0.036),
		Vector4(0.48, -0.06, 0.29, 0.038),
		Vector4(-0.34, 0.28, 0.32, 0.028),
		Vector4(0.30, 0.24, 0.34, 0.026),
		Vector4(0.16, -0.34, 0.49, 0.032),
		Vector4(-0.30, -0.33, 0.44, 0.034),
	]
	for b_idx in range(bubble_specs.size()):
		var spec: Vector4 = bubble_specs[b_idx]
		var b_inst := MeshInstance3D.new()
		b_inst.name = "Bubble_%d" % b_idx
		b_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b_inst.mesh = unit_bubble
		b_inst.position = Vector3(spec.x, spec.y, spec.z)
		b_inst.scale = Vector3.ONE * spec.w
		b_inst.material_override = bubble_mat
		bubbles_root.add_child(b_inst)

	refs["bubbles_root"] = bubbles_root
	return refs


static func _create_glossy_jelly_part_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, unshaded;

void fragment() {
	vec3 n = normalize(FRONT_FACING ? NORMAL : -NORMAL);
	vec3 v = normalize(VIEW);
	float ndotv = clamp(dot(n, v), 0.0, 1.0);
	float rim = pow(1.0 - ndotv, 1.95);
	vec3 core_pink = vec3(1.0, 0.72, 0.87);
	vec3 edge_pink = vec3(0.97, 0.38, 0.69);
	vec3 col = mix(edge_pink, core_pink, smoothstep(0.12, 0.85, ndotv));
	col = mix(col, vec3(1.0, 0.95, 0.99), rim * 0.68);

	vec3 key = normalize(vec3(-0.42, 0.66, 0.62));
	float spec = smoothstep(0.92, 0.985, max(dot(n, normalize(key + v)), 0.0));
	float soft_spec = pow(max(dot(n, normalize(key + v)), 0.0), 18.0) * 0.32;
	col += vec3(1.0) * (spec * 0.95 + soft_spec);

	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
	ALPHA = clamp(0.76 + rim * 0.22 + spec * 0.24, 0.0, 0.98);
}
"""
	mat.shader = sh
	mat.render_priority = 2
	return mat


static func _create_knit_material(cols: float, rows: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/shaders/slime_knit_beanie.gdshader") as Shader
	mat.set_shader_parameter("rib_columns", cols)
	mat.set_shader_parameter("stitch_rows", rows)
	return mat


static func _create_bubble_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/shaders/slime_bubble.gdshader") as Shader
	mat.render_priority = 1
	return mat


static func _create_soft_unshaded_mat(lit_col: Color, shade_col: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;
uniform vec4 c_lit : source_color = vec4(1.0);
uniform vec4 c_shade : source_color = vec4(0.8, 0.8, 0.85, 1.0);
void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float l = clamp(dot(n, normalize(vec3(-0.35, 0.72, 0.58))) * 0.5 + 0.55, 0.0, 1.0);
	float rim = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 2.2) * 0.25;
	ALBEDO = clamp(mix(c_shade.rgb, c_lit.rgb, l) + vec3(rim), vec3(0.0), vec3(1.0));
}
"""
	mat.shader = sh
	mat.set_shader_parameter("c_lit", lit_col)
	mat.set_shader_parameter("c_shade", shade_col)
	return mat


static func _build_curved_antenna_stalk() -> ArrayMesh:
	var p0 := Vector3(0.0, -0.02, 0.0)
	var p1 := Vector3(-0.06, 0.24, 0.02)
	var p2 := Vector3(-0.25, 0.26, 0.04)
	var p3 := Vector3(-0.315, 0.06, 0.055)

	var steps: int = 18
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var omt: float = 1.0 - t
		var pt: Vector3 = (
			omt * omt * omt * p0
			+ 3.0 * omt * omt * t * p1
			+ 3.0 * omt * t * t * p2
			+ t * t * t * p3
		)
		pts.append(pt)
		radii.append(lerpf(0.052, 0.021, pow(t, 0.75)))

	return _extrude_variable_tube(pts, radii, 12)


static func _build_bean_paw_mesh() -> ArrayMesh:
	# كف هلامي ممتلئ بشكل حبة المارشملو/الفاصوليا اللطيفة كما في الصورة المرجعية
	var steps: int = 14
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		var ang: float = lerpf(-0.95, 0.95, u)
		var x: float = sin(ang) * 0.105
		var y: float = cos(ang) * 0.036 - 0.02
		var z: float = cos(ang * 0.8) * 0.018
		pts.append(Vector3(x, y, z))
		var profile: float = sin(clampf(u, 0.04, 0.96) * PI)
		radii.append(0.018 + 0.052 * pow(profile, 0.58))
	return _extrude_variable_tube(pts, radii, 14)


static func _build_plump_five_star_mesh(outer_r: float, inner_r: float, half_thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ring_pts: Array[Vector3] = []
	for i in range(10):
		var angle: float = -PI * 0.5 + float(i) * (TAU / 10.0)
		var r: float = outer_r if (i % 2 == 0) else inner_r
		ring_pts.append(Vector3(cos(angle) * r, -sin(angle) * r, 0.0))

	var front_center := Vector3(0.0, 0.0, half_thick)
	var back_center := Vector3(0.0, 0.0, -half_thick)

	for i in range(10):
		var a: Vector3 = ring_pts[i]
		var b: Vector3 = ring_pts[(i + 1) % 10]

		var fn: Vector3 = (b - a).cross(front_center - a).normalized()
		if fn.z < 0.0:
			fn = -fn
		st.set_normal(Vector3(0.0, 0.0, 1.0))
		st.add_vertex(front_center)
		st.set_normal(fn)
		st.add_vertex(a)
		st.set_normal(fn)
		st.add_vertex(b)

		var bn: Vector3 = (a - b).cross(back_center - b).normalized()
		if bn.z > 0.0:
			bn = -bn
		st.set_normal(Vector3(0.0, 0.0, -1.0))
		st.add_vertex(back_center)
		st.set_normal(bn)
		st.add_vertex(b)
		st.set_normal(bn)
		st.add_vertex(a)

	return st.commit()


static func _build_plump_heart_mesh(scale_size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segs: int = 24
	var outline: Array[Vector3] = []
	for i in range(segs):
		var t: float = TAU * float(i) / float(segs)
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		outline.append(Vector3(x, y, 0.0) * (scale_size / 17.0))

	var f_c := Vector3(0.0, 0.0, scale_size * 0.42)
	var b_c := Vector3(0.0, 0.0, -scale_size * 0.35)
	for i in range(segs):
		var a: Vector3 = outline[i]
		var b: Vector3 = outline[(i + 1) % segs]
		st.set_normal(Vector3(0.0, 0.0, 1.0))
		st.add_vertex(f_c)
		st.set_normal(a.normalized() + Vector3(0.0, 0.0, 0.6))
		st.add_vertex(a)
		st.set_normal(b.normalized() + Vector3(0.0, 0.0, 0.6))
		st.add_vertex(b)

		st.set_normal(Vector3(0.0, 0.0, -1.0))
		st.add_vertex(b_c)
		st.set_normal(b.normalized() + Vector3(0.0, 0.0, -0.6))
		st.add_vertex(b)
		st.set_normal(a.normalized() + Vector3(0.0, 0.0, -0.6))
		st.add_vertex(a)

	return st.commit()


static func _extrude_variable_tube(points: PackedVector3Array, radii: PackedFloat32Array, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = points.size()
	if count < 2:
		return ArrayMesh.new()

	var rings: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	for i in range(count):
		var prev_i: int = maxi(0, i - 1)
		var next_i: int = mini(count - 1, i + 1)
		var tang: Vector3 = (points[next_i] - points[prev_i]).normalized()
		if tang.length_squared() < 0.001:
			tang = Vector3.UP
		var ref_up := Vector3.FORWARD if absf(tang.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
		var na: Vector3 = tang.cross(ref_up).normalized()
		var nb: Vector3 = tang.cross(na).normalized()

		var r_v := PackedVector3Array()
		var r_n := PackedVector3Array()
		var rad: float = radii[i]
		for s in range(sides):
			var th: float = TAU * float(s) / float(sides)
			var d: Vector3 = (na * cos(th) + nb * sin(th)).normalized()
			r_v.append(points[i] + d * rad)
			r_n.append(d)
		rings.append(r_v)
		norms.append(r_n)

	for i in range(count - 1):
		for s in range(sides):
			var ns: int = (s + 1) % sides
			st.set_normal(norms[i][s]); st.add_vertex(rings[i][s])
			st.set_normal(norms[i + 1][s]); st.add_vertex(rings[i + 1][s])
			st.set_normal(norms[i + 1][ns]); st.add_vertex(rings[i + 1][ns])

			st.set_normal(norms[i][s]); st.add_vertex(rings[i][s])
			st.set_normal(norms[i + 1][ns]); st.add_vertex(rings[i + 1][ns])
			st.set_normal(norms[i][ns]); st.add_vertex(rings[i][ns])

	# Smooth rounded end caps
	var start_c: Vector3 = points[0]
	var end_c: Vector3 = points[count - 1]
	for s in range(sides):
		var ns: int = (s + 1) % sides
		st.set_normal(-((points[1] - points[0]).normalized()))
		st.add_vertex(start_c)
		st.set_normal(norms[0][ns]); st.add_vertex(rings[0][ns])
		st.set_normal(norms[0][s]); st.add_vertex(rings[0][s])

		st.set_normal((points[count - 1] - points[count - 2]).normalized())
		st.add_vertex(end_c)
		st.set_normal(norms[count - 1][s]); st.add_vertex(rings[count - 1][s])
		st.set_normal(norms[count - 1][ns]); st.add_vertex(rings[count - 1][ns])

	return st.commit()

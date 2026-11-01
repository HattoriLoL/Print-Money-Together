extends RefCounted
## Pastelão da frigideira (o golpe fica em player.gd): as estrelinhas girando em volta da cabeça
## de quem levou, o "BONK!" de gibi no lugar da pancada e os sons, todos feitos aqui mesmo.

## Estrelinhas: quantas, o raio da roda em volta da cabeça e a velocidade do giro.
const STAR_COUNT := 5
const STAR_RING := 0.2
const STAR_SPIN := 4.5
const STAR_COLOR := Color(1.0, 0.85, 0.15)
## Quanto o "BONK!" fica na tela (s).
const POPUP_TIME := 0.8
const RATE := 22050

static var _cache := {}


## A roda de estrelinhas (top level: quem usa põe ela na cabeça a cada quadro com place_stars).
static func make_stars() -> Node3D:
	var root := Node3D.new()
	root.name = "Stars"
	root.top_level = true
	root.visible = false
	for i in STAR_COUNT:
		var star := MeshInstance3D.new()
		star.mesh = _star_mesh()
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(star)
	return root


## Põe a roda girando em volta de `head` (no mundo), com um balanço de bêbado.
static func place_stars(stars: Node3D, head: Vector3, time: float) -> void:
	stars.global_position = head + Vector3.UP * (0.16 + 0.02 * sin(time * 3.0))
	var n := stars.get_child_count()
	for i in n:
		var a := time * STAR_SPIN + i * TAU / n
		var star: Node3D = stars.get_child(i)
		star.position = Vector3(cos(a) * STAR_RING, 0.04 * sin(a * 2.0 + i), sin(a) * STAR_RING)
		star.scale = Vector3.ONE * (0.85 + 0.25 * sin(time * 9.0 + i * 1.7))


## "BONK!" de gibi em `pos`: cresce de repente, treme e some. Vai para `parent` e se apaga sozinho.
static func popup(parent: Node, pos: Vector3, text := "BONK!") -> Label3D:
	var label := Label3D.new()
	label.name = "Bonk"
	label.text = text
	label.font_size = 120
	label.pixel_size = 0.0018
	label.outline_size = 36
	label.modulate = STAR_COLOR
	label.outline_modulate = Color(0.08, 0.05, 0.03)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.outline_render_priority = 9
	parent.add_child(label)
	label.global_position = pos + Vector3.UP * 0.25
	label.rotation.z = randf_range(-0.3, 0.3)
	label.scale = Vector3.ONE * 0.2
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE * 1.25, 0.08)
	tween.tween_property(label, "scale", Vector3.ONE, 0.1)
	tween.parallel().tween_property(label, "global_position", label.global_position + Vector3.UP * 0.15, POPUP_TIME)
	tween.tween_property(label, "modulate:a", 0.0, 0.25).set_delay(POPUP_TIME - 0.45)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.25).set_delay(POPUP_TIME - 0.45)
	tween.tween_callback(label.queue_free)
	return label


## Toca um dos sons (bonk, clang, swoosh) em `pos`, num tocador que se apaga quando acaba.
static func play(parent: Node, sound: String, pos: Vector3) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = _sound(sound)
	player.unit_size = 5.0
	player.pitch_scale = randf_range(0.93, 1.07)
	parent.add_child(player)
	player.global_position = pos
	player.finished.connect(player.queue_free)
	player.play()


## Estrela de 5 pontas chapada, amarela e sem luz, sempre virada para a câmera.
static func _star_mesh() -> Mesh:
	if _cache.has("star"):
		return _cache["star"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i in 10:
		var r := 0.045 if i % 2 == 0 else 0.019
		var a := PI / 2.0 + i * TAU / 10.0
		pts.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	for i in 10:
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(pts[i])
		st.add_vertex(pts[(i + 1) % 10])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = STAR_COLOR
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	var mesh := st.commit()
	_cache["star"] = mesh
	return mesh


static func _sound(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var rng := RandomNumberGenerator.new()
	rng.seed = sound.hash()
	var samples := PackedFloat32Array()
	match sound:
		"bonk":
			# Ferro fundido: parciais fora da série (sino grave) e o baque surdo da cabeça.
			for i in int(RATE * 0.9):
				var t := float(i) / RATE
				var ring := 0.45 * sin(TAU * 196.0 * t) * exp(-t * 4.0) + 0.3 * sin(TAU * 463.0 * t) * exp(-t * 6.0) \
						+ 0.2 * sin(TAU * 817.0 * t) * exp(-t * 9.0) + 0.12 * sin(TAU * 1290.0 * t) * exp(-t * 14.0)
				var thud := 0.8 * sin(TAU * 80.0 * t) * exp(-t * 25.0)
				var hit := 0.5 * rng.randf_range(-1.0, 1.0) * exp(-t * 120.0)
				samples.append(ring + thud + hit)
		"clang":
			# Frigideira na parede ou na mesa: mais curto e mais agudo.
			for i in int(RATE * 0.5):
				var t := float(i) / RATE
				samples.append(0.35 * sin(TAU * 520.0 * t) * exp(-t * 9.0) + 0.25 * sin(TAU * 1210.0 * t) * exp(-t * 14.0)
						+ 0.45 * rng.randf_range(-1.0, 1.0) * exp(-t * 90.0))
		"swoosh":
			# O ar cortado: ruído filtrado que sobe e desce.
			var low := 0.0
			var n := int(RATE * 0.28)
			for i in n:
				var t := float(i) / n
				low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.15 + 0.3 * t)
				samples.append(low * 1.6 * sin(PI * t) * sin(PI * t))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 24000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	_cache[sound] = wav
	return wav

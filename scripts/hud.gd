extends CanvasLayer
## Interface do jogador local: mira, aviso de interação, quem está na sala, mensagens, dicas
## de controle e o menu do Esc (o jogo não pausa: é multiplayer).

var _prompt: Label
var _message: Label
var _hint: Label
var _roster: VBoxContainer
var _pause: Control
var _capture_hint: Label
var _carry: Label
var _money: Label
var _throw_back: ColorRect
var _throw_bar: ColorRect
var _message_tween: Tween
var _hint_tween: Tween
var _poll := 0.0


func _ready() -> void:
	var crosshair := ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.75)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE  # fica bem embaixo do cursor preso
	_place(crosshair, Vector2(0.5, 0.5), Rect2(-2, -2, 4, 4))

	_capture_hint = _label(22)
	_capture_hint.text = "Click to look around"
	_capture_hint.visible = false
	_place(_capture_hint, Vector2(0.5, 0.5), Rect2(-300, -70, 600, 34))

	_prompt = _label(18)
	_place(_prompt, Vector2(0.5, 0.5), Rect2(-300, 22, 600, 30))

	_message = _label(30)
	_message.modulate.a = 0.0
	_place(_message, Vector2(0.5, 0.3), Rect2(-500, -60, 1000, 120))

	# No canto de baixo à esquerda: no meio ficaria em cima do que está na mão.
	_carry = _label(17)
	_carry.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(_carry, Vector2(0.0, 1.0), Rect2(20, -48, 500, 26))

	_throw_back = ColorRect.new()
	_throw_back.color = Color(0, 0, 0, 0.45)
	_throw_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_throw_back.visible = false
	_place(_throw_back, Vector2(0.5, 0.5), Rect2(-50, 52, 100, 8))
	_throw_bar = ColorRect.new()
	_throw_bar.color = Color(1.0, 0.8, 0.25, 0.9)
	_throw_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_throw_bar.position = Vector2(1, 1)
	_throw_bar.size = Vector2(0, 6)
	_throw_back.add_child(_throw_bar)

	_hint = _label(14)
	_hint.modulate.a = 0.0
	_place(_hint, Vector2(0.5, 1.0), Rect2(-500, -40, 1000, 24))

	# Dinheiro do grupo, no canto de cima à direita.
	_money = _label(22)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	_place(_money, Vector2(1.0, 0.0), Rect2(-220, 14, 200, 30))

	_roster = VBoxContainer.new()
	_roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_roster, Vector2(0.0, 0.0), Rect2(16, 14, 260, 120))

	_build_pause()


func _process(delta: float) -> void:
	_capture_hint.visible = not _pause.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		_update_roster()
	var kitnet := get_tree().get_first_node_in_group("kitnet")
	if kitnet != null and kitnet.wallet != null:
		_money.text = "$%d" % kitnet.wallet.cash


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_paused(not _pause.visible)
		get_viewport().set_input_as_handled()


## O clique que prende o mouse vem em _input: nenhum Control na frente pode engolir.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _pause.visible \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


## A janela perdeu o foco (Alt+Tab, jogo embutido no editor) e o Windows soltou o mouse:
## ao voltar, prende de novo se o menu do Esc não estiver aberto.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _pause != null and not _pause.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Com o menu do Esc aberto o jogador não anda nem olha.
func is_blocking() -> bool:
	return _pause.visible


func set_paused(open: bool) -> void:
	_pause.visible = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func set_prompt(text: String) -> void:
	_prompt.text = text


## Força do arremesso sendo carregada, de 0 a 1 (negativo = esconde a barra).
func set_throw(charge: float) -> void:
	_throw_back.visible = charge >= 0.0
	if charge >= 0.0:
		_throw_bar.size.x = 98.0 * charge
		_throw_bar.color = Color(1.0, 0.8 - 0.5 * charge, 0.25 - 0.15 * charge, 0.9)


## O que o jogador está carregando ("" = mãos vazias).
func set_carry(text: String) -> void:
	_carry.text = text


func show_message(text: String, seconds := 3.0) -> void:
	_message.text = text
	if _message_tween:
		_message_tween.kill()
	_message.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(seconds)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.8)


func show_hint(text: String, seconds := 8.0) -> void:
	_hint.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint.modulate.a = 0.75
	_hint_tween = create_tween()
	_hint_tween.tween_interval(seconds)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 1.5)


func _update_roster() -> void:
	var kitnet := get_tree().get_first_node_in_group("kitnet")
	if kitnet == null:
		return
	for child in _roster.get_children():
		child.queue_free()
	var ids: Array = kitnet.roster.keys()
	ids.sort_custom(func(a, b): return kitnet.roster[a]["slot"] < kitnet.roster[b]["slot"])
	for id in ids:
		var entry: Dictionary = kitnet.roster[id]
		var l := _label(15)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.text = "● " + entry["name"] + ("  (host)" if id == 1 and Net.is_online() else "")
		l.add_theme_color_override("font_color", Net.PLAYER_COLORS[entry["slot"]].lightened(0.25))
		_roster.add_child(l)


func _build_pause() -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0, 0, 0, 0.6)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(260, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := _label(26)
	title.text = "PAUSED"
	box.add_child(title)
	var note := _label(13)
	note.text = "The game keeps running for everyone else."
	note.modulate.a = 0.7
	box.add_child(note)
	for item in [["Resume", set_paused.bind(false)], ["Leave room", Net.leave]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(item[1])
		box.add_child(b)


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _place(control: Control, anchor: Vector2, rect: Rect2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y
	add_child(control)

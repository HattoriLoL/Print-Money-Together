extends Control
## Menu principal: nome, hospedar, entrar por IP e sair.
##
## Pela linha de comando (testes e duas janelas no mesmo PC):
##   godot --path . -- --solo
##   godot --path . -- --host --name=Ana
##   godot --path . -- --join=127.0.0.1 --name=Bia

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	Net.join_failed.connect(_on_join_failed)
	if not Net.last_message.is_empty():
		_status.text = Net.last_message
		Net.last_message = ""
	_auto_start.call_deferred()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.1, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "PRINT MONEY TOGETHER"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.62, 0.85, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Co-op counterfeiting for up to %d friends" % Net.MAX_PLAYERS
	subtitle.modulate.a = 0.7
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(HSeparator.new())

	_name_edit = _field(box, "Your name", Net.player_name)
	_name_edit.max_length = 16
	_buttons.append(_button(box, "Play solo", _on_solo))
	_buttons.append(_button(box, "Host a room", _on_host))
	_ip_edit = _field(box, "Host IP", "127.0.0.1")
	_buttons.append(_button(box, "Join", _on_join))
	_buttons.append(_button(box, "Quit", get_tree().quit))

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	box.add_child(_status)


func _field(parent: Control, label: String, value: String) -> LineEdit:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	parent.add_child(row)
	return edit


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _auto_start() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--name="):
			_name_edit.text = arg.get_slice("=", 1)
	for arg in OS.get_cmdline_user_args():
		if arg == "--solo":
			_on_solo()
		elif arg == "--host":
			_on_host()
		elif arg.begins_with("--join="):
			_ip_edit.text = arg.get_slice("=", 1)
			_on_join()


func _apply_name() -> void:
	var n := _name_edit.text.strip_edges()
	Net.player_name = n if not n.is_empty() else "Player"


func _on_solo() -> void:
	_apply_name()
	Net.play_solo()


func _on_host() -> void:
	_apply_name()
	var err := Net.host()
	if err != OK:
		_status.text = "Could not open the room on port %d (%s)." % [Net.PORT, error_string(err)]


func _on_join() -> void:
	_apply_name()
	var err := Net.join(_ip_edit.text.strip_edges())
	if err != OK:
		_status.text = "Invalid address (%s)." % error_string(err)
		return
	_status.text = "Connecting to %s..." % _ip_edit.text
	for b in _buttons:
		b.disabled = true


func _on_join_failed(reason: String) -> void:
	_status.text = reason
	for b in _buttons:
		b.disabled = false

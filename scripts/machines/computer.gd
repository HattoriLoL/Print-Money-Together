extends Node3D
## O PC velho da escrivaninha (filho do MACHINE_PC do kitnet.glb; o referencial é o do modelo, com a
## frente, onde fica quem usa, para +Z). É por ele que o grupo compra papel e tinta na internet: a
## tela mostra um navegador de 1998 (scripts/shop/browser.gd, num SubViewport) com as lojas do
## catálogo (scripts/shop/catalog.gd), e o pedido chega numa caixa na porta (scripts/shop/
## deliveries.gd), pago com o dinheiro do grupo (scripts/wallet.gd).
##
##   [E] de mão vazia: senta para usar. Só um por vez.
##
## Usando, a câmera vai para a frente do monitor, a mão esquerda fica no teclado e a direita no
## mouse (os outros veem). O mouse anda com o cursor na tela, o clique aperta o que estiver embaixo
## dele e [E] sai.
##
## Rede: o host guarda o estado (quem usa, a página, o carrinho, o aviso e os últimos pedidos) e
## repassa. Quem usa mexe o cursor na hora e manda a posição para os outros (dá para olhar por cima
## do ombro); o clique vai com a posição para o host, que decide o que ele apertou.

const InteractZone := preload("res://scripts/interact_zone.gd")
const Browser := preload("res://scripts/shop/browser.gd")
const Catalog := preload("res://scripts/shop/catalog.gd")
const CRT_SHADER := preload("res://shaders/crt.gdshader")

## Resolução da tela (o navegador é desenhado nela).
const SCREEN_SIZE := Vector2i(640, 480)
## Medidas do modelo (art_source/blender/machines.py, PC_SCREEN; y do Blender = -z): o meio da tela.
const SCREEN_CENTER := Vector3(0.0, 0.213, 0.1875)
## Câmera de quem usa: na frente da tela, um pouco acima do meio, e o campo de visão.
const VIEW_FROM := Vector3(0.0, 0.235, 0.54)
const VIEW_FOV := 40.0
## Onde quem usa fica em pé (no chão, na frente da escrivaninha).
const STAND := Vector3(0.0, -0.75, 0.75)
## Pixels de cursor por pixel de mouse.
const CURSOR_SPEED := 0.8
## Quanto o mouse anda na mesa de uma ponta da tela à outra (m, para os lados e para a frente).
const MOUSE_TRAVEL := Vector2(0.05, 0.035)
## Pulso da luva esquerda em cima do teclado, e o da direita em relação ao mouse.
const KEYBOARD_WRIST := Vector3(-0.07, 0.052, 0.36)
const MOUSE_WRIST := Vector3(0.0, 0.046, 0.085)
## Quantas vezes por segundo quem usa manda a posição do cursor.
const CURSOR_RATE := 30.0

var operator := 0
var page := "office"
## product_id -> quantidade.
var cart := {}
var notice := ""
var receipt: Array = []
var zone: Area3D
var browser: Control

var _kitnet: Node
var _viewport: SubViewport
var _mouse: Node3D
var _mouse_rest := Vector3.ZERO
var _operating_player: Node = null
var _cursor := Vector2(SCREEN_SIZE) / 2.0
var _cursor_target := Vector2(SCREEN_SIZE) / 2.0
var _send_timer := 0.0
var _cursor_dirty := false
var _click_sound: AudioStreamPlayer3D


func _ready() -> void:
	name = "Computer"
	add_to_group("station")
	_kitnet = get_tree().get_first_node_in_group("kitnet")
	var model := get_parent()
	_mouse = model.find_child("MACHINE_PC_Mouse", false, false)
	if _mouse:
		_mouse_rest = _mouse.position

	_viewport = SubViewport.new()
	_viewport.name = "Screen"
	_viewport.size = SCREEN_SIZE
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	browser = Browser.new()
	browser.setup(_kitnet)
	_viewport.add_child(browser)

	var screen: MeshInstance3D = model.find_child("MACHINE_PC_Screen", false, false)
	if screen:
		var mat := ShaderMaterial.new()
		mat.shader = CRT_SHADER
		mat.set_shader_parameter("screen_tex", _viewport.get_texture())
		screen.material_override = mat
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	zone = InteractZone.new()
	zone.setup(self, "Zone_PC", Vector3(0.0, 0.2, 0.15), Vector3(0.44, 0.42, 0.5))
	zone.prompt_fn = _prompt
	zone.press_fn = _press
	_build_click_sound()


func _process(delta: float) -> void:
	if not _is_mine():
		_cursor = _cursor.lerp(_cursor_target, clampf(20.0 * delta, 0.0, 1.0))
	browser.cursor = _cursor
	if _mouse:
		var t := _cursor / Vector2(SCREEN_SIZE) - Vector2(0.5, 0.5)
		_mouse.position = _mouse_rest + Vector3(t.x * MOUSE_TRAVEL.x, 0.0, t.y * MOUSE_TRAVEL.y)
	if _is_mine() and _cursor_dirty:
		_send_timer -= delta
		if _send_timer <= 0.0:
			_send_timer = 1.0 / CURSOR_RATE
			_cursor_dirty = false
			_kitnet.rpc_roster(self, &"_remote_cursor", [_cursor])


# --- Host -------------------------------------------------------------------------------------

func _press(peer: int) -> void:
	if operator != 0 or _kitnet.items.held_by(peer) != null:
		return
	operator = peer
	notice = ""
	_send_state()


## Host: o clique de quem usa, em `pos` (pixels da tela).
func _click(peer: int, pos: Vector2) -> void:
	if peer != operator:
		return
	browser.cursor = pos
	_apply(browser.action_at(pos))
	_send_state()


func _apply(action: String) -> void:
	var verb := action.get_slice(":", 0)
	var arg := action.get_slice(":", 1)
	match verb:
		"go":
			page = arg
			notice = ""
		"add", "inc":
			if Catalog.can_buy(arg):
				cart[arg] = mini(int(cart.get(arg, 0)) + 1, Catalog.MAX_PER_PRODUCT)
				notice = "Added to cart: %s" % Catalog.PRODUCTS[arg]["name"] if verb == "add" else ""
		"dec":
			if cart.has(arg):
				cart[arg] = int(cart[arg]) - 1
				if cart[arg] <= 0:
					cart.erase(arg)
			notice = ""
		"checkout":
			if Catalog.count(cart) == 0:
				return
			var total := Catalog.total(cart)
			if not _kitnet.wallet.spend(total):
				notice = "Payment declined: not enough money."
				return
			receipt = _kitnet.deliveries.order(cart)
			cart = {}
			page = "done"
			notice = "Paid $%d. Thank you!" % total


func _leave(peer: int) -> void:
	if operator == peer:
		operator = 0
		_send_state()


func drop_peer(peer: int) -> void:
	_leave(peer)


func _send_state() -> void:
	var args := [operator, page, cart, notice, receipt]
	_sync.callv(args)
	_kitnet.rpc_roster(self, &"_sync", args)


func send_state_to(peer: int) -> void:
	_sync.rpc_id(peer, operator, page, cart, notice, receipt)


# --- Quem usa -----------------------------------------------------------------------------------

func is_operated_by(player: Node) -> bool:
	return operator != 0 and player != null and player.name.to_int() == operator


## Mouse e clique de quem usa (o player.gd repassa enquanto `operating` é este PC).
func station_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_cursor = (_cursor + event.relative * CURSOR_SPEED).clamp(Vector2.ZERO, Vector2(SCREEN_SIZE) - Vector2.ONE)
		_cursor_dirty = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		request_click()


func station_hint() -> String:
	return "Mouse: move the pointer · Click: click · E: leave"


func request_click() -> void:
	_play_click()
	_kitnet.rpc_roster(self, &"_remote_click", [])
	if multiplayer.is_server():
		_click(multiplayer.get_unique_id(), _cursor)
	else:
		_rpc_click.rpc_id(1, _cursor)


func request_leave() -> void:
	if multiplayer.is_server():
		_leave(multiplayer.get_unique_id())
	else:
		_rpc_leave.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_click(pos: Vector2) -> void:
	if multiplayer.is_server():
		_click(multiplayer.get_remote_sender_id(), pos)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_leave() -> void:
	if multiplayer.is_server():
		_leave(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _remote_cursor(pos: Vector2) -> void:
	if multiplayer.get_remote_sender_id() == operator:
		_cursor_target = pos


@rpc("any_peer", "call_remote", "unreliable")
func _remote_click() -> void:
	if multiplayer.get_remote_sender_id() == operator:
		_play_click()


# --- Aplicado em todas as máquinas ------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _sync(op: int, new_page: String, new_cart: Dictionary, new_notice: String, new_receipt: Array) -> void:
	page = new_page
	cart = new_cart.duplicate()
	notice = new_notice
	receipt = new_receipt.duplicate()
	if op != operator:
		# Quem senta encontra o cursor no meio da tela.
		_cursor = Vector2(SCREEN_SIZE) / 2.0
		_cursor_target = _cursor
	operator = op
	browser.page = page
	browser.cart = cart
	browser.notice = notice
	browser.receipt = receipt
	browser.render()
	var now: Node = _kitnet.players.get(op) if op != 0 else null
	if now != _operating_player:
		if is_instance_valid(_operating_player) and _operating_player.operating == self:
			_operating_player.operating = null
		_operating_player = now
		if now != null:
			now.operating = self


func _is_mine() -> bool:
	return operator != 0 and operator == multiplayer.get_unique_id()


func _prompt(player: Node) -> String:
	if operator != 0:
		if is_operated_by(player):
			return ""
		return "%s is using the computer" % _kitnet.roster.get(operator, {}).get("name", "Someone")
	if player.held_item() != null:
		return "Put down what you're holding to use the computer"
	return "[E] Use the computer"


func _play_click() -> void:
	if _click_sound and _mouse:
		_click_sound.global_position = _mouse.global_position
		_click_sound.play()


## O clique do mouse, feito aqui mesmo: um estalinho seco de plástico.
func _build_click_sound() -> void:
	const RATE := 22050
	var count := int(RATE * 0.04)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 98
	for i in count:
		var t := float(i) / RATE
		var s := rng.randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.6 + sin(TAU * 3200.0 * t) * exp(-t * 250.0) * 0.4
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 20000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	_click_sound = AudioStreamPlayer3D.new()
	_click_sound.name = "ClickSound"
	_click_sound.stream = wav
	_click_sound.unit_size = 1.5
	add_child(_click_sound)


# --- Câmera e mãos de quem usa ---------------------------------------------------------------

## Câmera de quem usa: na frente da tela, olhando para o meio dela.
func view_transform() -> Transform3D:
	var from := global_transform * VIEW_FROM
	return Transform3D(Basis.IDENTITY, from).looking_at(global_transform * SCREEN_CENTER, global_basis.y)


## Onde fica a luva aberta de quem usa (side 1 = direita, no mouse; -1 = esquerda, no teclado). A
## luva tem os dedos para -Z e a palma para baixo; as duas viram um pouco para dentro.
func hand_transform(side: int) -> Transform3D:
	var local: Transform3D
	if side > 0 and _mouse:
		local = Transform3D(Basis(Vector3.UP, 0.12), _mouse.position + MOUSE_WRIST)
	else:
		local = Transform3D(Basis(Vector3.UP, -0.25), KEYBOARD_WRIST)
	return global_transform * local


func hand_bend() -> float:
	return 0.0


func stand_point() -> Vector3:
	return global_transform * STAND


func stand_yaw() -> float:
	return global_basis.get_euler().y

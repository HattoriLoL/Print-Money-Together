extends SceneTree
## Teste da kitnet (scenes/kitnet.tscn) com o jogador de verdade, hospedando uma sala:
## - o modelo carrega com 5 portas (3 trancadas), 4 spawns e as luzes das zonas;
## - o jogador nasce em pé no chão e a colisão segura (andar até a parede do fundo);
## - a porta 301 abre com interact e a trancada não;
## - impressora: pegar resma, carregar, ligar no botão, esquentar, imprimir sozinha, desligar,
##   pegar e soltar a folha;
## - com --solo, entra sozinho sem rede (o botão "Play solo") em vez de hospedar;
## - com --client, abre uma segunda janela que entra na sala e confere que ela aparece e se mexe.
## Prints de alguns pontos de vista na pasta --out (rode com janela, sem --headless).
##
##   godot --path . --resolution 1280x720 --script res://tools/tests/test_kitnet.gd -- --out=<pasta> [--solo | --client]
##
## Termina com "TESTE OK" ou com a lista do que falhou.

var _out := ""
var _with_client := false
var _solo := false
var _started := false
var _failures: Array[String] = []


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg == "--client":
			_with_client = true
		elif arg == "--solo":
			_solo = true
	if _out.is_empty():
		_out = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var net: Node = root.get_node_or_null("Net")
	_check(net != null, "autoload Net existe")
	if net == null:
		_finish()
		return
	net.player_name = "Tester"
	if _solo:
		net.play_solo()
		_check(not net.is_online(), "sozinho, sem rede")
	else:
		_check(net.host() == OK, "abre a sala na porta %d" % net.PORT)
	var kitnet: Node3D = null
	while kitnet == null or kitnet.local_player() == null:
		await process_frame
		kitnet = get_first_node_in_group("kitnet")
	var player: CharacterBody3D = kitnet.local_player()
	await create_timer(1.0).timeout

	# --- Montagem ---
	_check(kitnet.doors.size() == 5, "5 portas (%d)" % kitnet.doors.size())
	for key in ["302", "303", "Stairs"]:
		_check(kitnet.doors.has(key) and kitnet.doors[key].locked, "porta %s trancada" % key)
	_check(not kitnet.doors["301"].locked and not kitnet.doors["Bath"].locked, "301 e banheiro abrem")
	_check(kitnet.spawns.size() == 4, "4 spawns")
	var lights: Array = kitnet.model.find_children("LIGHT_*", "Light3D", true, false)
	_check(lights.size() == 6, "6 luzes (%d)" % lights.size())
	_check(kitnet.roster.size() == 1 and kitnet.roster.has(1), "o host está na lista")

	# --- Jogador no chão ---
	_check(player.is_on_floor() and absf(player.global_position.y) < 0.1,
			"o jogador está no chão (y %.2f)" % player.global_position.y)
	var spawn: Vector3 = kitnet.spawns[0].origin
	_check(player.global_position.distance_to(Vector3(spawn.x, player.global_position.y, spawn.z)) < 0.2,
			"nasceu no SPAWN_1")
	await _shot("01_spawn")

	# Olhar com o mouse de verdade (o evento passa pela interface antes de chegar ao jogador).
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "o mouse fica preso no jogo")
	var yaw_before := player.rotation.y
	var pitch_before: float = player.head.rotation.x
	for i in 10:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(20, 8)
		motion.position = root.get_visible_rect().size / 2.0
		Input.parse_input_event(motion)
		await process_frame
	_check(absf(player.rotation.y - yaw_before) > 0.1, "mexer o mouse para o lado gira o jogador (%.2f)" % (player.rotation.y - yaw_before))
	_check(absf(player.head.rotation.x - pitch_before) > 0.05, "mexer o mouse para baixo abaixa o olhar")

	# Mouse solto (janela sem foco, como no jogo embutido no editor): clicar no meio da tela,
	# bem em cima da mira, tem que prender de novo.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = root.get_visible_rect().size / 2.0
		click.global_position = click.position
		Input.parse_input_event(click)
		await process_frame
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "clicar na mira prende o mouse de novo")

	# Andar para o fundo (-Z no Godot): a parede (z -5) segura.
	player.global_position = Vector3(4.2, 0.05, -2.0)
	player.rotation.y = 0.0
	Input.action_press("move_forward")
	await create_timer(2.5).timeout
	Input.action_release("move_forward")
	var z := player.global_position.z
	_check(z < -2.5, "andou para frente (z %.2f)" % z)
	_check(z > -5.0 + 0.3, "a parede do fundo segura (z %.2f)" % z)

	# Vistas.
	await _look(player, Vector3(4.3, 0, -0.6), Vector3(1.5, 0.9, -4.0), "02_da_entrada")
	await _look(player, Vector3(2.2, 0, -2.9), Vector3(2.2, 0.7, -4.6), "03_impressora")
	await _look(player, Vector3(3.9, 0, -3.0), Vector3(6.5, 1.6, -3.7), "04_servico")
	await _look(player, Vector3(1.8, 0, -1.4), Vector3(2.6, 1.0, -0.2), "05_cozinha")
	await _look(player, Vector3(5.4, 0, -0.4), Vector3(6.4, 0.8, -1.8), "08_banheiro")
	await _look(player, Vector3(9.2, 0, 0.85), Vector3(-1.5, 1.3, 1.3), "09_corredor")
	await _look(player, Vector3(2.5, 0, -3.6), Vector3(2.5, 0.2, -14.0), "10_janela")

	# --- Portas ---
	var door: AnimatableBody3D = kitnet.doors["301"]
	player.global_position = Vector3(4.1, 0.05, -1.0)
	await physics_frame
	door.interact(player)
	await create_timer(0.8).timeout
	_check(door.is_open, "a 301 abriu")
	var leaf_dir: Vector3 = door.global_basis.x
	_check(leaf_dir.z < -0.9, "a folha girou para dentro da kitnet (%s)" % leaf_dir)
	await _look(player, Vector3(4.1, 0, -1.2), Vector3(4.1, 1.2, 1.0), "06_porta_aberta")
	var locked: AnimatableBody3D = kitnet.doors["303"]
	locked.interact(player)
	await create_timer(0.6).timeout
	_check(not locked.is_open, "a 303 continua fechada")
	door.interact(player)
	await create_timer(0.8).timeout
	_check(not door.is_open, "a 301 fechou")

	await _test_printer(kitnet, player)

	if _with_client:
		await _test_client(kitnet)
	_finish()


## Segunda janela entrando na sala pelo menu (--join), como um amigo faria.
func _test_client(kitnet: Node3D) -> void:
	kitnet.doors["Bath"].interact(kitnet.local_player())
	var args := ["--path", ProjectSettings.globalize_path("res://"), "--resolution", "640x400",
			"--", "--join=127.0.0.1", "--name=Bot"]
	var pid := OS.create_process(OS.get_executable_path(), args)
	_check(pid > 0, "abriu a janela do cliente")
	var waited := 0.0
	while kitnet.roster.size() < 2 and waited < 30.0:
		await create_timer(0.25).timeout
		waited += 0.25
	_check(kitnet.roster.size() == 2, "o cliente entrou na sala (%d jogadores)" % kitnet.roster.size())
	if kitnet.roster.size() == 2:
		var bot_id: int = kitnet.roster.keys().filter(func(id): return id != 1)[0]
		_check(kitnet.roster[bot_id]["name"] == "Bot" and kitnet.roster[bot_id]["slot"] == 1,
				"o cliente é o Bot na vaga 2")
		var bot: CharacterBody3D = kitnet.players[bot_id]
		await create_timer(2.0).timeout
		_check(bot.global_position.distance_to(kitnet.spawns[1].origin) < 0.3,
				"o boneco do Bot está no SPAWN_2 (%s)" % bot.global_position)
		await _look(kitnet.local_player(), Vector3(1.5, 0, -1.8), kitnet.spawns[1].origin + Vector3.UP, "07_outro_jogador")
	OS.kill(pid)
	waited = 0.0
	while kitnet.roster.size() > 1 and waited < 40.0:
		await create_timer(0.25).timeout
		waited += 0.25
	_check(kitnet.roster.size() == 1, "quando o cliente fecha, ele sai da lista (%.1f s)" % waited)


func _test_printer(kitnet: Node3D, player: CharacterBody3D) -> void:
	var printer: Node3D = kitnet.printer
	var supply: Node3D = kitnet.paper_supply
	var items: Node = kitnet.items
	var stats: Resource = printer.stats
	_check(printer != null and supply != null, "impressora e resmas montadas")
	_check(not printer.powered and printer._screen_text() == "", "começa desligada, visor apagado")

	# Pegar uma resma.
	player.global_position = Vector3(3.3, 0.05, -4.0)
	await physics_frame
	var stock_before: int = supply.stock
	supply.zone.interact(player)
	await physics_frame
	var held: Node = player.held_item()
	_check(held != null and held.kind == "ream", "pegou uma resma")
	_check(supply.stock == stock_before - 1, "o estoque de resmas baixou")
	await _look(player, Vector3(3.0, 0, -2.6), Vector3(1.0, 1.2, -1.5), "10_resma_na_mao")
	var hands_ok: bool = player._hands.size() == 2 and player._hands.all(func(h): return h.visible)
	_check(hands_ok, "as luvas aparecem segurando a resma")

	# Carregar no alimentador de trás.
	player.global_position = Vector3(2.3, 0.05, -3.9)
	await physics_frame
	_check(printer._feeder_prompt(player).begins_with("[E] Load paper"), "o alimentador oferece carregar")
	printer.feeder_zone.interact(player)
	await physics_frame
	_check(player.held_item() == null, "a resma saiu da mão")
	_check(printer.paper == stats.sheets_per_ream, "o alimentador tem %d folhas" % printer.paper)
	await _look(player, Vector3(2.62, 0, -3.75), Vector3(2.3, 0.85, -4.7), "11_impressora_desligada")

	# Ligar: esquenta e imprime sozinha.
	var ink_before: float = printer.ink
	printer.power_zone.interact(player)
	await physics_frame
	_check(printer.powered and not printer.is_ready(), "ligou e está esquentando")
	_check(printer._screen_text().begins_with("WARMING UP"), "o visor mostra WARMING UP")
	await create_timer(stats.warmup_seconds + stats.seconds_per_sheet * 2.8).timeout
	_check(printer.printing(), "imprimindo sozinha depois de esquentar")
	await _look(player, Vector3(2.62, 0, -3.75), Vector3(2.3, 0.85, -4.6), "12_imprimindo")
	printer.power_zone.interact(player)
	await physics_frame
	_check(not printer.powered and printer.progress == 0.0, "desligou e a folha pela metade voltou")
	var sheets: Array = items.items.values().filter(func(i): return i.kind == "sheet")
	_check(sheets.size() == 2, "saíram 2 folhas (%d)" % sheets.size())
	_check(printer.paper == stats.sheets_per_ream - 2, "gastou 2 folhas de papel")
	_check(printer.ink < ink_before, "gastou toner")
	_check(sheets.all(func(i): return i.data.get("wet", false)), "as folhas saem molhadas")
	await create_timer(stats.seconds_per_sheet * 0.5).timeout
	var after: int = items.items.values().filter(func(i): return i.kind == "sheet").size()
	_check(after == 2, "desligada não imprime mais")

	# Pegar uma folha da bandeja e soltar no chão.
	var sheet: Node = sheets[0]
	player.global_position = Vector3(2.3, 0.05, -3.9)
	await physics_frame
	items.request_pickup(sheet.id)
	await physics_frame
	_check(player.held_item() == sheet, "pegou a folha")
	_check(not printer.output_slots.has(sheet.id), "a vaga da bandeja liberou")
	await _look(player, Vector3(2.3, 0, -3.4), Vector3(2.3, 0.4, -4.4), "13_folha_na_mao")
	await _look(player, Vector3(3.2, 0, -2.4), Vector3(0.5, 1.3, -1.8), "14_folha_contra_a_luz")
	player.global_position = Vector3(3.0, 0.05, -2.5)
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0
	await physics_frame
	player._drop_held()
	await create_timer(1.5).timeout
	_check(player.held_item() == null and sheet.holder == 0, "soltou a folha")
	_check(sheet.global_position.y < 0.1, "a folha caiu no chão (y %.2f)" % sheet.global_position.y)
	_check(not player._hands[0].visible, "de mão vazia as luvas somem")
	await _look(player, Vector3(3.0, 0, -2.0), sheet.global_position, "15_folha_no_chao")

	# Sem papel: o LED âmbar acende e o visor avisa.
	printer.paper = 0
	printer.powered = true
	printer.warm = stats.warmup_seconds
	await physics_frame
	_check(printer._screen_text() == "PAPER OUT", "sem papel o visor mostra PAPER OUT")
	printer.powered = false


func _look(player: CharacterBody3D, at: Vector3, target: Vector3, shot_name: String) -> void:
	player.global_position = at + Vector3.UP * 0.05
	await physics_frame
	var eye: Vector3 = player.head.global_position
	var dir := (target - eye).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	player.head.rotation.x = asin(clampf(dir.y, -1.0, 1.0))
	await create_timer(0.4).timeout
	await _shot(shot_name)


func _shot(shot_name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(shot_name + ".png"))


func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "FALHOU ") + what)
	if not ok:
		_failures.append(what)


func _finish() -> void:
	if _failures.is_empty():
		print("TESTE OK")
	else:
		print("FALHAS (%d):" % _failures.size())
		for f in _failures:
			print("  - " + f)
	quit(0 if _failures.is_empty() else 1)

extends SceneTree
## Teste da kitnet (scenes/kitnet.tscn) com o jogador de verdade, hospedando uma sala:
## - o modelo carrega com 5 portas (3 trancadas), 4 spawns e as luzes das zonas;
## - visual de desenho: o mapa com o material toon e a câmera com o contorno;
## - o jogador nasce em pé no chão e a colisão segura (andar até a parede do fundo);
## - a porta 301 abre com interact e a trancada não;
## - impressora: pegar resma, carregar, ligar no botão, esquentar, imprimir sozinha, desligar,
##   pegar e soltar a folha;
## - física ao soltar: a folha cai devagar balançando e pousa deitada, a resma cai rápido, o
##   arremesso carregado vai longe (a resma mais que a folha), andando se empurra a resma e o
##   que cai fora do mapa volta;
## - guilhotina: pôr a folha, cortar linha por linha (2 notas por corte no montinho da frente,
##   borradas se a folha estava molhada), somar no mesmo montinho e carregar o montinho;
## - etapa 3 do visual: prints da fita na impressora, jornal, retrato, geladeira, TV, pizza, trancas e lâmpada;
## - vida no cenário: ventilador girando, vento no varal e na cortina, chuvisco na TV, vapor na panela,
##   lâmpada piscando e balançando quando alguém passa perto;
## - detalhes da história: prints da ficha do fiscal, do jornal, do lixo de notas, das pegadas e da pizza;
## - bonecos: cada vaga com o acessório dela, andando (joelho dobrando), no ar e segurando (a mão chega
##   na luva pelo IK do braço), com print do elenco;
## - primeira pessoa: o próprio corpo aparece (sem a cabeça) e o braço chega na luva que segura;
## - empurra-empurra: encostados se afastam, quem vem andando empurra junto e o tronco balança; na
##   trombada o peito e a cabeça vêm atrasados, o corpo achata, a câmera dá um tranco e os passos
##   vão para o lado do empurrão;
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
	var wall: MeshInstance3D = kitnet.model.find_child("Walls_Kitnet", true, false)
	_check(wall != null and wall.get_surface_override_material(0) is ShaderMaterial, "o mapa ganhou o visual de desenho (toon)")
	_check(player.camera.get_node_or_null("Outline") != null, "a câmera tem o contorno preto")
	var ceiling: MeshInstance3D = kitnet.model.find_child("Ceiling", true, false)
	var ceiling_mat: Material = ceiling.get_surface_override_material(0) if ceiling != null else null
	_check(ceiling_mat is ShaderMaterial and is_equal_approx(ceiling_mat.get_shader_parameter("toon_full_light"), 0.25),
			"o teto aceita só parte da luz cheia (sem mancha clara em volta da lâmpada)")
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
	# Etapa 3 do visual: objetos novos e proporções exageradas.
	await _look(player, Vector3(2.2, 0, -3.65), Vector3(2.2, 0.92, -4.5), "20_fita_na_impressora")
	await _look(player, Vector3(2.5, 0, -3.3), Vector3(2.5, 1.5, -5.1), "21_jornal_na_janela")
	await _look(player, Vector3(2.0, 0, -3.4), Vector3(0.0, 1.7, -3.5), "22_retrato")
	await _look(player, Vector3(1.3, 0, -1.3), Vector3(0.4, 1.1, -0.4), "23_geladeira_gorducha")
	await _look(player, Vector3(3.5, 0, -3.3), Vector3(4.7, 0.9, -2.25), "24_tv_enorme")
	await _look(player, Vector3(3.6, 0, -3.2), Vector3(4.55, 0.1, -4.5), "25_caixas_de_pizza")
	await _look(player, Vector3(4.1, 0, -1.4), Vector3(4.1, 1.3, 0.1), "26_trancas_da_porta")
	await _look(player, Vector3(2.6, 0, -2.0), Vector3(2.6, 2.1, -2.7), "27_lampada_pelada")

	# --- Vida no cenário (scripts/ambience.gd) ---
	var amb: Node = kitnet.ambience
	var blades_before: Basis = amb.fan_blades.transform.basis
	await create_timer(0.2).timeout
	_check(not amb.fan_blades.transform.basis.is_equal_approx(blades_before), "as pás do ventilador giram")
	var clothes: GeometryInstance3D = kitnet.model.find_child("MACHINE_ClothesLine", true, false)
	var curtain: GeometryInstance3D = kitnet.model.find_child("Curtain_Main", true, false)
	_check(clothes.get_instance_shader_parameter("wind").x > 0.0 and curtain.get_instance_shader_parameter("wind").x > 0.0,
			"as folhas do varal e a cortina pegam vento")
	_check(amb.tv_material != null, "a TV mostra chuvisco")
	_check(amb.steam != null and amb.steam.emitting, "a panela de tinta solta vapor")
	var bulb_light: Light3D = kitnet.model.find_child("LIGHT_main_0", true, false)
	# O brilho de repouso (uma piscada sorteada pode estar acontecendo agora).
	var full_energy: float = amb.light_energy_full
	amb.flicker_now()
	await process_frame
	await process_frame
	_check(amb.bulb_level < 0.5 and bulb_light.light_energy < full_energy * 0.5,
			"a lâmpada pisca (brilho %.2f)" % amb.bulb_level)
	# Passar perto da lâmpada (na frente da mesa) balança o fio.
	for i in 40:
		player.global_position = Vector3(1.8 + i * 0.05, 0.05, -3.3)
		await physics_frame
	_check(amb.swing.length() > 0.02, "quem passa perto balança a lâmpada (%.3f rad)" % amb.swing.length())
	await _look(player, Vector3(2.6, 0, -2.0), Vector3(2.6, 2.1, -2.7), "31_lampada_balancando")
	await _look(player, Vector3(2.45, 0, -1.25), Vector3(2.45, 1.15, -0.24), "28_vapor_da_tinta")
	await _look(player, Vector3(3.6, 0, -2.25), Vector3(4.7, 0.9, -2.25), "29_tv_chuvisco")
	await _look(player, Vector3(4.3, 0, -3.5), Vector3(5.8, 1.9, -3.7), "30_varal_ao_vento")
	# Detalhes que contam a história.
	await _look(player, Vector3(4.2, 0, -4.0), Vector3(4.35, 1.62, -5.0), "32_ficha_do_fiscal")
	await _look(player, Vector3(2.5, 0, -4.0), Vector3(2.3, 1.6, -5.1), "33_jornal_de_perto")
	await _look(player, Vector3(2.0, 0, -3.6), Vector3(1.3, 0.15, -4.6), "34_lixo_de_notas")
	await _look(player, Vector3(2.9, 0, -0.75), Vector3(3.7, 0.0, -2.6), "35_pegadas_de_tinta")
	await _look(player, Vector3(1.5, 0, -3.9), Vector3(0.56, 0.62, -4.35), "36_pizza_aberta")

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
	await _test_drop_physics(kitnet, player)
	await _test_guillotine(kitnet, player)
	await _test_characters(kitnet, player)
	await _test_first_person(kitnet, player)
	await _test_push(kitnet, player)

	if _with_client:
		await _test_client(kitnet)
	_finish()


## Os bonecos (character_rig.gd) das 4 vagas lado a lado, sem o mapa: um parado, um andando, um
## no ar e um segurando a resma (braços esticados até as luvas).
func _test_characters(kitnet: Node3D, player: CharacterBody3D) -> void:
	var Rig := preload("res://scripts/character_rig.gd")
	var stage := Node3D.new()
	stage.name = "CharacterLineup"
	kitnet.add_child(stage)
	var sun := DirectionalLight3D.new()
	# A luz anda para -Z, como a câmera olha: pega a frente dos bonecos (que olham para ela).
	sun.rotation = Vector3(-0.6, 0.4, 0.0)
	sun.light_energy = 1.2
	stage.add_child(sun)
	var rigs: Array[Node3D] = []
	for i in 4:
		var rig: Node3D = Rig.new()
		rig.setup(i, Net.PLAYER_COLORS[i])
		stage.add_child(rig)
		rig.global_position = Vector3(1.15 + i * 0.85, 0.0, -4.2)
		rig.rotation.y = PI
		rigs.append(rig)
	var ok_acc := true
	for i in 4:
		var shown: Array = Rig.ACCESSORIES.filter(func(a): return rigs[i].model.find_child(a, true, false).visible)
		ok_acc = ok_acc and shown == [Rig.ACCESSORIES[i]]
	_check(ok_acc, "cada vaga mostra só o acessório dela (boné, óculos, topete, gorro)")
	kitnet.model.visible = false
	var max_leg := 0.0
	var max_knee := 0.0
	var walk_dir: Vector3 = -rigs[1].global_basis.z
	for f in 50:
		var dt := 1.0 / 60.0
		rigs[0].animate(dt, Vector3.ZERO, false, 0.0)
		rigs[1].animate(dt, walk_dir * 2.8, false, 0.0)
		rigs[2].animate(dt, Vector3.ZERO, true, 0.3)
		var hold: Vector3 = rigs[3].global_position + rigs[3].global_basis * Vector3(0, 1.35, -0.45)
		rigs[3].animate(dt, Vector3.ZERO, false, 0.0, [hold + rigs[3].global_basis.x * 0.12, hold - rigs[3].global_basis.x * 0.12])
		max_leg = maxf(max_leg, absf(rigs[1].leg_angles[0]))
		max_knee = maxf(max_knee, rigs[1].knee_angles[0])
		await process_frame
	_check(max_leg > 0.3, "andando, as pernas balançam (%.2f rad)" % max_leg)
	_check(max_knee > 0.4, "andando, o joelho dobra (%.2f rad)" % max_knee)
	var hold_r: Vector3 = rigs[3].global_position + rigs[3].global_basis * Vector3(0, 1.35, -0.45) + rigs[3].global_basis.x * 0.12
	var hand_r: Vector3 = rigs[3].hand_position(0)
	_check(not rigs[3].gloves[0].visible and hand_r.distance_to(hold_r) < 0.03,
			"segurando, ombro e cotovelo levam a mão até a luva (%.3f m)" % hand_r.distance_to(hold_r))
	await _look(player, Vector3(2.4, 0, -2.0), Vector3(2.4, 0.85, -4.2), "37_elenco")
	await _look(player, Vector3(1.4, 0, -3.35), Vector3(1.4, 1.5, -4.2), "38_rosto")
	await _look(player, Vector3(3.3, 0, -3.0), Vector3(3.6, 0.7, -4.2), "39_maos_e_tenis")
	kitnet.model.visible = true
	stage.queue_free()


## Primeira pessoa: quem joga vê o próprio corpo (sem a cabeça, onde fica a câmera) e os braços
## indo até o que segura.
func _test_first_person(kitnet: Node3D, player: CharacterBody3D) -> void:
	var rig: Node3D = player.character
	var head_mesh: Node3D = rig.model.find_child("Char_Head", true, false)
	_check(player.get_node("Body").visible and not head_mesh.visible,
			"em primeira pessoa o corpo aparece e a cabeça não")
	var at := Vector3(2.4, 0, -2.6)
	await _look(player, at, at + Vector3(0, 0, -0.35), "40_primeira_pessoa_olhando_para_baixo")
	kitnet.items.give(1, "ream")
	await create_timer(0.3).timeout
	await _look(player, at, at + Vector3(0, 0.9, -1.6), "41_primeira_pessoa_segurando_a_resma")
	var hand: Vector3 = rig.hand_position(0)
	_check(hand.distance_to(player._hands[0].global_position) < 0.05,
			"segurando, o braço do próprio boneco chega na luva (%.3f m)" % hand.distance_to(player._hands[0].global_position))
	await _look(player, at, at + Vector3(0, -0.2, -0.8), "42_primeira_pessoa_resma_olhando_para_baixo")
	player._drop_held()
	await create_timer(0.3).timeout


## Empurra-empurra: um boneco de outro jogador (sem rede, ele só segue a posição que "recebe")
## encostado no jogador se afasta, e vindo andando empurra o jogador junto; o tronco balança.
func _test_push(kitnet: Node3D, player: CharacterBody3D) -> void:
	var other: CharacterBody3D = load("res://scenes/player.tscn").instantiate()
	other.setup(4242, "Shover", 1, Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(3.62, 0.05, -3.3)))
	kitnet.get_node("Players").add_child(other)
	player.global_position = Vector3(3.8, 0.05, -3.3)
	player.velocity = Vector3.ZERO
	for i in 40:
		await physics_frame
	var gap := Vector2(player.global_position.x - other.global_position.x, player.global_position.z - other.global_position.z).length()
	_check(gap > 0.5 and gap < 0.8, "encostados, os bonecos se afastam até quase não encostar (%.2f m entre os dois)" % gap)
	# O outro vem andando a 2,8 m/s para cima do jogador.
	other.global_position = Vector3(3.0, 0.05, -3.3)
	other._target_position = other.global_position
	player.global_position = Vector3(3.9, 0.05, -3.3)
	await physics_frame
	var start_x := player.global_position.x
	var min_gap := 9.0
	var max_lean := 0.0
	var max_squash := 0.0
	var max_kick := 0.0
	var lagged := false
	var step_along := -1.0
	var rig: Node3D = player.character
	for i in 40:
		other._target_position += Vector3(2.8 / Engine.physics_ticks_per_second, 0, 0)
		await physics_frame
		min_gap = minf(min_gap, absf(player.global_position.x - other.global_position.x))
		max_lean = maxf(max_lean, rig.lean.length())
		max_squash = maxf(max_squash, absf(rig.squash))
		max_kick = maxf(max_kick, player.camera_kick.length())
		lagged = lagged or (rig.lean.length() > 0.02 and rig.chest_lean.dot(rig.lean) < 0.0)
		if i == 25:
			step_along = (rig.skeleton.global_basis.orthonormalized() * rig._step_dir).dot(Vector3.RIGHT)
		if i == 30:
			await _shot("43_empurra_empurra_primeira_pessoa")
	var moved := player.global_position.x - start_x
	_check(moved > 0.3, "quem vem andando empurra o jogador junto (%.2f m)" % moved)
	_check(min_gap > 0.4, "empurrando, um não entra no outro (%.2f m no mais perto)" % min_gap)
	_check(max_lean > 0.05, "o tronco de quem leva o empurrão balança (%.2f rad)" % max_lean)
	_check(lagged, "o peito vem atrasado em relação ao tronco (balanço em onda)")
	_check(max_squash > 0.05, "na trombada o corpo achata (%.2f)" % max_squash)
	_check(max_kick > 0.01, "na trombada a câmera de quem joga dá um tranco (%.3f rad)" % max_kick)
	_check(step_along > 0.7, "empurrado, os passos vão para o lado do empurrão (%.2f)" % step_along)
	# De fora: um boneco vem andando e tromba em outro parado (sem rede, o parado não sai do lugar,
	# mas o balanço, o atraso do peito e da cabeça e o achatado aparecem nos dois).
	var still: CharacterBody3D = load("res://scenes/player.tscn").instantiate()
	still.setup(4343, "Still", 2, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(4.25, 0.05, -3.4)))
	kitnet.get_node("Players").add_child(still)
	other.global_position = Vector3(3.2, 0.05, -3.4)
	other._target_position = other.global_position
	await _look(player, Vector3(3.7, 0, -1.9), Vector3(3.9, 0.9, -3.4), "44_trombada_antes")
	var shots := {22: "45_trombada_choque", 28: "46_trombada_balanco", 40: "47_trombada_volta"}
	for i in 48:
		if i < 24:
			other._target_position += Vector3(2.8 / Engine.physics_ticks_per_second, 0, 0)
		await physics_frame
		if shots.has(i):
			await _shot(shots[i])
	other.queue_free()
	still.queue_free()
	await physics_frame


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
		var rig: Node3D = bot.character
		_check(rig != null and bot.get_node("Body").visible and rig.accessory != null
				and rig.accessory.name == "Acc_Glasses", "o Bot aparece como o boneco de óculos (vaga 2)")
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
	await _wait_landed(sheet, 5.0)
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


func _test_drop_physics(kitnet: Node3D, player: CharacterBody3D) -> void:
	var items: Node = kitnet.items
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var free_fall := sqrt(2.0 * 1.5 / gravity)

	# Folha solta de 1,5 m, um pouco inclinada, longe dos móveis.
	var start := Vector3(3.9, 1.55, -3.3)
	var sheet: Node = items.spawn("sheet", Transform3D(Basis(Vector3.RIGHT, 0.45), start))
	await physics_frame
	var t := await _wait_landed(sheet, 6.0)
	var drift := Vector2(sheet.global_position.x - start.x, sheet.global_position.z - start.z).length()
	_check(t > free_fall * 1.6, "a folha cai devagar (%.2f s; queda livre %.2f s)" % [t, free_fall])
	_check(absf(sheet.global_basis.y.normalized().y) > 0.9, "a folha pousa deitada")
	_check(drift > 0.03, "a folha plana para o lado ao cair (%.2f m)" % drift)
	items.consume(sheet)

	# Resma solta da mesma altura: cai quase em queda livre.
	var ream: Node = items.spawn("ream", Transform3D(Basis.IDENTITY, start))
	await physics_frame
	t = 0.0
	while ream.global_position.y > 0.06 and t < 3.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	_check(t < free_fall * 1.3, "a resma cai rápido: bate no chão em %.2f s" % t)
	await _wait_landed(ream, 3.0)
	items.consume(ream)

	# Arremessos para -X pelo corredor livre em z = -1 (da entrada até a geladeira).
	var throw_from := Vector3(4.2, 0.05, -1.0)
	var dist_ream := await _throw(kitnet, player, "ream", throw_from, 1.0)
	var dist_sheet := await _throw(kitnet, player, "sheet", throw_from, 1.0)
	var dist_drop := await _throw(kitnet, player, "ream", throw_from, 0.0)
	_check(dist_ream > 2.0, "arremesso forte leva a resma longe (%.2f m)" % dist_ream)
	_check(dist_sheet < dist_ream, "a folha arremessada vai menos que a resma (%.2f m)" % dist_sheet)
	_check(dist_drop < 1.2, "tocar [G] só solta na frente (%.2f m)" % dist_drop)

	# Andar contra uma resma no chão empurra ela.
	var pushed: Node = items.spawn("ream", Transform3D(Basis.IDENTITY, Vector3(3.9, 0.1, -3.2)))
	await _wait_landed(pushed, 2.0)
	var before: Vector3 = pushed.global_position
	player.global_position = Vector3(3.9, 0.05, -2.5)
	player.rotation.y = 0.0
	Input.action_press("move_forward")
	await create_timer(0.9).timeout
	Input.action_release("move_forward")
	await create_timer(0.5).timeout
	_check(pushed.global_position.distance_to(before) > 0.1,
			"andando se empurra a resma (%.2f m)" % pushed.global_position.distance_to(before))

	# O que cai fora do mapa volta para dentro.
	pushed.snap(Transform3D(Basis.IDENTITY, Vector3(3.0, -6.0, -3.0)))
	await physics_frame
	await physics_frame
	_check(pushed.global_position.y > -1.0, "a resma que caiu fora do mapa voltou (y %.2f)" % pushed.global_position.y)
	items.consume(pushed)
	await _shot("16_depois_dos_arremessos")


func _test_guillotine(kitnet: Node3D, player: CharacterBody3D) -> void:
	var g: Node3D = kitnet.guillotine
	var items: Node = kitnet.items
	var stats: Resource = g.stats
	var swing: float = stats.swing_down + stats.swing_up + 0.1
	_check(g != null and g.rows_left == 0, "guilhotina montada e vazia")
	# Em pé na frente da guilhotina (lado da lâmina), olhando para ela.
	var stand := Vector3(2.35, 0.05, -1.35)
	player.global_position = stand
	await physics_frame
	_check(g._prompt(player).begins_with("[E] Pull the lever"), "vazia ela oferece só bater a alavanca")

	# Folha molhada: põe, corta as 3 linhas.
	items.give(1, "sheet", {"wet": true})
	await create_timer(0.3).timeout
	_check(g._prompt(player).contains("smudge"), "avisa que a folha molhada vai borrar")
	g.zone.interact(player)
	await physics_frame
	_check(player.held_item() == null and g.rows_left == stats.rows_per_sheet, "a folha foi para a guilhotina (3 linhas)")
	_check(g._strips.all(func(st): return st.visible), "as 3 faixas da folha aparecem")
	g.zone.interact(player)
	await create_timer(stats.swing_down * 0.5).timeout
	await _look(player, Vector3(2.62, 0, -1.4), Vector3(2.32, 0.82, -2.05), "17_guilhotina_cortando")
	await create_timer(swing).timeout
	_check(g.rows_left == stats.rows_per_sheet - 1, "um corte, uma linha a menos")
	var pile: Node = items.items.get(g._pile_id)
	_check(pile != null and pile.kind == "bills" and pile.data["count"] == stats.bills_per_row,
			"saíram %d notas no montinho" % stats.bills_per_row)
	for i in stats.rows_per_sheet - 1:
		g.zone.interact(player)
		await create_timer(swing).timeout
	var total: int = stats.rows_per_sheet * stats.bills_per_row
	_check(g.rows_left == 0 and not g._strips.any(func(st): return st.visible), "folha toda cortada")
	_check(pile.data["count"] == total and pile.data["smudged"] == total,
			"montinho com %d notas, todas borradas (%d, %d)" % [total, pile.data["count"], pile.data["smudged"]])

	# Folha seca: as notas somam no mesmo montinho, sem borrar.
	items.give(1, "sheet", {"wet": false})
	await create_timer(0.3).timeout
	g.zone.interact(player)
	await physics_frame
	g.zone.interact(player)
	await create_timer(swing).timeout
	_check(pile.data["count"] == total + stats.bills_per_row and pile.data["smudged"] == total,
			"a folha seca soma no montinho sem borrar")
	var top: Material = pile.get_node("Mesh").get_surface_override_material(0)
	_check(top is ShaderMaterial and top.get_shader_parameter("albedo_tex") == preload("res://assets/textures/bill_front.png"),
			"a nota de cima do montinho voltou a ser a limpa (toon acompanhou a troca de malha)")
	await _look(player, Vector3(2.62, 0, -1.4), Vector3(2.25, 0.78, -1.85), "18_montinho")
	# Cortar com a mão ocupada não dá; outra coisa que não folha também não entra.
	items.give(1, "ream")
	await create_timer(0.3).timeout
	_check(g._prompt(player) == "Needs a printed sheet", "a resma não entra na guilhotina")
	player._drop_held()
	await create_timer(0.3).timeout

	# Pegar o montinho e carregar.
	player.global_position = stand
	await physics_frame
	items.request_pickup(pile.id)
	await create_timer(0.4).timeout
	_check(player.held_item() == pile, "pegou o montinho de notas")
	_check(g._pile_id == 0, "a guilhotina sabe que o montinho saiu")
	await _look(player, Vector3(2.4, 0, -1.2), Vector3(1.0, 1.0, -0.6), "19_notas_na_mao")
	player._drop_held()
	await create_timer(0.5).timeout


## Dá um item na mão do jogador em `at`, olhando para -X, solta com a força `charge` e devolve
## quanto ele andou no chão até parar. O item some depois.
func _throw(kitnet: Node3D, player: CharacterBody3D, kind: String, at: Vector3, charge: float) -> float:
	player.global_position = at
	player.rotation.y = PI / 2
	player.head.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	await physics_frame
	var item: Node = kitnet.items.give(1, kind)
	await create_timer(0.4).timeout
	var from := Vector2(player.global_position.x, player.global_position.z)
	# O giro ao soltar é sorteado (às vezes a resma vira e rola mais um pouco): semente fixa para
	# o teste dar sempre o mesmo resultado.
	seed(301)
	player._drop_held(charge)
	await physics_frame
	await _wait_landed(item, 4.0)
	var dist := Vector2(item.global_position.x, item.global_position.z).distance_to(from)
	kitnet.items.consume(item)
	await physics_frame
	return dist


## Espera o item parar no chão (dormindo ou quase parado perto do chão); devolve quanto levou.
func _wait_landed(item: Node, timeout: float) -> float:
	var t := 0.0
	await physics_frame
	while t < timeout:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if item.sleeping or (item.global_position.y < 0.12 and item.linear_velocity.length() < 0.05):
			break
	return t


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

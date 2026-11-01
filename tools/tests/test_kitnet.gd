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
## - guilhotina: pôr a folha começa a operar (câmera em cima da mesa, luvas na folha), o mouse
##   desliza a folha, o clique corta: na marca as notas saem perfeitas, fora dela tortas (valem
##   menos e a de cima mostra o corte), no meio da linha estraga; [E] sai; somar no mesmo montinho
##   e carregar o montinho;
## - loja: o PC mostra o navegador, usar põe a câmera na tela e as luvas no teclado e no mouse,
##   comprar papel e cartucho (sem dinheiro não paga), a caixa de cada loja chega na porta com a
##   campainha, abrir solta o que veio, a resma volta para o estoque e o cartucho genérico entra na
##   impressora (folha e notas com a cor errada); sem cartucho o visor avisa;
## - varal: a folha molhada pendura e seca (mais rápido com o ventilador ligado, tremulando), tirar
##   no meio leva ela úmida, seca não borra na guilhotina, varal cheio não aceita mais;
## - máquina de lavar: os montinhos entram e saem do cesto, lava e centrifuga com a tampa travada,
##   solta ela anda e segurada fica parada, as notas saem usadas (valem mais), empurra de volta;
## - contadora: conta o montinho do funil para a bandeja, a borrada emperra e segurando destrava (vai
##   para as rejeitadas), com 20 para e cinta o maço com a nota de qualidade, pega as soltas;
## - frigideira: nasce no fogão, bate com o clique (BONK! em quem está na frente, clang na parede), quem
##   leva cai com as estrelinhas, solta o que segurava e levanta tonto;
## - vizinho do 303: o barulho enche a paciência e ele vem; com a 301 trancada bate e vai embora;
##   destrancada entra, vê as notas e corre ligando para a polícia; a frigideira derruba e corta a
##   ligação; arrastado até o capacho dele, acorda achando que sonhou; o maço suborna; a polícia
##   leva o que está à vista e cobra a multa, e o esconderijo salva o que está dentro;
## - saco de lixo: sai do rolo da cozinha, recebe maços e montinhos (estufa e não afunda no chão),
##   o clique tira o último, carrega cheio e cabe no esconderijo; o vizinho não vê o que está dentro;
##   na mão, o clique abre: o que cai na boca (largado ou arremessado) entra, e aberto o vizinho vê;
##   aberto, o dinheiro lá dentro tem física; balança na mão; aberto e tombado derrama, fechado não;
## - batida policial: a malha de navegação; esconder no guarda-roupa (o corpo some, olha pela fresta);
##   os policiais entram pela 301 trancada, pegam a prova à vista e revistam com chance (sem achar,
##   a geladeira e quem está escondido ficam); achando, cacetada, algema e arrasto pela gola; a
##   frigideira no policial solta o preso; preso na escada até o fim, e volta no corredor; o saco de
##   lixo fechado passa por lixo;
## - luz: cada aparelho soma no consumo; acima do limite as luzes tremem e o disjuntor cai (apaga a
##   kitnet mas não o corredor, a impressora desliga, a máquina de lavar e o ventilador param e
##   voltam); religa no quadro, e [E] no quadro desliga a luz de propósito;
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
## - ragdoll parcial: andando não derruba; correndo, quem leva a trombada solta o item, cai (a
##   câmera vai junto sem entrar na parede) e levanta onde caiu;
## - com --solo, entra sozinho sem rede (o botão "Play solo") em vez de hospedar;
## - com --client, abre uma segunda janela que entra na sala e confere que ela aparece e se mexe.
## Prints de alguns pontos de vista na pasta --out (rode com janela, sem --headless).
##
##   godot --path . --resolution 1280x720 --script res://tools/tests/test_kitnet.gd -- --out=<pasta> [--solo | --client]
##
## Termina com "TESTE OK" ou com a lista do que falhou.

const ItemKinds := preload("res://scripts/items/item_kinds.gd")

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
	# O vizinho só acorda no teste dele (as máquinas do teste fazem barulho de sobra).
	kitnet.neighbor.enabled = false
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
	_check(not kitnet.fan.powered and amb.fan_blades.transform.basis.is_equal_approx(blades_before),
			"o ventilador começa desligado, parado")
	kitnet.fan._toggle(1)
	await create_timer(kitnet.fan.SPIN_TIME).timeout
	blades_before = amb.fan_blades.transform.basis
	await create_timer(0.2).timeout
	_check(not amb.fan_blades.transform.basis.is_equal_approx(blades_before), "ligado, as pás do ventilador giram")
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
	await _test_shop(kitnet, player)
	await _test_clothesline(kitnet, player)
	await _test_washer(kitnet, player)
	await _test_counter(kitnet, player)
	await _test_power(kitnet, player)
	await _test_pan(kitnet, player)
	await _test_neighbor(kitnet, player)
	await _test_trashbag(kitnet, player)
	await _test_raid(kitnet, player)
	await _test_characters(kitnet, player)
	await _test_first_person(kitnet, player)
	await _test_push(kitnet, player)
	await _test_ragdoll(kitnet, player)

	if _with_client:
		await _test_client(kitnet)
	_finish()


## A luz da kitnet (power.gd): o consumo e o disjuntor.
func _test_power(kitnet: Node3D, player: CharacterBody3D) -> void:
	var power: Node = kitnet.power
	var amb: Node = kitnet.ambience
	var printer: Node3D = kitnet.printer
	var fan: Node3D = kitnet.fan
	var washer: Node3D = kitnet.washer
	var bulb: Light3D = kitnet.model.find_child("LIGHT_main_0", true, false)
	var kitchen: Light3D = kitnet.model.find_child("LIGHT_kitchen_0", true, false)
	var hall: Light3D = kitnet.model.find_child("LIGHT_hall_0", true, false)
	_check(power != null and power.zone != null, "quadro de luz montado")
	if printer.powered:
		printer._toggle_power(1)
	if fan.powered:
		fan._toggle(1)
	await create_timer(0.3).timeout
	_check(kitnet.has_power(), "começa com luz")
	var base: float = power.load_watts
	_check(absf(base - (power.BASE_WATTS + kitnet.computer.WATTS)) < 1.0,
			"parado, gasta só a base e o PC (%d W)" % base)
	fan._toggle(1)
	printer._toggle_power(1)
	washer.contents = [{"count": 2}]
	washer.lid_open = false
	washer._start(1)
	await create_timer(0.3).timeout
	_check(washer.running(), "a máquina de lavar começou")
	_check(power.load_watts >= base + fan.WATTS + washer.WASH_WATTS,
			"o ventilador, a impressora e a máquina de lavar somam (%d W)" % power.load_watts)
	_check(power.load_watts < power.LIMIT_WATTS and power.heat == 0.0, "isso cabe no disjuntor")

	# Um aparelho a mais que passa do limite: esquenta, as luzes tremem e ele cai.
	var hog := Node.new()
	var hog_script := GDScript.new()
	hog_script.source_code = "extends Node\nfunc power_draw() -> float:\n\treturn %.1f\n" % power.LIMIT_WATTS
	hog_script.reload()
	hog.set_script(hog_script)
	hog.add_to_group("powered")
	kitnet.add_child(hog)
	await create_timer(0.4).timeout
	_check(power.heat > 0.0 and kitnet.has_power(), "acima do limite, o disjuntor esquenta (ainda com luz)")
	var lowest := 1.0
	for i in 40:
		lowest = minf(lowest, amb.mains_level)
		await process_frame
	_check(lowest < 0.8, "as luzes tremem com a sobrecarga (%.2f)" % lowest)
	await create_timer(power.TRIP_SECONDS).timeout
	_check(power.tripped and not kitnet.has_power(), "com a sobrecarga, o disjuntor cai")
	await process_frame
	_check(bulb.light_energy == 0.0 and kitchen.light_energy == 0.0, "as luzes da kitnet apagam")
	_check(hall.light_energy > 0.0, "as do corredor (do prédio) continuam acesas")
	_check(not printer.powered, "a impressora desligou")
	printer._toggle_power(1)
	_check(not printer.powered and printer._power_prompt(player).begins_with("No power"), "sem luz, a impressora não liga")
	_check(fan.powered and not fan.blowing(), "o ventilador para, com o botão ligado")
	var left: float = washer.time_left
	await create_timer(0.5).timeout
	_check(washer.running() and is_equal_approx(washer.time_left, left) and washer.noise() == 0.0,
			"a máquina de lavar para no meio do ciclo")
	_check(kitnet.computer._prompt(player).begins_with("No power"), "o PC apaga")
	_check(power.load_watts == 0.0, "sem luz, o relógio não conta")
	await _look(player, Vector3(2.6, 0, -1.0), Vector3(2.6, 1.0, -4.0), "80_sem_luz")

	# Religar com tudo ainda ligado: cai de novo. Sem o excesso, fica.
	player.global_position = Vector3(4.6, 0.05, -0.8)
	await physics_frame
	_check(power._prompt(player).begins_with("[E] Flip"), "o quadro oferece religar")
	power.zone.interact(player)
	await create_timer(0.2).timeout
	_check(kitnet.has_power(), "religou")
	await create_timer(power.TRIP_SECONDS + 0.3).timeout
	_check(power.tripped, "com o excesso ainda ligado, cai de novo")
	hog.queue_free()
	power.zone.interact(player)
	await create_timer(1.0).timeout
	_check(kitnet.has_power() and amb.mains_level == 1.0 and bulb.light_energy > 0.0 and kitchen.light_energy > 0.0,
			"sem o excesso, a luz volta e fica")
	_check(washer.time_left < left, "a máquina de lavar continua o ciclo")
	_check(fan.blowing(), "o ventilador volta a girar sozinho")
	_check(not printer.powered, "a impressora continua desligada (tem que ligar de novo)")
	await _look(player, Vector3(4.75, 0, -1.1), Vector3(4.78, 1.6, 0.0), "81_quadro_de_luz")
	power.zone.interact(player)
	await create_timer(0.2).timeout
	_check(power.tripped and power._prompt(player).begins_with("[E] Flip"), "[E] no quadro desliga a luz")
	power.zone.interact(player)
	await create_timer(0.2).timeout
	_check(kitnet.has_power(), "e liga de novo")
	washer.confiscate()
	fan._toggle(1)


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


## Ragdoll parcial: andando ninguém derruba ninguém; correndo, quem leva a trombada solta o que
## segura, cai (os ossos de física tombam) e depois levanta onde caiu.
func _test_ragdoll(kitnet: Node3D, player: CharacterBody3D) -> void:
	var runner: CharacterBody3D = load("res://scenes/player.tscn").instantiate()
	runner.setup(4444, "Runner", 1, Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(2.9, 0.05, -3.3)))
	kitnet.get_node("Players").add_child(runner)
	await physics_frame

	# Andando (2,8 m/s): empurra, mas não derruba.
	player.global_position = Vector3(3.9, 0.05, -3.3)
	await _run_into(runner, player, 2.8, 30)
	_check(not player.fallen, "andando, a trombada não derruba")
	await create_timer(0.6).timeout

	# Correndo (4,8 m/s) com a resma na mão: derruba.
	runner.global_position = Vector3(2.7, 0.05, -3.3)
	runner._target_position = runner.global_position
	runner._last_physics_pos = runner.global_position
	player.global_position = Vector3(3.9, 0.05, -3.3)
	player._last_physics_pos = player.global_position
	kitnet.items.give(1, "ream")
	await create_timer(0.3).timeout
	var start := player.global_position
	await _run_into(runner, player, 4.8, 18)
	_check(player.fallen, "correndo, a trombada derruba")
	_check(player.held_item() == null, "quem cai solta o que segurava")
	var lowest := 9.0
	var in_wall := 0
	for i in 50:
		await physics_frame
		lowest = minf(lowest, player.character.ragdoll_hips().y)
		if _camera_in_wall(player):
			in_wall += 1
		if i == 12:
			await _shot("48_caindo_primeira_pessoa")
	_check(lowest < 0.45, "caído, os quadris vão ao chão (%.2f m)" % lowest)
	_check(in_wall == 0, "caindo, a câmera não entra na parede (%d quadros dentro)" % in_wall)
	var waited := 0.0
	while player.fallen and waited < 4.0:
		await physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
	_check(not player.fallen, "depois de %.1f s levanta" % waited)
	var slid := (player.global_position - start).dot(Vector3.RIGHT)
	_check(slid > 0.3, "levanta onde caiu, para o lado da trombada (%.2f m)" % slid)
	await create_timer(1.0).timeout
	_check(player.character.getup >= 1.0 and player._has_control(), "de pé de novo, o jogador volta a andar")

	# Caindo de cara na parede do fundo (z -5): a cabeça do ragdoll vai até ela, a câmera não entra.
	player.global_position = Vector3(4.2, 0.05, -4.55)
	player._last_physics_pos = player.global_position
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0
	await physics_frame
	player._begin_fall(Vector3.FORWARD, 5.0)
	in_wall = 0
	for i in 50:
		await physics_frame
		if _camera_in_wall(player):
			in_wall += 1
		if i == 10:
			await _shot("53_caindo_na_parede")
	_check(in_wall == 0, "caindo na parede, a câmera não entra nela (%d quadros dentro)" % in_wall)
	while player.fallen:
		await physics_frame
	await create_timer(1.0).timeout

	# De fora: o corredor cai (sem rede, chamado direto) e levanta.
	runner._target_position = Vector3(3.6, 0.05, -3.3)
	runner.global_position = runner._target_position
	await _look(player, Vector3(2.4, 0, -1.9), Vector3(3.6, 0.6, -3.3), "49_ragdoll_antes")
	runner._begin_fall(Vector3(1, 0, -0.3).normalized(), 5.0)
	var shots := {8: "50_ragdoll_tombando", 30: "51_ragdoll_no_chao"}
	for i in 60:
		await physics_frame
		if shots.has(i):
			await _shot(shots[i])
	runner._end_fall()
	for i in 20:
		await physics_frame
	await _shot("52_ragdoll_levantando")
	runner.queue_free()
	await physics_frame


## A câmera do jogador entrou no cenário? A colisão do cenário é oca (trimesh): entrou se a linha
## da cabeça da cápsula até ela cruza o cenário, ou se ela está encostada numa superfície (o plano
## near corta).
func _camera_in_wall(player: CharacterBody3D) -> bool:
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var eye: Vector3 = player.camera.global_position
	var line := PhysicsRayQueryParameters3D.create(player.head.global_position as Vector3, eye, 1)
	line.hit_back_faces = true
	var near := SphereShape3D.new()
	near.radius = player.camera.near
	var touch := PhysicsShapeQueryParameters3D.new()
	touch.shape = near
	touch.transform = Transform3D(Basis.IDENTITY, eye)
	touch.collision_mask = 1
	return not space.intersect_ray(line).is_empty() or not space.intersect_shape(touch, 1).is_empty()


## O outro boneco vem andando em linha reta para cima do jogador, a `speed` m/s, por `frames`.
func _run_into(runner: CharacterBody3D, player: CharacterBody3D, speed: float, frames: int) -> void:
	var dir := Vector3(player.global_position.x - runner.global_position.x, 0, player.global_position.z - runner.global_position.z).normalized()
	for i in frames:
		runner._target_position += dir * speed / Engine.physics_ticks_per_second
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
	_check(printer.ink < ink_before, "gastou tinta do cartucho")
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
	_check(g != null and not g.has_sheet(), "guilhotina montada e vazia")
	# Em pé na frente da guilhotina (lado da lâmina), olhando para ela.
	var stand := Vector3(2.35, 0.05, -1.35)
	player.global_position = stand
	await physics_frame
	_check(g._prompt(player).begins_with("[E] Pull the lever"), "vazia ela oferece só bater a alavanca")

	# Folha molhada: põe e começa a operar, com a câmera em cima da mesa e as luvas na folha.
	items.give(1, "sheet", {"wet": true})
	await create_timer(0.3).timeout
	_check(g._prompt(player).contains("smudge"), "avisa que a folha molhada vai borrar")
	g.zone.interact(player)
	await physics_frame
	_check(player.held_item() == null and g.pieces_left == stats.rows_per_sheet, "a folha foi para a guilhotina (3 linhas)")
	_check(player.operating == g and g._sheet.visible, "pondo a folha, começa a operar")
	await create_timer(player.STATION_CAMERA_TIME + 0.15).timeout
	_check(root.get_camera_3d() == player._station_cam, "a câmera foi para cima da mesa")
	var right: MeshInstance3D = player._press_hands[0]
	_check(g._guide.visible, "a linha-guia da lâmina aparece")
	_check(right.visible and right.global_position.distance_to(g._sheet.global_position) < 0.3,
			"as luvas seguram a folha (%.2f m)" % right.global_position.distance_to(g._sheet.global_position))
	await _shot("17_guilhotina_operando")

	# O mouse desliza a folha para além da lâmina, e as luvas vão junto.
	var hand_before := right.global_position
	var sheet_before: Vector3 = g._sheet.global_position
	player._input(_mouse_motion(Vector2(0, 300)))
	await process_frame
	await process_frame
	_check(g.feed > 0.03, "o mouse desliza a folha (%.3f m)" % g.feed)
	_check(g._sheet.global_position.distance_to(sheet_before) > 0.03, "a folha anda na mesa")
	_check(right.global_position.distance_to(hand_before) > 0.02, "as luvas vão junto com a folha")
	await _shot("18_guilhotina_folha_passando")
	# Mais que uma linha não passa da lâmina, e com Shift a folha anda um quarto.
	player._input(_mouse_motion(Vector2(0, 5000)))
	_check(is_equal_approx(g.feed, g.feed_max()) and g.feed_max() < 2.0 * (g.row_edges(1).x - g.row_edges(0).x),
			"a folha passa no máximo uma linha da lâmina (%.3f m)" % g.feed)
	g.slide_to(0.02)
	Input.action_press("sprint")
	player._input(_mouse_motion(Vector2(0, 100)))
	Input.action_release("sprint")
	_check(is_equal_approx(g.feed - 0.02, 100 * g.FEED_PER_PIXEL * g.FEED_FINE),
			"com Shift, o ajuste fino anda menos (%.4f m em 100 px)" % (g.feed - 0.02))

	# Na marca: a linha sai reta. O corte só acontece com a lâmina embaixo, e do clique até a
	# alavanca voltar a folha fica parada. A tira (2 notas ainda grudadas) vai para a pilha do lado
	# da lâmina: só com o corte vertical, no fim, elas viram notas.
	_feed_to(g, g.ideal_cut() - g.cut_pos)
	var feed_at: float = g.feed
	player._input(_left_click())
	await create_timer(stats.swing_down * 0.4).timeout
	_check(g.pieces_left == stats.rows_per_sheet and g.feed == feed_at and g._pile_id == 0,
			"o corte espera a lâmina descer (a folha fica onde estava)")
	player._input(_mouse_motion(Vector2(0, 200)))
	_check(g.feed == feed_at, "durante o golpe o mouse não mexe a folha")
	await create_timer(stats.swing_down * 0.6 + 0.05).timeout
	_check(g._strips[0].visible and g._strip_tweens[0].is_running() and not g._strips[1].visible,
			"a tira cortada vai para a pilha")
	_check(player.camera_kick.length() > 0.003, "a câmera dá um tranco no golpe (%.3f rad)" % player.camera_kick.length())
	await _shot("18b_guilhotina_golpe")
	await create_timer(swing - stats.swing_down - 0.05).timeout
	_check(not g._strips[0].visible and g._stack.visible and g.stack_count == 1, "a tira pousou na pilha")
	var toon_uv: Vector3 = g._sheet.get_surface_override_material(0).get_shader_parameter("uv1_scale")
	_check(toon_uv.is_equal_approx((g._sheet.mesh as QuadMesh).material.uv1_scale) and toon_uv.y < 0.9,
			"o que sobrou da folha mostra só a parte que sobrou (escala %.2f)" % toon_uv.y)
	_check(g._pile_id == 0, "cortar só na horizontal não solta nota")
	_check(g.pieces_left == stats.rows_per_sheet - 1 and g.feed == 0.0, "um corte, uma linha a menos, e a folha volta para a lâmina")

	# 5 mm depois da marca: a linha sai torta, e a de trás perde um pedaço da frente. Esse corte
	# separa a última linha, que sai junto (segunda tira). Acabaram as linhas: a pilha gira e vai
	# para a lâmina.
	_feed_to(g, g.ideal_cut() - g.cut_pos + 0.005)
	await _cut_click(player, stats.swing_down + 0.15)
	_check(g._strips[0].visible and g._strips[1].visible, "a última linha sai junto, numa segunda tira")
	await create_timer(swing - stats.swing_down - 0.15).timeout
	_check(g.phase == g.Phase.COLUMNS and g.pieces_left == stats.bills_per_row and g.stack_count == stats.rows_per_sheet
			and g._stack.visible and not g._sheet.visible and g._pile_id == 0,
			"acabaram as linhas: a pilha de %d tiras gira para o corte vertical" % g.stack_count)
	var stack_x: float = (g.global_transform * Vector3(g.STACK_X, 0, 0)).x
	_check(is_equal_approx(g._stack_shift, 0.0) and absf(g.hand_transform(1).origin.x - stack_x) < 0.25,
			"a pilha chegou na lâmina e as luvas seguram ela")
	await _shot("18c_guilhotina_pilha_de_tiras")

	# Corte vertical 4 mm depois da marca: separa as colunas de todas as tiras de uma vez (a de trás
	# sai junto), e o erro dele soma no de cada linha: as 6 notas saem tortas.
	_feed_to(g, g.ideal_cut() - g.cut_pos + 0.004)
	await _cut_click(player, stats.swing_down + 0.15)
	_check(g._strips[0].visible and g._strips[1].visible, "as duas colunas saem, cada uma para o montinho")
	await create_timer(swing - stats.swing_down - 0.15).timeout
	var total: int = stats.rows_per_sheet * stats.bills_per_row
	var pile: Node = items.items.get(g._pile_id)
	_check(pile != null and pile.kind == "bills" and pile.data["count"] == total and pile.data["smudged"] == total,
			"3 cortes acabam a folha: %d notas borradas no montinho" % total)
	_check(pile != null and pile.data["crooked"] == total and pile.data["worth"] > 3.2 and pile.data["worth"] < 3.9,
			"o corte vertical torto entorta as notas das duas colunas (valem %.2f de %d)" % [pile.data["worth"] if pile else 0.0, total])
	_check(pile != null and (pile.data["top_cut"] as Rect2).has_area(), "a nota de cima mostra o corte torto")
	_check(not g.has_sheet() and not g._sheet.visible and not g._stack.visible and g.phase == g.Phase.ROWS, "a folha acabou")
	await create_timer(0.3).timeout
	_check(player.operating == null, "acabou a folha, sai da guilhotina sozinho")
	await create_timer(player.STATION_CAMERA_TIME + 0.15).timeout
	_check(root.get_camera_3d() == player.camera, "a câmera voltou para a primeira pessoa")
	_check(absf(g._arm.rotation.z - g.OPEN_ANGLE) < 0.01,
			"a alavanca volta para o ângulo de parada (%.0f°)" % rad_to_deg(g._arm.rotation.z))
	await _look(player, Vector3(2.62, 0, -1.4), Vector3(2.25, 0.78, -1.85), "19_montinho_torto")

	# Folha seca: na marca a linha vai para a pilha; no meio da linha estraga ela.
	items.give(1, "sheet", {"wet": false})
	await create_timer(0.3).timeout
	g.zone.interact(player)
	await physics_frame
	_feed_to(g, g.ideal_cut() - g.cut_pos)
	await _cut_click(player, swing)
	_check(g.stack_count == 1 and pile.data["count"] == total, "a linha da folha seca foi para a pilha")
	_feed_to(g, 0.03)
	await _cut_click(player, swing)
	_check(g.stack_count == 1 and g.pieces_left == 1, "cortar no meio da linha estraga ela (não vai para a pilha)")
	# [E] sai, e a folha e a pilha ficam na mesa.
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	Input.action_release("interact")
	await physics_frame
	_check(player.operating == null and g.pieces_left == 1 and g._stack.visible, "[E] sai e a folha e a pilha ficam na mesa")
	await create_timer(player.STATION_CAMERA_TIME + 0.15).timeout
	_check(g._prompt(player).begins_with("[E] Cut"), "de mão vazia, dá para voltar a cortar")
	# A última linha tem grudado na frente o resto da que estragou, então não saiu sozinha. Outro
	# jogador puxa a alavanca no pegador, aparando no vão onde quem opera segura a folha: o resto
	# vira retalho na mesa e a última linha, agora solta, vai para a pilha.
	g.zone.interact(player)
	await physics_frame
	_check(player.operating == g, "voltou a operar")
	_feed_to(g, g.ideal_cut() - g.cut_pos)
	var stranger := Node.new()
	_check(g._lever_prompt(player) == "" and g._lever_prompt(stranger).begins_with("[E] Pull the lever"),
			"o pegador da alavanca é para outro jogador puxar")
	stranger.free()
	g._press_lever(99)
	await create_timer(stats.swing_down + 0.15).timeout
	_check(g._strips[0].visible and g._strips[1].visible, "aparou: sai o retalho e a última linha")
	await create_timer(swing - stats.swing_down - 0.15).timeout
	_check(g.phase == g.Phase.COLUMNS and g.stack_count == 2, "outro jogador aparou, e as 2 linhas boas foram para o corte vertical")
	# Corte vertical na marca: as 4 notas saem perfeitas e somam no mesmo montinho sem borrar.
	_feed_to(g, g.ideal_cut() - g.cut_pos)
	await _cut_click(player, swing)
	_check(pile.data["count"] == total + 4 and pile.data["smudged"] == total and pile.data["crooked"] == total,
			"na marca, as notas da folha seca saem perfeitas e somam no montinho sem borrar")
	var top: Material = pile.get_node("Mesh").get_surface_override_material(0)
	_check(top is ShaderMaterial and top.get_shader_parameter("albedo_tex") == preload("res://assets/textures/bill_front.png"),
			"a nota de cima do montinho voltou a ser a limpa e reta (toon acompanhou a troca de malha)")
	await create_timer(0.3).timeout
	_check(player.operating == null, "acabou a folha de novo, saiu sozinho")
	await create_timer(player.STATION_CAMERA_TIME + 0.15).timeout
	# Cortar com a mão ocupada não dá; outra coisa que não folha também não entra.
	items.give(1, "ream")
	await create_timer(0.3).timeout
	_check(g._prompt(player) == "Needs a printed sheet", "a resma não entra na guilhotina")
	# Some com ela (largada, ela cai em cima da mesa e tapa os prints da guilhotina).
	items.consume(player.held_item())
	await create_timer(0.3).timeout

	# Pegar o montinho e carregar.
	player.global_position = stand
	await physics_frame
	items.request_pickup(pile.id)
	await create_timer(0.4).timeout
	_check(player.held_item() == pile, "pegou o montinho de notas")
	_check(g._pile_id == 0, "a guilhotina sabe que o montinho saiu")
	_check(preload("res://scripts/items/item_kinds.gd").label(pile).contains("6 crooked"), "o nome do montinho conta as tortas (%s)" % preload("res://scripts/items/item_kinds.gd").label(pile))
	await _look(player, Vector3(2.4, 0, -1.2), Vector3(1.0, 1.0, -0.6), "19b_notas_na_mao")
	player._drop_held()
	await create_timer(0.5).timeout

	# Mãos: andam livres pela mesa. Pegando pela borda de trás a folha treme; o botão direito anda só
	# com as mãos; perto da lâmina ela fica firme; o que passar da linha da lâmina vai embora.
	player.global_position = stand
	await physics_frame
	items.give(1, "sheet", {"wet": false})
	await create_timer(0.3).timeout
	g.zone.interact(player)
	await physics_frame
	_check(g._on_paper(g.feed, g.hands_z) and not g.hands_in_danger() and g.shake_now() > 0.001,
			"pega a folha pela borda de trás: seguro, mas ela treme (%.1f mm)" % (g.shake_now() * 1000.0))
	var feed_before: float = g.feed
	var hands_before: float = g.hands_z
	player._input(_right_button(true))
	player._input(_mouse_motion(Vector2(0, 300)))
	player._input(_right_button(false))
	_check(g.hands_z > hands_before + 0.03 and g.feed == feed_before, "com o botão direito, só as mãos andam")
	player._input(_mouse_motion(Vector2(0, 100)))
	_check(g.feed > feed_before, "com as mãos em cima, o mouse empurra a folha")
	_feed_to(g, g.ideal_cut() - g.cut_pos)
	_check(g.shake_now() == 0.0 and not g.hands_in_danger(), "com as mãos perto da lâmina, a folha fica firme")
	await _cut_click(player, swing)
	_check(player.fingers_missing() == 0 and g.stack_count == 1, "mãos perto, mas atrás da lâmina: corte sem susto")
	# Sobrou pouca folha atrás da lâmina. Empurrando com as mãos onde estão, o polegar passaria da
	# linha; então as mãos saem da folha pelo botão direito, empurram pela ponta de trás e voltam
	# para perto da lâmina sem mexer nela.
	_check(g._chopped(g.hands_z + (g.ideal_cut() - g.cut_pos)) != 0, "empurrar a folha curta com as mãos onde estão levaria os dedos")
	player._input(_right_button(true))
	player._input(_mouse_motion(Vector2(0, -1200)))
	player._input(_right_button(false))
	_check(not g._on_paper(g.feed, g.hands_z) and g.feed == 0.0, "as mãos saem da folha, para trás dela")
	hands_before = g.hands_z
	player._input(_mouse_motion(Vector2(0, 60)))
	_check(g.feed == 0.0 and g.hands_z > hands_before, "fora da folha, o mouse anda só com as mãos")
	for i in 30:
		player._input(_mouse_motion(Vector2(0, 20)))
	_check(g.feed > 0.02 and g._on_paper(g.feed, g.hands_z), "encostando, as mãos empurram a folha pela ponta (%.3f m)" % g.feed)
	g.slide_to(g.ideal_cut() - g.cut_pos)
	_check(not g.hands_in_danger() and g.shake_now() > 0.001,
			"pela ponta, a última linha chega na marca sem perigo, mas tremendo (%.1f mm)" % (g.shake_now() * 1000.0))
	feed_before = g.feed
	player._input(_right_button(true))
	player._input(_mouse_motion(Vector2(0, (g.CUT_Z - 0.01 - g.hands_front_offset() - g.hands_z) / g.FEED_PER_PIXEL)))
	player._input(_right_button(false))
	_check(g.feed == feed_before and g.shake_now() == 0.0 and not g.hands_in_danger(),
			"as mãos voltam para perto da lâmina sem mexer a folha: firme")
	await _cut_click(player, swing)
	_check(player.fingers_missing() == 0 and g.phase == g.Phase.COLUMNS and g.stack_count == 3, "a última linha saiu sem susto")
	# Corte vertical com o polegar e o indicador passando da linha: o golpe leva os dois, das duas mãos.
	g.slide_to(g.ideal_cut() - g.cut_pos)
	_check(_place_for(g, 0b11), "dá para pôr só o polegar e o indicador passando da linha")
	await process_frame
	await process_frame
	var flat: MeshInstance3D = player._press_hands[0]
	_check(g.hands_in_danger() and flat.get_node("HandFlat_R_Thumb").material_overlay != null
			and flat.get_node("HandFlat_R_Middle").material_overlay == null,
			"com os dedos passando da linha, a guilhotina avisa e eles ficam vermelhos")
	await _shot("18d_guilhotina_dedos_na_linha")
	await _cut_click(player, swing)
	var kinds := preload("res://scripts/items/item_kinds.gd")
	var fingers: Array = items.items.values().filter(func(it): return it.kind == "finger")
	_check(player.injury[0] == 0b11 and player.injury[1] == 0b11 and player.fingers_missing() == 4,
			"o golpe levou o polegar e o indicador das duas mãos")
	_check(fingers.size() == 4 and kinds.label(fingers[0]).begins_with(player.player_name),
			"os 4 dedos caíram na mesa como itens (%s)" % (kinds.label(fingers[0]) if fingers.size() > 0 else "nenhum"))
	var glove: MeshInstance3D = player._hands[0]
	_check(not glove.get_node("Hand_R_Thumb").visible and glove.get_node("Hand_R_StumpThumb").visible
			and glove.get_node("Hand_R_Middle").visible and not glove.get_node("Hand_R_StumpMiddle").visible,
			"a luva fica sem o polegar e o indicador, com o curativo no lugar")
	await create_timer(0.3).timeout
	# Outra folha: sem dedos ela treme mesmo segurando perto; e o golpe sem papel passando da lâmina
	# não corta nada, mas pega a mão que estiver embaixo dela.
	items.give(1, "sheet", {"wet": false})
	await create_timer(0.3).timeout
	g.zone.interact(player)
	await physics_frame
	g.place_hands(0.01)
	_check(is_equal_approx(g.shake_now(), 4 * g.FINGER_SHAKE), "sem dedos, a folha treme mesmo segurando perto")
	_check(_place_for(g, g.HAND_LOST), "dá para pôr o meio da palma passando da linha")
	await _cut_click(player, swing)
	var hands: Array = items.items.values().filter(func(it): return it.kind == "hand")
	_check(player.hands_left() == 0 and hands.size() == 2 and g.pieces_left == stats.rows_per_sheet,
			"sem papel passando, o golpe não corta a folha, mas leva as mãos que estavam embaixo da lâmina")
	g.request_leave()
	await create_timer(0.4).timeout
	_check(not glove.get_node("Hand_R_Glove").visible and glove.get_node("Hand_R_StumpWrist").visible
			and not player.character.gloves[0].visible, "sem a mão: curativo na ponta da manga, e o boneco sem a luva")
	await _look(player, Vector3(2.62, 0, -1.4), Vector3(2.3, 0.78, -1.75), "19c_dedos_na_mesa")
	# Sem as duas mãos a resma não vem, e o que está na mão escorrega andando.
	player.global_position = stand
	await physics_frame
	var ream: Node = items.spawn("ream", Transform3D(Basis.IDENTITY, stand + Vector3(0.0, 0.3, 0.4)))
	await create_timer(0.3).timeout
	_check(ream.get_prompt(player) == "Needs both hands to carry", "a resma pede as duas mãos")
	items.request_pickup(ream.id)
	await create_timer(0.3).timeout
	_check(player.held_item() == null, "sem uma das mãos, a resma não vem")
	items.consume(ream)
	var slipping: Node = items.give(1, "sheet", {"wet": false})
	await create_timer(0.3).timeout
	seed(5)
	var steps := 0
	while player.held_item() != null and steps < 400:
		player._maybe_slip(0.1, 2.0)
		steps += 1
	_check(player.held_item() == null, "sem dedos, o que está na mão escorrega andando (%d passos de 0,1 s)" % steps)
	await physics_frame
	for it in fingers + hands + [slipping]:
		items.consume(it)
	player.heal()
	_check(player.fingers_missing() == 0 and glove.get_node("Hand_R_Thumb").visible and glove.get_node("Hand_R_Glove").visible
			and not glove.get_node("Hand_R_StumpThumb").visible, "mãos de volta (partida nova)")
	await create_timer(0.3).timeout


## Loja: o PC mostra o navegador; usando, a câmera vai para a tela, as luvas vão para o teclado e o
## mouse, e o mouse anda com o cursor. Comprar papel e um cartucho genérico (o pedido caro demais
## não passa), a caixa de cada loja chega na porta com a campainha, abrir a caixa solta o que
## veio, a resma volta para o estoque e o cartucho genérico entra na impressora: a folha sai com a
## cor errada e as notas dela valem menos.
func _test_shop(kitnet: Node3D, player: CharacterBody3D) -> void:
	var pc: Node3D = kitnet.computer
	var items: Node = kitnet.items
	var printer: Node3D = kitnet.printer
	var supply: Node3D = kitnet.paper_supply
	var wallet: Node = kitnet.wallet
	_check(pc != null and wallet != null and kitnet.deliveries != null, "PC, dinheiro e entregas montados")
	_check(wallet.cash == wallet.START_CASH, "o grupo começa com as economias ($%d)" % wallet.cash)
	_check(supply.START_STOCK == 3, "começa com só 3 resmas em casa")
	_check(printer.has_cartridge and printer.brand == "original", "a impressora vem com o cartucho original")
	var screen: MeshInstance3D = kitnet.model.find_child("MACHINE_PC_Screen", true, false)
	_check(screen != null and screen.material_override is ShaderMaterial, "a tela do monitor mostra o navegador")
	await _look(player, Vector3(1.9, 0, -3.7), Vector3(1.8, 0.95, -4.7), "40_pc")

	# Sentar no PC: câmera na tela, luva direita no mouse e esquerda no teclado.
	player.global_position = Vector3(1.8, 0.05, -3.9)
	await physics_frame
	_check(pc._prompt(player) == "[E] Use the computer", "o PC oferece usar")
	pc.zone.interact(player)
	await physics_frame
	_check(player.operating == pc, "usando o PC")
	await create_timer(player.STATION_CAMERA_TIME + 0.15).timeout
	_check(root.get_camera_3d() == player._station_cam, "a câmera foi para a frente da tela")
	var right: MeshInstance3D = player._press_hands[0]
	var mouse: Node3D = pc._mouse
	_check(right.visible and right.global_position.distance_to(mouse.global_position) < 0.15,
			"a luva direita está no mouse (%.2f m)" % right.global_position.distance_to(mouse.global_position))
	var mouse_before := mouse.position
	await _pc_click(player, pc, "go:ink")
	_check(pc.page == "ink", "clicar no favorito abre a loja de tinta")
	_check(mouse.position.distance_to(mouse_before) > 0.005, "o mouse anda na mesa com o cursor")
	await _shot("41_pc_loja_de_tinta")

	# Comprar: um cartucho genérico e duas resmas.
	await _pc_click(player, pc, "add:ink_generic")
	await _pc_click(player, pc, "go:office")
	await _pc_click(player, pc, "add:ream")
	await _pc_click(player, pc, "add:ream")
	_check(pc.cart.get("ream", 0) == 2 and pc.cart.get("ink_generic", 0) == 1, "2 resmas e 1 cartucho no carrinho")
	await _shot("42_pc_loja_de_papel")
	await _pc_click(player, pc, "go:cart")
	var total: int = pc.Catalog.total(pc.cart)
	_check(total == 2 * 9 + 19 + 2 * 5, "total com o frete das duas lojas ($%d)" % total)
	await _shot("43_pc_carrinho")
	# Caro demais: três originais não cabem no dinheiro, o botão de pagar fica apagado.
	await _pc_click(player, pc, "go:ink")
	for i in 3:
		await _pc_click(player, pc, "add:ink_original")
	await _pc_click(player, pc, "go:cart")
	_check(pc.browser.action_at(_button_center(pc, "checkout")) == "", "sem dinheiro, o botão de pagar não funciona")
	for i in 3:
		await _pc_click(player, pc, "dec:ink_original")
	_check(not pc.cart.has("ink_original"), "o menos tira do carrinho")
	await _pc_click(player, pc, "checkout")
	_check(wallet.cash == wallet.START_CASH - total, "pagou o pedido (sobrou $%d)" % wallet.cash)
	_check(pc.page == "done" and pc.cart.is_empty(), "pedido confirmado e carrinho vazio")
	_check(kitnet.deliveries.on_the_way.size() == 2, "duas caixas a caminho, uma por loja")
	await _shot("44_pc_pedido_feito")
	pc.request_leave()
	await physics_frame
	_check(player.operating == null, "[E] sai do PC")
	await create_timer(player.STATION_CAMERA_TIME + 0.1).timeout

	# A entrega: as caixas aparecem na porta e a campainha toca.
	for entry in kitnet.deliveries._pending:
		entry["left"] = 0.3
	await create_timer(0.6).timeout
	var parcels: Array = items.items.values().filter(func(i): return i.kind == "parcel")
	_check(parcels.size() == 2, "chegaram 2 caixas (%d)" % parcels.size())
	_check(kitnet.deliveries._bell.playing, "a campainha tocou")
	_check(kitnet.deliveries.on_the_way.is_empty(), "nada mais a caminho")
	var knock: Vector3 = kitnet.model.find_child("POINT_Knock", true, false).global_position
	_check(parcels.all(func(p): return Vector2(p.global_position.x - knock.x, p.global_position.z - knock.z).length() < 1.2),
			"as caixas ficam no corredor, na frente da porta")
	await create_timer(1.0).timeout
	await _look(player, knock + Vector3(1.4, 0, 0.3), knock, "45_caixas_na_porta")

	# Abrir a caixa do papel: saem as duas resmas.
	var office: Node = parcels.filter(func(p): return p.data["from"] == "OFFICE+")[0]
	var ink_box: Node = parcels.filter(func(p): return p.data["from"] == "INK-O-RAMA")[0]
	player.global_position = office.global_position + Vector3(0.8, 0, 0)
	await physics_frame
	_check(office.get_prompt(player).begins_with("[E] Open parcel from OFFICE+"), "a caixa oferece abrir")
	items.request_pickup(office.id)
	await physics_frame
	_check(player.held_item() == null, "a caixa não vai para a mão")
	var reams_before: int = items.items.values().filter(func(i): return i.kind == "ream").size()
	var office_id: int = office.id
	office.interact(player)
	await create_timer(1.0).timeout
	var reams: Array = items.items.values().filter(func(i): return i.kind == "ream")
	_check(reams.size() == reams_before + 2 and not items.items.has(office_id), "abriu a caixa e saíram 2 resmas")
	ink_box.interact(player)
	await create_timer(1.0).timeout
	var carts: Array = items.items.values().filter(func(i): return i.kind == "cartridge")
	_check(carts.size() == 1 and carts[0].data["brand"] == "generic", "da outra caixa saiu o cartucho genérico")
	await _look(player, knock + Vector3(1.4, 0, 0.3), knock, "46_caixas_abertas")

	# A resma volta para o estoque.
	var ream: Node = reams[reams.size() - 1]
	player.global_position = ream.global_position + Vector3(0.5, 0, 0)
	await physics_frame
	items.request_pickup(ream.id)
	await physics_frame
	player.global_position = Vector3(3.3, 0.05, -4.0)
	await physics_frame
	var stock: int = supply.stock
	_check(supply._prompt(player).begins_with("[E] Put the ream back"), "com a resma na mão, o estoque oferece guardar")
	supply.zone.interact(player)
	await physics_frame
	_check(supply.stock == stock + 1 and player.held_item() == null, "a resma voltou para o estoque")

	# O cartucho genérico entra na impressora; o original vem para a mão.
	var cart: Node = carts[0]
	player.global_position = cart.global_position + Vector3(0.5, 0, 0)
	await physics_frame
	items.request_pickup(cart.id)
	await physics_frame
	_check(player.held_item() == cart, "pegou o cartucho (cartucho em %s, jogador em %s, na mão de %d)"
			% [cart.global_position, player.global_position, cart.holder])
	player.global_position = Vector3(2.3, 0.05, -3.9)
	await physics_frame
	var old_ink: float = printer.ink
	_check(printer._cartridge_prompt(player).begins_with("[E] Swap ink cartridge"), "a tampa oferece trocar o cartucho")
	printer.cartridge_zone.interact(player)
	await physics_frame
	var old: Node = player.held_item()
	_check(printer.brand == "generic" and is_equal_approx(printer.ink, 1.0), "o genérico entrou cheio")
	_check(old != null and old.kind == "cartridge" and old.data["brand"] == "original" and is_equal_approx(old.data["ink"], old_ink),
			"o original velho veio para a mão")
	await _look(player, Vector3(2.62, 0, -3.75), Vector3(2.3, 0.85, -4.6), "47_cartucho_na_mao")
	# Imprimir com ele: a folha sai com a cor errada.
	printer.paper = 1
	printer.powered = true
	printer.warm = printer.stats.warmup_seconds
	await create_timer(printer.stats.seconds_per_sheet + 0.3).timeout
	printer.powered = false
	var off_sheets: Array = items.items.values().filter(func(i): return i.kind == "sheet" and i.data.get("offcolor", false))
	_check(off_sheets.size() == 1, "com o genérico a folha sai com a cor errada")
	await _look(player, Vector3(2.3, 0, -3.75), Vector3(2.3, 0.8, -4.45), "48_folha_cor_errada")
	if not off_sheets.is_empty():
		_check(ItemKinds.label(off_sheets[0]).contains("off-color"), "o nome da folha avisa a cor errada")
		items.consume(off_sheets[0])
	# As notas dela valem menos (o montinho da guilhotina).
	var g: Node3D = kitnet.guillotine
	g.sheet_offcolor = true
	g.sheet_wet = false
	g._add_to_pile(6, 0, 6.0, Rect2())
	var pile: Node = items.items.get(g._pile_id)
	_check(pile != null and pile.data.get("offcolor", 0) >= 6 and pile.data.get("top_offcolor", false),
			"as notas do genérico saem marcadas com a cor errada")
	_check(pile != null and pile.data.get("worth", 0.0) <= pile.data.get("count", 0) - 6 * (1.0 - ItemKinds.OFFCOLOR_WORTH) + 0.01,
			"as notas com a cor errada valem menos")
	g.sheet_offcolor = false
	if pile != null:
		await _look(player, Vector3(2.35, 0, -1.6), pile.global_position, "49_notas_cor_errada")
		items.consume(pile)
	# De volta o original; sem cartucho nenhum a impressora avisa.
	printer.cartridge_zone.interact(player)
	await physics_frame
	_check(printer.brand == "original" and player.held_item() != null and player.held_item().data["brand"] == "generic",
			"trocou de volta para o original")
	items.consume(player.held_item())
	await physics_frame
	printer.cartridge_zone.interact(player)
	await physics_frame
	printer.powered = true
	printer.warm = printer.stats.warmup_seconds
	printer.paper = 1
	await physics_frame
	_check(not printer.has_cartridge and printer._screen_text() == "NO CARTRIDGE", "sem cartucho o visor mostra NO CARTRIDGE")
	printer.cartridge_zone.interact(player)
	await physics_frame
	_check(printer.has_cartridge and player.held_item() == null, "o cartucho voltou para a impressora")
	printer.powered = false
	printer.paper = 0


## Clica no botão `action` do navegador com o mouse de verdade (o cursor anda até o meio dele).
func _pc_click(player: CharacterBody3D, pc: Node3D, action: String) -> void:
	var target := _button_center(pc, action)
	if target.x < 0.0:
		_check(false, "o navegador tem o botão %s" % action)
		return
	player._input(_mouse_motion((target - pc._cursor) / pc.CURSOR_SPEED))
	await process_frame
	player._input(_left_click())
	await physics_frame
	await process_frame


func _button_center(pc: Node3D, action: String) -> Vector2:
	for b in pc.browser._buttons:
		if is_instance_valid(b) and b.get_meta("action") == action:
			return b.get_global_rect().get_center()
	return Vector2(-1, -1)


## Varal: a folha molhada pendura no varal e seca (o brilho some); com o ventilador ligado seca
## mais rápido e tremula; tirar no meio leva ela úmida e pendurar de novo continua de onde parou;
## seca, ela deixa de ser molhada (as notas não borram); varal cheio não aceita mais.
func _test_clothesline(kitnet: Node3D, player: CharacterBody3D) -> void:
	var line: Node3D = kitnet.clothesline
	var fan: Node3D = kitnet.fan
	var items: Node = kitnet.items
	_check(line != null and fan != null, "varal e ventilador montados")
	_check(not kitnet.model.find_children("*", "MeshInstance3D", true, false).any(
			func(m): return m.name == "MACHINE_ClothesLine" and m.mesh.get_surface_count() > 3),
			"o varal do modelo não tem mais folhas desenhadas")
	# Pendurar uma folha molhada (ventilador desligado).
	var under := Vector3(5.75, 0.05, -3.1)
	player.global_position = under
	await physics_frame
	if fan.powered:
		fan.zone.interact(player)
		await physics_frame
	var sheet: Node = items.give(1, "sheet", {"wet": true})
	await create_timer(0.3).timeout
	_check(line._prompt(player).begins_with("[E] Hang the sheet to dry (turn on the fan"), "o varal oferece pendurar e lembra do ventilador")
	line.zone.interact(player)
	await physics_frame
	var hung: Array = items.items.values().filter(func(i): return i.kind == "sheet" and i.data.get("hanging", false))
	_check(player.held_item() == null and hung.size() == 1, "a folha foi para o varal")
	if hung.is_empty():
		return
	sheet = hung[0]
	var slot_xf: Transform3D = line.slot_transform(0)
	_check(sheet.global_position.distance_to(slot_xf.origin) < 0.01 and sheet.freeze, "pendurada na primeira vaga, parada")
	_check(absf(sheet.global_basis.y.x) > 0.99, "pendurada em pé, com a face para o lado")
	# Sem ventilador, seca devagar; ligado, bem mais rápido.
	var w0: float = line._wetness[sheet.id]
	await create_timer(1.0).timeout
	var calm: float = w0 - line._wetness[sheet.id]
	fan.zone.interact(player)
	await physics_frame
	_check(fan.powered, "o ventilador ligou")
	await create_timer(fan.SPIN_TIME + 0.1).timeout
	var blades: Basis = kitnet.ambience.fan_blades.transform.basis
	var w1: float = line._wetness[sheet.id]
	await create_timer(1.0).timeout
	var windy: float = w1 - line._wetness[sheet.id]
	_check(calm > 0.0 and windy > calm * 2.5, "com o ventilador seca mais rápido (%.3f contra %.3f por segundo)" % [windy, calm])
	_check(not kitnet.ambience.fan_blades.transform.basis.is_equal_approx(blades), "ligado, as pás giram")
	var mesh: MeshInstance3D = sheet.get_node("Mesh")
	_check(mesh.get_instance_shader_parameter("flutter") > line.FLUTTER_CALM * 2.0, "no vento a folha tremula")
	_check(mesh.get_instance_shader_parameter("wet") < 0.95, "o brilho de molhada vai sumindo (%.2f)" % mesh.get_instance_shader_parameter("wet"))
	await _look(player, Vector3(5.75, 0, -2.5), Vector3(5.75, 2.1, -3.2), "50_folha_no_varal")
	# Tirar no meio: vem úmida; pendurar de novo continua de onde parou.
	items.request_pickup(sheet.id)
	await physics_frame
	_check(player.held_item() == sheet and not sheet.data.get("hanging", true), "pegou a folha do varal")
	var damp: float = sheet.data.get("wetness", 1.0)
	_check(sheet.data["wet"] and damp < 0.95 and damp > 0.0, "ainda úmida (%.2f)" % damp)
	_check(ItemKinds.label(sheet).begins_with("damp sheet"), "o nome diz quanto já secou (%s)" % ItemKinds.label(sheet))
	line.zone.interact(player)
	await physics_frame
	hung = items.items.values().filter(func(i): return i.kind == "sheet" and i.data.get("hanging", false))
	_check(hung.size() == 1 and absf(hung[0].data.get("wetness", 1.0) - damp) < 0.05, "pendurada de novo, continua de onde parou")
	# Seca de vez.
	sheet = hung[0]
	line._wetness[sheet.id] = 0.01
	await create_timer(0.3).timeout
	_check(not sheet.data["wet"] and not line._wetness.has(sheet.id), "secou: não está mais molhada")
	var dry_wet: float = sheet.get_node("Mesh").get_instance_shader_parameter("wet")
	_check(dry_wet == 0.0, "seca, sem brilho de tinta (%.2f)" % dry_wet)
	await _look(player, Vector3(5.75, 0, -2.5), Vector3(5.75, 2.1, -3.2), "51_folha_seca")
	items.request_pickup(sheet.id)
	await physics_frame
	_check(ItemKinds.label(sheet) == "printed sheet", "a folha seca é só uma folha impressa")
	# Na guilhotina, a folha seca não borra.
	var g: Node3D = kitnet.guillotine
	player.global_position = Vector3(2.35, 0.05, -1.35)
	await physics_frame
	g.zone.interact(player)
	await physics_frame
	_check(g.has_sheet() and not g.sheet_wet, "na guilhotina, a folha seca não vai borrar")
	g.request_leave()
	await physics_frame
	g.pieces_left = 0
	g._rows.clear()
	g.stack_count = 0
	g._send_state()
	await create_timer(player.STATION_CAMERA_TIME + 0.1).timeout
	# Varal cheio: 15 vagas.
	player.global_position = under
	await physics_frame
	for i in line.slots.size():
		items.give(1, "sheet", {"wet": true})
		await physics_frame
		line.zone.interact(player)
		await physics_frame
	_check(line.free_slots() == 0, "15 folhas no varal")
	await _look(player, Vector3(5.75, 0, -2.4), Vector3(5.85, 2.0, -3.6), "52_varal_cheio")
	items.give(1, "sheet", {"wet": true})
	await physics_frame
	_check(line._prompt(player) == "The clothesline is full", "varal cheio não aceita mais")
	line.zone.interact(player)
	await physics_frame
	_check(player.held_item() != null, "a folha continua na mão")
	for item in items.items.values():
		if item.kind == "sheet":
			items.consume(item)
	fan.zone.interact(player)
	await physics_frame
	_check(not fan.powered, "o ventilador desligou")


## Máquina de lavar: a tampa abre e fecha, os montinhos entram e saem do cesto, o botão lava e
## centrifuga com a tampa travada; centrifugando com carga ímpar ela anda, segurada fica parada e
## faz menos barulho; no fim as notas saem usadas (valem mais); parada fora do lugar, empurra de volta.
func _test_washer(kitnet: Node3D, player: CharacterBody3D) -> void:
	var w: Node3D = kitnet.washer
	var items: Node = kitnet.items
	_check(w != null and w.phase == w.Phase.IDLE and not w.lid_open, "máquina de lavar montada, parada e fechada")
	if w == null:
		return
	var body: Node3D = w.get_parent()
	var home: Vector3 = body.global_position
	var front := Vector3(5.95, 0.05, -3.88)
	player.global_position = front
	await physics_frame
	_check(w._lid_prompt(player) == "[E] Open the lid", "a tampa oferece abrir")
	_check(w._panel_prompt(player) == "Put bills in to wash them", "vazia, o botão pede notas")
	w.lid_zone.interact(player)
	await create_timer(0.6).timeout
	_check(w.lid_open and absf(w._lid.rotation.x + w.LID_OPEN) < 0.01, "a tampa abriu (quase em pé)")
	var pile: Node = items.give(1, "bills", {"count": 12, "worth": 12.0, "crooked": 0})
	await physics_frame
	_check(w._drum_prompt(player).begins_with("[E] Put the bills in"), "o cesto aceita o montinho")
	var crisp := ItemKinds.value(pile.data)
	_check(is_equal_approx(crisp, 12.0 * ItemKinds.CRISP_WORTH), "nota sem lavar vale menos (%.1f de 12)" % crisp)
	w.drum_zone.interact(player)
	await physics_frame
	_check(player.held_item() == null and w.contents.size() == 1 and not w.contents[0].has("resting"),
			"o montinho foi para o cesto")
	_check(w._piles.get_child_count() == 1, "dá para ver o montinho lá dentro")
	_check(w._drum_prompt(player).begins_with("[E] Take out the 12 bills"), "de mão vazia, oferece tirar")
	w.drum_zone.interact(player)
	await physics_frame
	var back: Node = player.held_item()
	_check(back != null and back.kind == "bills" and back.data.get("count", 0) == 12 and w.contents.is_empty(),
			"tirou o montinho de volta")
	w.drum_zone.interact(player)
	await physics_frame
	await _look(player, front, w.global_transform * w.DRUM_CENTER, "53_cesto_com_notas")
	_check(w._panel_prompt(player) == "Close the lid to start", "de tampa aberta não liga")
	w._start(1)
	_check(w.phase == w.Phase.IDLE, "nem forçando")
	# Lavar.
	w.lid_zone.interact(player)
	await create_timer(0.4).timeout
	_check(not w.lid_open and w._panel_prompt(player).begins_with("[E] Start the wash"), "fechada, o botão liga")
	w.panel_zone.interact(player)
	await create_timer(0.5).timeout
	_check(w.phase == w.Phase.WASH and w.noise() == w.NOISE_WASH, "lavando, com barulho")
	_check(w._screen.text.begins_with("WASH "), "o visor conta o tempo (%s)" % w._screen.text)
	w.lid_zone.interact(player)
	await physics_frame
	_check(not w.lid_open and w._lid_prompt(player).begins_with("The lid is locked"), "a tampa trava lavando")
	_check(w._hum.playing, "o motor faz barulho")
	# Centrifugar: uma carga só (desequilibrada), ninguém segurando, a máquina anda.
	w.time_left = 0.05
	await create_timer(0.2).timeout
	_check(w.phase == w.Phase.SPIN and w.unbalanced(), "centrifugando, desequilibrada")
	await create_timer(1.5).timeout
	var walked := body.global_position.distance_to(home)
	_check(w.offset.length() > 0.03 and walked > 0.03, "solta, a máquina sai andando (%.2f m)" % walked)
	_check((body.global_position - home).x < 0.0, "anda para a frente, longe da parede")
	_check(w.noise() == w.NOISE_SPIN and w._body_prompt(player) == "Hold [E] to hold the washer still",
			"bate e faz barulho, pedindo para segurar")
	await _look(player, Vector3(5.75, 0, -3.3), body.global_position + Vector3.UP * 0.6, "54_maquina_andando")
	w.body_zone.begin_hold(player)
	await create_timer(0.3).timeout
	var held_at: Vector3 = w.offset
	await create_timer(1.0).timeout
	_check(w.steadied and w.offset.distance_to(held_at) < 0.002, "segurada, fica parada")
	_check(w.noise() == w.NOISE_HELD, "segurada, faz menos barulho")
	w.body_zone.end_hold(player)
	# Fim: as notas saem usadas.
	w.time_left = 0.05
	await create_timer(0.3).timeout
	_check(w.phase == w.Phase.IDLE and w.contents.size() == 1 and w.contents[0].get("worn", 0) == 12 \
			and w.contents[0].get("top_worn", false), "acabou: as notas saíram usadas")
	_check(w._screen.text == "END", "o visor diz que acabou")
	w.lid_zone.interact(player)
	await create_timer(0.4).timeout
	w.drum_zone.interact(player)
	await physics_frame
	var worn: Node = player.held_item()
	_check(worn != null and ItemKinds.label(worn) == "12 bills (worn)", "o montinho diz que está usado (%s)" % (ItemKinds.label(worn) if worn else "nada"))
	if worn != null:
		_check(is_equal_approx(ItemKinds.value(worn.data), 12.0), "lavado, vale tudo (%.1f)" % ItemKinds.value(worn.data))
		var mesh: MeshInstance3D = worn.get_node("Mesh")
		var top_mat: Material = mesh.mesh.surface_get_material(0)
		_check(top_mat is BaseMaterial3D and top_mat.albedo_texture == ItemKinds.BILL_FRONT_WORN, "com a textura desbotada e vincada")
	await _look(player, front, body.global_position + Vector3.UP * 0.9, "55_notas_usadas")
	# Parada fora do lugar: empurrar de volta.
	_check(w._body_prompt(player) == "Hold [E] to push the washer back", "fora do lugar, oferece empurrar de volta")
	w.body_zone.begin_hold(player)
	await create_timer(w.HOSE_LENGTH / w.PUSH_SPEED + 0.5).timeout
	w.body_zone.end_hold(player)
	await create_timer(0.3).timeout
	_check(w.offset.length() < 0.001 and body.global_position.distance_to(home) < 0.003, "empurrada de volta para o lugar")
	if worn != null:
		items.consume(worn)
	w.lid_zone.interact(player)
	await physics_frame


## Contadora: o montinho entra no funil e ela conta sozinha para a bandeja; nota borrada emperra,
## e segurar [E] destrava jogando ela nas rejeitadas do lado; com 20 na bandeja ela para e [E]
## cinta o maço (com a nota de qualidade); antes disso, dá para pegar as contadas soltas.
func _test_counter(kitnet: Node3D, player: CharacterBody3D) -> void:
	var c: Node3D = kitnet.cash_counter
	var items: Node = kitnet.items
	_check(c != null and c.hopper.is_empty() and c.tray.is_empty() and not c.jammed, "contadora montada e vazia")
	if c == null:
		return
	var table: MeshInstance3D = kitnet.model.find_child("Table", true, false)
	_check(table != null and table.mesh.get_surface_count() <= 4, "a mesa não tem mais maços desenhados")
	var spot := Vector3(3.0, 0.05, -2.9)
	player.global_position = spot
	await physics_frame
	_check(c._screen.text == "000", "o visor começa no zero (%s)" % c._screen.text)
	# Um montinho lavado: conta tudo para a bandeja.
	items.give(1, "bills", {"count": 12, "worth": 12.0, "worn": 12, "top_worn": true})
	await physics_frame
	_check(c._hopper_prompt(player) == "[E] Feed 12 bills into the counter", "o funil aceita o montinho")
	c.hopper_zone.interact(player)
	await physics_frame
	_check(player.held_item() == null and c.hopper.get("count", 0) == 12 and c.counting(), "as notas entraram e ela começou a contar")
	_check(c.noise() > 0.0 and c._whirr.playing, "contando faz barulho")
	await create_timer(0.5).timeout
	var midway: int = c.tray.get("count", 0)
	_check(midway > 0 and midway < 12, "conta uma por uma (%d na bandeja)" % midway)
	await _look(player, spot, c.global_position + Vector3.UP * 0.08, "56_contadora")
	await create_timer(1.2).timeout
	_check(c.tray.get("count", 0) == 12 and c.hopper.is_empty() and c._screen.text == "012", "contou as 12 (%s)" % c._screen.text)
	_check(c._tray_prompt(player) == "[E] Take the 12 counted bills (a bundle is 20)", "a bandeja diz quantas faltam para o maço")
	# Notas borradas emperram; segurar destrava e elas vão para as rejeitadas.
	items.give(1, "bills", {"count": 2, "worth": 2.0, "smudged": 2, "top_smudged": true, "worn": 2})
	await physics_frame
	c.hopper_zone.interact(player)
	await create_timer(0.4).timeout
	_check(c.jammed and c.tray.get("count", 0) == 12 and c.noise() == 0.0, "a borrada emperrou a máquina")
	_check(c._body_prompt(player).begins_with("Hold [E] to clear the jam"), "pede para segurar e destravar")
	c.body_zone.begin_hold(player)
	await create_timer(c.JAM_CLEAR * 2.0 + 0.6).timeout
	c.body_zone.end_hold(player)
	_check(not c.jammed and c.hopper.is_empty(), "destravou as duas")
	var reject: Node = items.items.get(c._reject_id)
	_check(reject != null and reject.data.get("count", 0) == 2 and reject.data.get("smudged", 0) == 2,
			"as borradas foram para as rejeitadas do lado (%s)" % (ItemKinds.label(reject) if reject else "nada"))
	_check(reject != null and reject.global_position.distance_to(c.global_position) < 0.35 and reject.global_position.y > 0.7,
			"em cima da mesa, do lado da máquina")
	# Completa o maço: para com 20, e o resto espera no funil.
	items.give(1, "bills", {"count": 10, "worth": 10.0, "worn": 10, "top_worn": true})
	await physics_frame
	c.hopper_zone.interact(player)
	await create_timer(1.4).timeout
	_check(c.tray.get("count", 0) == c.BUNDLE_SIZE and c.hopper.get("count", 0) == 2 and not c.counting(),
			"parou com o maço completo (2 esperando no funil)")
	_check(c._screen.text == "20 A", "o visor mostra o maço e a nota (%s)" % c._screen.text)
	_check(c._tray_prompt(player) == "[E] Take the bundle (20 bills, grade A)", "cintou sozinha: a bandeja oferece o maço")
	_check(c._tray_stack.mesh == ItemKinds._bundle_mesh(false, true, "A"), "a bandeja mostra o maço cintado")
	c.tray_zone.interact(player)
	await physics_frame
	var bundle: Node = player.held_item()
	_check(bundle != null and bundle.kind == "bundle" and ItemKinds.label(bundle) == "bundle of 20 bills (grade A)",
			"cintou o maço (%s)" % (ItemKinds.label(bundle) if bundle else "nada"))
	if bundle != null:
		_check(is_equal_approx(ItemKinds.value(bundle.data), 20.0), "o maço lavado vale tudo (%.1f)" % ItemKinds.value(bundle.data))
		var mesh: Mesh = bundle.get_node("Mesh").mesh
		var band: Material = mesh.surface_get_material(mesh.get_surface_count() - 1)
		_check(band.albedo_color == ItemKinds.BAND_COLORS["A"], "com a cinta de papel dourada (nota A)")
		_check((bundle.get_child(0).shape as BoxShape3D).size == ItemKinds.SIZES["bundle"], "maço gordinho, do tamanho dele")
	await create_timer(0.5).timeout
	_check(c.tray.get("count", 0) == 2, "e voltou a contar o resto")
	await _look(player, spot, c.global_position + Vector3.UP * 0.05, "57_maco_cintado")
	# As notas de qualidade.
	_check(ItemKinds.grade({"count": 20, "worth": 20.0}) == "C", "sem lavar, o maço perfeito é C")
	_check(ItemKinds.grade({"count": 20, "worth": 12.0, "worn": 20}) == "C", "lavado mas com a cor errada, C")
	_check(ItemKinds.grade({"count": 20, "worth": 12.0}) == "D", "cor errada e sem lavar, D")
	_check(ItemKinds.grade({"count": 20, "worth": 17.0, "worn": 20}) == "B", "lavado com umas tortas, B")
	# Mão cheia, a bandeja só conta; de mão vazia, pega as soltas.
	_check(c._tray_prompt(player) == "2 counted bills", "de mão cheia a bandeja só mostra")
	if bundle != null:
		items.consume(bundle)
	await physics_frame
	c.tray_zone.interact(player)
	await physics_frame
	var loose: Node = player.held_item()
	_check(loose != null and loose.kind == "bills" and loose.data.get("count", 0) == 2 and c.tray.is_empty(),
			"pegou as 2 contadas soltas")
	for item in [loose, reject]:
		if item != null:
			items.consume(item)
	await physics_frame


## Frigideira: nasce no fogão, pega na mão, o clique bate (a frigideira levanta e desce); acertando
## alguém sai o "BONK!", e quem levou cai com as estrelinhas, solta o que segurava e levanta depois;
## errando na parede, "clang".
func _test_pan(kitnet: Node3D, player: CharacterBody3D) -> void:
	var items: Node = kitnet.items
	var pans: Array = items.items.values().filter(func(i): return i.kind == "pan")
	_check(pans.size() == 1, "tem uma frigideira no mapa")
	if pans.is_empty():
		return
	var pan: Node = pans[0]
	_check(pan.global_position.distance_to(kitnet.PAN_START.origin) < 0.05 and pan.freeze, "parada em cima do fogão")
	_check(ItemKinds.label(pan) == "frying pan", "chama frying pan")
	await _look(player, Vector3(2.8, 0, -1.25), pan.global_position, "58_frigideira_no_fogao")
	items.request_pickup(pan.id)
	await create_timer(0.4).timeout
	_check(player.held_item() == pan, "pegou a frigideira")
	# Alguém parado na frente para levar o bonk.
	var victim: CharacterBody3D = load("res://scenes/player.tscn").instantiate()
	victim.setup(5555, "Victim", 2, Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(3.15, 0.05, -3.4)))
	kitnet.get_node("Players").add_child(victim)
	await physics_frame
	player.global_position = Vector3(3.9, 0.05, -3.4)
	player.rotation.y = PI / 2.0
	player.head.rotation.x = -0.05
	await create_timer(0.5).timeout
	var rest: Transform3D = pan.global_transform
	player.swing()
	await create_timer(0.09).timeout
	_check(player.swinging() and pan.global_transform.origin.distance_to(rest.origin) > 0.03, "o golpe mexe a frigideira (levanta)")
	await create_timer(0.08).timeout
	await _shot("59_golpe")
	await create_timer(0.1).timeout
	_check(player.last_swing == "bonk" and player.last_bonked == victim, "acertou quem estava na frente")
	_check(kitnet.get_children().any(func(n): return n is Label3D and n.text == "BONK!"), "apareceu o BONK!")
	await _shot("60_bonk")
	# Quem levou (aqui de mentira, porque o dono dele não está na sala): cai com as estrelinhas.
	victim._begin_fall(Vector3.FORWARD, player.BONK_SPEED)
	victim._stars_left = player.STARS_TIME
	await create_timer(0.6).timeout
	_check(victim.fallen and victim._stars.visible, "a vítima caiu com as estrelinhas")
	await _look(player, player.global_position - Vector3.UP * 0.05, victim.bonk_point(), "61_estrelinhas")
	await create_timer(player.SWING_TIME).timeout
	_check(not player.swinging(), "o golpe acaba e a frigideira volta")
	_check(pan.global_transform.origin.distance_to(player.hold_point.global_transform * ItemKinds.hold_offset("pan").origin) < 0.05,
			"de volta na mão, parada")
	# Na parede: clang.
	player.global_position = Vector3(4.2, 0.05, -4.4)
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0
	await create_timer(0.3).timeout
	player.swing()
	await create_timer(player.SWING_TIME + 0.1).timeout
	_check(player.last_swing == "clang", "na parede faz clang (%s)" % player.last_swing)
	player.global_position = Vector3(4.0, 0.05, -3.4)
	player.rotation.y = -PI / 2.0
	await create_timer(0.3).timeout
	player.swing()
	await create_timer(player.SWING_TIME + 0.1).timeout
	_check(player.last_swing == "miss", "no vazio, não acerta nada")
	# Levar o bonk: solta o que segura, cai por mais tempo e levanta com as estrelinhas ainda girando.
	player._get_bonked(Vector3.RIGHT)
	await physics_frame
	_check(player.fallen and player.dazed() and player.held_item() == null, "levou o bonk: caiu, soltou a frigideira e ficou tonto")
	await create_timer(1.5).timeout
	await _shot("62_tonto_primeira_pessoa")
	var waited := 1.5
	while player.fallen and waited < 6.0:
		await physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
	_check(waited > player.BONK_TIME - 0.2 and waited < player.BONK_TIME + 0.5, "fica caído uns %.1f s" % waited)
	_check(player.dazed(), "levanta ainda com as estrelinhas")
	await create_timer(player.STARS_TIME - player.BONK_TIME + 0.3).timeout
	_check(not player.dazed() and not player._stars.visible, "as estrelinhas passam")
	await create_timer(1.0).timeout
	victim.queue_free()
	items.consume(pan)
	items.spawn("pan", kitnet.PAN_START, {"resting": true})
	await physics_frame


func _test_neighbor(kitnet: Node3D, player: CharacterBody3D) -> void:
	var n: CharacterBody3D = kitnet.neighbor
	var S = n.State
	var items: Node = kitnet.items
	var door: AnimatableBody3D = kitnet.doors["301"]
	_check(not n.visible and n.state == S.HOME, "o vizinho começa em casa (escondido)")
	_check(kitnet.stashes.size() == 4, "4 esconderijos (%d)" % kitnet.stashes.size())
	# Barulho enche a paciência: uma fonte de barulho alto de mentira.
	var loud_script := GDScript.new()
	loud_script.source_code = "extends Node
func noise() -> float:
	return 0.8
"
	loud_script.reload()
	var loud := Node.new()
	loud.set_script(loud_script)
	loud.add_to_group("noise_source")
	kitnet.add_child(loud)
	n.enabled = true
	n.annoyance = n.BANG_AT - 0.002
	await create_timer(1.0).timeout
	_check(n.noise >= 0.8, "o barulho das máquinas soma (%.2f)" % n.noise)
	_check(n.annoyance > n.BANG_AT and n._banged, "a paciência vai acabando, e ele bate na parede (%.3f)" % n.annoyance)
	loud.queue_free()
	if kitnet.fan.powered:
		kitnet.fan._toggle(1)
	kitnet.printer.powered = false
	await create_timer(0.5).timeout
	var calm: float = n.annoyance
	await create_timer(1.0).timeout
	_check(n.annoyance < calm, "em silêncio, ele vai se acalmando")
	n.enabled = false
	n.annoyance = 0.0

	# Trancar a porta por dentro: a zona da tranca de barra.
	player.global_position = Vector3(4.1, 0.05, -1.0)
	await physics_frame
	door.lock_zone.press_fn.call(1)
	_check(door.locked, "a 301 tranca por dentro")
	_check(door.get_prompt(player) == "[E] Unlock", "de dentro, a porta trancada destranca")
	# 1. Trancada: bate e vai embora.
	n.visit()
	await create_timer(0.3).timeout
	_check(n.visible and kitnet.doors["303"].is_open, "ele sai do 303")
	var got := await _wait_neighbor(n, [S.KNOCK], 8.0)
	_check(got, "vem bater na 301")
	await create_timer(0.5).timeout
	await _look(player, Vector3(5.6, 0, 0.9), n.global_position + Vector3.UP * 1.4, "63_vizinho_batendo")
	player.global_position = Vector3(4.1, 0.05, -1.6)
	got = await _wait_neighbor(n, [S.LEAVE], 15.0)
	_check(got and not door.is_open, "com a porta trancada, ele desiste e volta para casa")
	got = await _wait_neighbor(n, [S.HOME], 10.0)
	_check(got and not n.visible and not kitnet.doors["303"].is_open, "e some no 303 com a porta fechada")
	_check(n.visits == 1, "a visita conta (a próxima vem mais cedo)")

	# 2. Destrancada e notas na mesa: entra, vê e corre ligando.
	door.interact(player)
	_check(not door.locked, "[E] na porta destranca")
	var bills_id: int = items.spawn("bills", Transform3D(Basis.IDENTITY, Vector3(3.6, 0.8, -1.9)), {"count": 6}).id
	player.global_position = Vector3(1.0, 0.05, -2.5)
	n.visit()
	got = await _wait_neighbor(n, [S.CALL], 30.0)
	_check(got and n.alarmed and n.calling, "entrou, viu as notas e foi ligar para a polícia")
	_check(n.global_position.distance_to(n.DOORMAT) < 0.4, "liga parado no capacho dele")
	await _look(player, Vector3(4.1, 0, 0.2), n.global_position + Vector3.UP * 1.5, "64_vizinho_ligando")
	# 3. Frigideira: corta a ligação e derruba.
	var pan: Node = items.items.values().filter(func(i): return i.kind == "pan")[0]
	pan.global_position = player.global_position + Vector3.UP * 0.9
	items.request_pickup(pan.id)
	await create_timer(0.3).timeout
	var to: Vector3 = n.global_position - player.global_position
	to.y = 0.0
	player.global_position = n.global_position - to.normalized() * 0.75 + Vector3.UP * 0.05
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = -0.05
	await create_timer(0.2).timeout
	player.swing()
	await create_timer(0.6).timeout
	_check(player.last_bonked == n and n.knocked_out() and not n.calling, "BONK: caiu e a ligação caiu")
	await create_timer(1.0).timeout
	_check(n.bonk_point().y < 0.6 and n._stars.visible, "desmaiado no chão com as estrelinhas")
	player._drop_held()
	await create_timer(0.3).timeout
	# 4. Arrastar até o capacho: acorda achando que sonhou.
	n._press(1)
	_check(player.dragging() and n.zone.get_prompt(player) == "[E] Let go", "arrasta pela gola")
	var start: Vector3 = n.body_position()
	var target := Vector3(3.4, 0.05, 0.35)
	for i in 240:
		var d: Vector3 = target - player.global_position
		d.y = 0.0
		if d.length() < 0.05:
			break
		player.global_position += d.normalized() * minf(1.5 / 60.0, d.length())
		player.rotation.y = PI
		await physics_frame
	await create_timer(1.2).timeout
	_check(n.body_position().distance_to(start) > 0.3, "o corpo vem junto (%.2f m)" % n.body_position().distance_to(start))
	_check(n.body_position().distance_to(n.DOORMAT) < n.HOME_RADIUS, "largado no capacho dele")
	await _look(player, player.global_position, n.body_position(), "65_vizinho_arrastado")
	player._update_interaction(0.016)
	n.request_let_go()
	_check(not player.dragging(), "solta")
	n._ko_left = 0.05
	await create_timer(0.4).timeout
	_check(not n.alarmed, "acorda no capacho achando que sonhou")
	got = await _wait_neighbor(n, [S.HOME], 12.0)
	_check(got, "e volta a dormir")

	# 5. Suborno: um maço e ele não viu nada.
	n.visit()
	await _wait_neighbor(n, [S.KNOCK], 8.0)
	n._alarm()
	await create_timer(0.3).timeout
	var bundle: Node = items.spawn("bundle", Transform3D(Basis.IDENTITY, player.global_position + Vector3.UP), {"count": 20, "worth": 20.0})
	var bundle_id: int = bundle.id
	items._set_holder(bundle_id, 1, bundle.global_transform, Vector3.ZERO, Vector3.ZERO)
	player.global_position = n.global_position + Vector3(0.6, 0.05, -0.3)
	_check(n.zone.get_prompt(player) == "[E] Bribe him with the bundle", "com o maço na mão, dá para subornar")
	n._press(1)
	_check(not n.calling and not n.alarmed and not items.items.has(bundle_id), "subornado: desliga e fica com o maço")
	await _wait_neighbor(n, [S.HOME], 12.0)

	# 6. Polícia: leva as notas da mesa e multa; o esconderijo salva o maço.
	var stash: Node = kitnet.stashes.filter(func(s): return s.spot_name == "the wardrobe")[0]
	var hidden: Node = items.spawn("bundle", Transform3D(Basis.IDENTITY, player.global_position + Vector3.UP), {"count": 20, "worth": 20.0})
	items._set_holder(hidden.id, 1, hidden.global_transform, Vector3.ZERO, Vector3.ZERO)
	player.global_position = Vector3(1.2, 0.05, -1.8)
	_check(stash.zone.get_prompt(player).begins_with("[E] Hide the bundle"), "o guarda-roupa esconde o que está na mão")
	stash._use(1)
	_check(stash.contents.size() == 1 and player.held_item() == null, "escondido no guarda-roupa")
	kitnet.police.call_cops()
	_check(kitnet.police.coming() and kitnet.police.alert_text() != "", "a polícia está a caminho (aviso no HUD)")
	kitnet.police.cancel()
	await create_timer(0.3).timeout
	stash._use(1)
	_check(player.held_item() != null and player.held_item().kind == "bundle", "tira o maço do esconderijo")
	items.consume(player.held_item())
	if items.items.has(bills_id):
		items.consume(items.items[bills_id])
	door.set_open(false)
	n.visits = 0
	await create_timer(1.0).timeout


func _test_trashbag(kitnet: Node3D, player: CharacterBody3D) -> void:
	var items: Node = kitnet.items
	var roll: Node3D = kitnet.bag_roll
	if player.held_item() != null:
		items.consume(player.held_item())
	player.global_position = Vector3(1.93, 0.05, -1.0)
	await physics_frame
	_check(roll.zone.get_prompt(player) == "[E] Tear off a trash bag", "o rolo de sacos na bancada")
	roll.zone.press_fn.call(1)
	await physics_frame
	var bag: Node = player.held_item()
	_check(bag != null and bag.kind == "trashbag" and ItemKinds.label(bag) == "empty trash bag", "destacou um saco vazio")
	if bag == null:
		return
	# No chão, no meio da kitnet.
	var spot := Vector3(3.3, 0.1, -1.5)
	player.global_position = spot + Vector3(0, -0.05, 0.8)
	items.request_drop(Transform3D(Basis.IDENTITY, spot), Vector3.ZERO)
	await create_timer(1.0).timeout
	var flat: Vector3 = (bag.get_child(0).shape as BoxShape3D).size
	# Dois maços e um montinho.
	var loads := [["bundle", {"count": 20, "worth": 20.0, "worn": 20}], ["bundle", {"count": 20, "worth": 20.0, "worn": 20}],
			["bills", {"count": 6, "worth": 6.0}]]
	for i in loads.size():
		var entry: Array = loads[i]
		var it: Node = items.spawn(entry[0], Transform3D(Basis.IDENTITY, player.global_position + Vector3.UP), entry[1])
		items._set_holder(it.id, 1, it.global_transform, Vector3.ZERO, Vector3.ZERO)
		await physics_frame
		if i == 0:
			_check(bag.get_prompt(player).begins_with("[E] Put the bundle of 20 bills (grade A) in the trash bag (0/10)"),
					"com o maço na mão, o saco oferece (%s)" % bag.get_prompt(player))
		bag.interact(player)
		await create_timer(0.3).timeout
	_check(bag.data["contents"].size() == 3 and player.held_item() == null, "dois maços e um montinho dentro")
	_check(ItemKinds.label(bag) == "trash bag (2 bundles, 6 loose bills)", "o nome conta o que tem (%s)" % ItemKinds.label(bag))
	var full: Vector3 = (bag.get_child(0).shape as BoxShape3D).size
	_check(full.y > flat.y * 10.0, "o saco estufou (%.2f m de altura)" % full.y)
	await create_timer(1.0).timeout
	_check(bag.global_position.y - full.y / 2.0 > -0.03, "e não afundou no chão (fundo em %.3f)" % (bag.global_position.y - full.y / 2.0))
	var n: Node = kitnet.neighbor
	_check("trashbag" not in n.EVIDENCE and items.items.values().filter(func(i): return i.kind == "bundle").is_empty(),
			"fechado parece lixo: o vizinho não vê os maços")
	await _look(player, spot + Vector3(0.0, 0.0, 0.8), bag.global_position, "67_saco_de_lixo")
	# Cheio não cabe mais.
	var saved: Array = bag.data["contents"]
	bag.data["contents"] = saved + saved + saved + [saved[0]]
	var extra: Node = items.spawn("bundle", Transform3D(Basis.IDENTITY, player.global_position + Vector3.UP), {"count": 20, "worth": 20.0})
	items._set_holder(extra.id, 1, extra.global_transform, Vector3.ZERO, Vector3.ZERO)
	await physics_frame
	_check(bag.get_prompt(player) == "The trash bag is full", "cheio (10), não cabe mais")
	items.consume(extra)
	bag.data["contents"] = saved
	await physics_frame
	# O clique tira o último (o montinho); [E] devolve; de mão vazia, [E] pega o saco.
	_check(bag.get_prompt(player).ends_with("Click: take out the 6 bills"), "de mão vazia: pegar o saco ou tirar o último")
	bag.click(player)
	await physics_frame
	_check(player.held_item() != null and player.held_item().kind == "bills" and bag.data["contents"].size() == 2,
			"o clique tirou o montinho")
	bag.interact(player)
	await physics_frame
	bag.interact(player)
	await create_timer(0.5).timeout
	_check(player.held_item() == bag, "carrega o saco com tudo dentro")
	# Aberto pela borda: o que cai na boca entra sozinho (um amigo segura, o outro joga).
	player.global_position = Vector3(3.3, 0.05, -1.2)
	player.rotation.y = 0.0
	player.head.rotation.x = -0.6
	items.request_bag_toggle()
	await create_timer(0.6).timeout
	_check(bag.data.get("open", false) and ItemKinds.label(bag).begins_with("open trash bag"), "o clique abre o saco")
	var mouth: Vector3 = ItemKinds.bag_mouth(bag)
	var inside_before: int = bag.data["contents"].size()
	var dropped_id: int = items.spawn("bundle", Transform3D(Basis.IDENTITY, mouth + Vector3(0.0, 0.4, 0.0)), {"count": 20, "worth": 20.0}).id
	await create_timer(0.8).timeout
	_check(not items.items.has(dropped_id) and bag.data["contents"].size() > inside_before,
			"o maço que caiu na boca entrou (%d)" % bag.data["contents"].size())
	mouth = ItemKinds.bag_mouth(bag)
	var from: Vector3 = mouth + Vector3(0.0, 0.3, -1.8)
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var thrown: Node = items.spawn("bundle", Transform3D(Basis.IDENTITY, from), {"count": 20, "worth": 20.0})
	var thrown_id: int = thrown.id
	thrown.linear_velocity = (mouth - from) / 0.5 + Vector3.UP * 0.25 * gravity
	await create_timer(1.0).timeout
	_check(not items.items.has(thrown_id), "o arremessado de 1,8 m também")
	if items.items.has(thrown_id):
		items.consume(items.items[thrown_id])
	# O dinheiro lá dentro tem física: um corpo por coisa, acomodados dentro da casca.
	await create_timer(0.8).timeout
	var inside: Node = bag.get_node("Inside")
	var inside_ok: bool = inside.count() == bag.data["contents"].size()
	var bag_size: Vector3 = ItemKinds.bag_size(bag.data)
	for body: RigidBody3D in inside.bodies():
		var p: Vector3 = bag.global_transform.affine_inverse() * body.global_position
		inside_ok = inside_ok and absf(p.y) < bag_size.y / 2.0 + 0.02 and Vector2(p.x, p.z).length() < bag_size.x / 2.0 + 0.02
	_check(inside_ok, "aberto, os maços caem lá dentro com física (%d corpos)" % inside.count())
	# Andando de lado de repente, o saco balança na mão.
	for f in 12:
		player.global_position += Vector3(0.05, 0.0, 0.0)
		await process_frame
	var swing: float = bag.bag_swing_angle()
	_check(swing > 0.1, "o saco balança na mão (%.2f rad)" % swing)
	player.global_position = Vector3(3.3, 0.05, -1.2)
	await create_timer(0.8).timeout
	mouth = ItemKinds.bag_mouth(bag)
	# O vizinho: aberto com dinheiro, vê; com o nó, não.
	var n_pos: Vector3 = n.global_position
	var n_rot: Vector3 = n.rotation
	n.global_position = Vector3(mouth.x, 0.0, mouth.z - 1.5)
	n.rotation = Vector3(0.0, PI, 0.0)
	await physics_frame
	_check(n._sees_evidence(), "o vizinho vê os maços pela boca do saco aberto")
	items.request_bag_toggle()
	await physics_frame
	_check(not bag.data.get("open", false) and not n._sees_evidence(), "com o nó, o saco volta a parecer lixo")
	n.global_position = n_pos
	n.rotation = n_rot
	# Devolve como estava (3 dentro).
	bag.data["contents"] = bag.data["contents"].slice(0, 3)
	ItemKinds.refresh(bag)
	# Cabe no esconderijo e volta igual.
	var stash: Node = kitnet.stashes.filter(func(s): return s.spot_name == "the wardrobe")[0]
	player.global_position = Vector3(1.2, 0.05, -1.8)
	stash._use(1)
	await physics_frame
	_check(stash.contents.size() == 1 and player.held_item() == null, "o saco cabe no guarda-roupa")
	stash._use(1)
	await physics_frame
	var back: Node = player.held_item()
	_check(back != null and back.kind == "trashbag" and back.data["contents"].size() == 3, "e volta com tudo dentro")
	if back != null:
		# Fechado e tombado no chão: nada sai.
		var floor_spot := Vector3(3.3, 0.3, -1.6)
		player.global_position = floor_spot + Vector3(0.0, -0.25, 0.9)
		items.request_drop(Transform3D(Basis.IDENTITY, floor_spot + Vector3.UP * 0.1), Vector3.ZERO)
		await create_timer(0.6).timeout
		back.global_transform = Transform3D(Basis(Vector3.RIGHT, 1.7), floor_spot)
		back.angular_velocity = Vector3.ZERO
		await create_timer(0.8).timeout
		_check(back.data["contents"].size() == 3, "fechado e tombado, nada sai")
		# Aberto e tombado: derrama tudo pela boca, de verdade (itens soltos).
		var loose_before: Array = items.items.keys().filter(func(k): return items.items[k].kind in ItemKinds.BAG_KINDS)
		items.set_data(back, "open", true)
		back.global_transform = Transform3D(Basis(Vector3.RIGHT, 1.7), floor_spot)
		back.angular_velocity = Vector3.ZERO
		await create_timer(1.5).timeout
		var spilled: Array = items.items.keys().filter(func(k): return items.items[k].kind in ItemKinds.BAG_KINDS and k not in loose_before)
		_check(back.data["contents"].is_empty() and spilled.size() == 3,
				"aberto e tombado, derrama tudo (%d no chão)" % spilled.size())
		await _look(player, floor_spot + Vector3(0.0, -0.25, 0.9), back.global_position, "68_saco_derramado")
		for k in spilled:
			items.consume(items.items[k])
		items.consume(back)
	await create_timer(0.5).timeout


func _test_raid(kitnet: Node3D, player: CharacterBody3D) -> void:
	var items: Node = kitnet.items
	var police: Node = kitnet.police
	var door: Node = kitnet.doors["301"]
	if player.held_item() != null:
		items.consume(player.held_item())
	_check(kitnet.hideouts.size() == 5, "5 esconderijos de gente (%d)" % kitnet.hideouts.size())
	_check(kitnet.nav_region != null and kitnet.nav_region.navigation_mesh.get_polygon_count() > 20,
			"a malha de navegação dos policiais")
	# Cada esconderijo: entra, [E] sai, e a saída fica livre (sem ficar preso em móvel nenhum).
	var space := player.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = (player.collision.shape as CapsuleShape3D).radius
	capsule.height = 1.6
	var all_ok := true
	for key in kitnet.hideouts:
		var spot: Node = kitnet.hideouts[key]
		player.global_position = spot.exit_point()
		await physics_frame
		spot._press(1)
		await create_timer(0.15).timeout
		var inside: bool = player.hiding_spot == spot
		spot.request_leave()
		await create_timer(0.15).timeout
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, spot.exit_point() + Vector3.UP * 0.9)
		query.collision_mask = 1
		var blocked := space.intersect_shape(query, 4)
		var ok: bool = inside and player.hiding_spot == null and not player.collision.disabled and blocked.is_empty()
		if not ok:
			print("  esconderijo ", key, ": dentro=", inside, " saiu=", player.hiding_spot == null, " preso em ", blocked.map(func(h): return h["collider"].get_parent().name))
		all_ok = all_ok and ok
	_check(all_ok, "entra e sai de cada esconderijo, e a saída fica livre")
	# A porta do banheiro aberta dá passagem (a folha aberta não come o vão).
	var bath_door: Node = kitnet.doors["Bath"]
	bath_door.set_open(true)
	await create_timer(0.7).timeout
	player.global_position = Vector3(4.4, 0.05, -1.25)
	await physics_frame
	var passed := false
	for i in 120:
		player.velocity = Vector3(1.5, 0.0, 0.0)
		player.move_and_slide()
		if player.global_position.x > 5.4:
			passed = true
			break
		await physics_frame
	_check(passed, "entra andando no banheiro pela porta aberta (%.2f)" % player.global_position.x)
	bath_door.set_open(false)
	var wardrobe: Node = kitnet.hideouts["wardrobe"]
	player.global_position = wardrobe.exit_point()
	await physics_frame
	_check(wardrobe.zone.get_prompt(player) == "[E] Hide in the wardrobe", "o guarda-roupa esconde gente")
	wardrobe._press(1)
	await create_timer(0.4).timeout
	_check(player.hiding_spot == wardrobe and player.collision.disabled and not player._body.visible,
			"dentro do guarda-roupa (o corpo some)")
	_check(player.camera.global_position.distance_to(wardrobe.eye_point(0)) < 0.05, "olhando pela fresta")
	await _shot("69_escondido_no_guarda_roupa")
	# 1. Revista sem achar nada: levam as notas da mesa; a geladeira e quem está escondido ficam.
	var bills_id: int = items.spawn("bills", Transform3D(Basis.IDENTITY, Vector3(3.0, 0.8, -1.9)), {"count": 6}).id
	var fridge: Node = kitnet.stashes.filter(func(s): return s.spot_name == "the fridge")[0]
	fridge.contents = [["bundle", {"count": 20, "worth": 20.0}],
			["trashbag", {"contents": [["bundle", {"count": 20, "worth": 20.0}]]}]]
	door.set_locked(true)
	var cash_before: int = kitnet.wallet.cash
	police.search_chance = 0.0
	police.call_cops()
	police.time_left = 0.1
	var ended := await _wait_raid(police, 120.0)
	var raid: Dictionary = police.last_raid
	_check(ended and not items.items.has(bills_id) and raid.get("bills", 0) >= 6,
			"os policiais entraram e levaram as notas da mesa (%s)" % raid)
	_check(door.is_open, "entraram pela 301 trancada")
	_check(player.arrest_stage == "" and player.hiding_spot == wardrobe, "escondido no guarda-roupa, ninguém achou")
	_check(fridge.contents.size() == 2, "sem revistar, a geladeira guardou o dinheiro")
	_check(kitnet.wallet.cash == cash_before - mini(police.FINE, cash_before), "multa ($%d)" % kitnet.wallet.cash)
	kitnet.wallet.earn(cash_before - kitnet.wallet.cash)
	# 2. Revistando tudo: acham no guarda-roupa, cacetada, algema e arrasto; a frigideira no
	# policial solta o preso.
	police.search_chance = 1.0
	police.call_cops()
	police.time_left = 0.1
	var cuffed := await _wait_until(func(): return player.arrest_stage == "cuffed", 90.0)
	_check(cuffed and player.hiding_spot == null, "achado no guarda-roupa: cacetada e algemado")
	await create_timer(1.2).timeout
	var draggers: Array = police.cops.filter(func(c): return c.dragging == 1)
	var cop: Node = draggers[0] if not draggers.is_empty() else null
	_check(cop != null and cop.state == cop.State.DRAG and police.cops.filter(func(c): return c.dragging == 1).size() == 1,
			"um policial arrasta o preso pela gola")
	if cop != null:
		cop.take_bonk(Vector3.FORWARD)
	var freed := await _wait_until(func(): return player.arrest_stage == "", 3.0)
	_check(freed and cop != null and cop.knocked_out(), "frigideira no policial: ele desmaia e a algema solta")
	# Parado no meio da sala: pegam de novo e levam até a escada.
	player.global_position = Vector3(2.2, 0.05, -2.6)
	var jailed := await _wait_until(func(): return player.arrest_stage == "jailed", 90.0)
	_check(jailed and not player._body.visible, "preso na escada até a batida acabar")
	await create_timer(0.4).timeout
	await _shot("70_preso")
	ended = await _wait_raid(police, 150.0)
	raid = police.last_raid
	_check(ended and player.arrest_stage == "" and player.global_position.distance_to(police.RELEASE) < 1.2,
			"a batida acabou e o preso voltou no corredor")
	_check(raid.get("arrests", 0) >= 1 and raid.get("bundles", 0) >= 1, "levaram o maço da geladeira e contaram o preso (%s)" % raid)
	_check(fridge.contents.size() == 1 and fridge.contents[0][0] == "trashbag", "o saco de lixo fechado passou por lixo")
	fridge.contents.clear()
	kitnet.wallet.earn(cash_before - kitnet.wallet.cash)
	police.search_chance = -1.0
	door.set_open(false)
	await create_timer(1.0).timeout


## Espera a batida acabar (os policiais foram embora).
func _wait_raid(police: Node, limit: float) -> bool:
	await create_timer(0.5).timeout
	return await _wait_until(func(): return not police.raiding and police.time_left < 0.0, limit)


func _wait_until(cond: Callable, limit: float) -> bool:
	var t := 0.0
	while not cond.call() and t < limit:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return cond.call()


func _wait_neighbor(n: Node, states: Array, limit: float) -> bool:
	var t := 0.0
	while n.state not in states and t < limit:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return n.state in states


## Clique de quem opera (desce a alavanca) e espera ela voltar.
func _cut_click(player: CharacterBody3D, swing: float) -> void:
	player._input(_left_click())
	await create_timer(swing).timeout


## Põe as mãos onde o golpe levaria exatamente `lost` (bits de player.DIGITS e HAND_LOST),
## procurando de milímetro em milímetro a partir da linha da lâmina.
func _place_for(g: Node3D, lost: int) -> bool:
	for mm in 200:
		g.place_hands(-mm * 0.001)
		if g._chopped(g.hands_z) == lost:
			return true
	return false


## Põe a folha passando `amount` m da lâmina e as mãos firmes logo atrás dela (sem tremor).
func _feed_to(g: Node3D, amount: float) -> void:
	g.slide_to(amount)
	g.place_hands(0.01)


func _right_button(pressed: bool) -> InputEventMouseButton:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_RIGHT
	button.pressed = pressed
	return button


func _left_click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


func _mouse_motion(relative: Vector2) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.relative = relative
	return motion


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

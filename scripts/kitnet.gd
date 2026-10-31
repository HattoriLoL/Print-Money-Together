extends Node3D
## A kitnet 301: carrega o modelo do Blender (assets/models/kitnet.glb, montado por
## art_source/blender/build.py), dá colisão, portas e luz, e cuida de quem está na sala.
## As convenções de nomes do modelo estão em docs/kitnet.md.
##
## Rede: o host é quem decide a lista de jogadores (roster). Quem entra avisa o host quando a
## cena terminou de carregar (_client_ready) e só então passa a receber os RPCs da cena; por
## isso tudo que vai para "todos" usa rpc_roster em vez de rpc().

signal roster_changed

const KITNET := preload("res://assets/models/kitnet.glb")
const PlayerScene := preload("res://scenes/player.tscn")
const Door := preload("res://scripts/door.gd")
const ItemManager := preload("res://scripts/items/item_manager.gd")
const Printer := preload("res://scripts/machines/printer.gd")
const PaperSupply := preload("res://scripts/machines/paper_supply.gd")
const Guillotine := preload("res://scripts/machines/guillotine.gd")
const Toon := preload("res://scripts/toon.gd")
const Ambience := preload("res://scripts/ambience.gd")

## Portas que os jogadores não abrem (vizinhos e a escada, por onde o fiscal vai chegar).
const LOCKED_DOORS := ["302", "303", "Stairs"]
## Malhas sem colisão: luminárias (e o fio da lâmpada pelada), panos, o varal (acima da cabeça), as pás do ventilador,
## as manchas e tudo lá fora.
const NO_COLLISION := ["LAMP_", "Cord_", "Curtain_", "MACHINE_ClothesLine", "MACHINE_Fan_Blades", "Decal_", "Newspaper_", "Outside_"]
## Malhas que não fazem sombra (as manchas ficam a 3 mm da parede; lá fora é só fundo).
const NO_SHADOW := ["LAMP_", "Decal_", "Outside_"]
## Luz de cada zona (LIGHT_<zona>_<n> do modelo): alcance (m), energia e sombra.
const ZONE_LIGHT := {
	"main": [7.0, 1.4, true],
	"kitchen": [2.5, 0.5, false],
	"bath": [3.5, 0.8, true],
	"service": [4.0, 0.8, true],
	"hall": [5.0, 0.45, true],
}

var model: Node3D
## Portas pelo nome depois de KEEP_Door_ ("301", "Bath").
var doors := {}
## Onde cada vaga nasce (SPAWN_1 a SPAWN_4 do modelo).
var spawns: Array[Transform3D] = []
## id do peer -> {"name": String, "slot": int}. Igual em todas as máquinas.
var roster := {}
## id do peer -> jogador.
var players := {}
## Objetos carregáveis (resmas, folhas...).
var items: Node
## Estações da produção.
var printer: Node3D
var paper_supply: Node3D
var guillotine: Node3D
## Animações do cenário (ventilador, lâmpada, TV, vapor, vento).
var ambience: Node

var _players_root: Node3D


func _ready() -> void:
	add_to_group("kitnet")
	# Tudo que entra na cena (mapa, itens, luvas, jogadores) ganha o visual de desenho.
	get_tree().node_added.connect(_on_node_added)
	_build_environment()
	items = ItemManager.new()
	items.name = "Items"
	add_child(items)
	model = KITNET.instantiate()
	model.name = "Model"
	add_child(model)
	_setup_model()
	_players_root = Node3D.new()
	_players_root.name = "Players"
	add_child(_players_root)

	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_register(1, Net.player_name)
	else:
		_client_ready.rpc_id(1, Net.player_name)


## O jogador desta máquina (ou null antes de nascer).
func local_player() -> CharacterBody3D:
	return players.get(multiplayer.get_unique_id())


## Chama `method` em `node` em todas as outras máquinas que já estão na sala.
func rpc_roster(node: Node, method: StringName, args: Array = []) -> void:
	var me := multiplayer.get_unique_id()
	for id: int in roster:
		if id != me:
			node.callv(&"rpc_id", [id, method] + args)


# --- Sala ---------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _client_ready(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	for other: int in roster:
		_add_player.rpc_id(id, other, roster[other]["name"], roster[other]["slot"])
	for key in doors:
		if doors[key].is_open:
			doors[key].send_state_to(id)
	items.send_all_to(id)
	for station in get_tree().get_nodes_in_group("station"):
		station.send_state_to(id)
	for other: int in roster:
		players[other].send_injury_to(id)
	_register(id, player_name)


func _register(id: int, player_name: String) -> void:
	var slot := _free_slot()
	var clean := player_name.strip_edges().left(16)
	if clean.is_empty():
		clean = "Player %d" % (slot + 1)
	_add_player(id, clean, slot)
	rpc_roster(self, &"_add_player", [id, clean, slot])


func _free_slot() -> int:
	var used := roster.values().map(func(e): return e["slot"])
	for i in Net.MAX_PLAYERS:
		if i not in used:
			return i
	return 0


@rpc("authority", "call_remote", "reliable")
func _add_player(id: int, player_name: String, slot: int) -> void:
	if players.has(id):
		return
	roster[id] = {"name": player_name, "slot": slot}
	var player: CharacterBody3D = PlayerScene.instantiate()
	player.setup(id, player_name, slot, spawns[slot])
	_players_root.add_child(player)
	players[id] = player
	roster_changed.emit()
	var me := local_player()
	if me != null and id != multiplayer.get_unique_id():
		me.hud.show_message("%s joined" % player_name, 2.0)


func _on_peer_disconnected(id: int) -> void:
	if not roster.has(id):
		return
	items.drop_all_of(id)
	for zone in get_tree().get_nodes_in_group("interact_zone"):
		zone.drop_peer(id)
	for station in get_tree().get_nodes_in_group("station"):
		if station.has_method("drop_peer"):
			station.drop_peer(id)
	_remove_player(id)
	rpc_roster(self, &"_remove_player", [id])


@rpc("authority", "call_remote", "reliable")
func _remove_player(id: int) -> void:
	var player_name: String = roster.get(id, {}).get("name", "")
	roster.erase(id)
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
	roster_changed.emit()
	var me := local_player()
	if me != null:
		me.hud.show_message("%s left" % player_name, 2.0)


# --- Modelo -------------------------------------------------------------------

func _setup_model() -> void:
	for light: Light3D in model.find_children("LIGHT_*", "Light3D", true, false):
		_setup_light(light)
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	for mesh: MeshInstance3D in meshes:
		var mesh_name := String(mesh.name)
		if NO_SHADOW.any(func(p: String): return mesh_name.begins_with(p)):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_name.begins_with("KEEP_Door_"):
			_add_door(mesh)
		elif not NO_COLLISION.any(func(p: String): return mesh_name.begins_with(p)):
			_add_collision(mesh)
	for i in Net.MAX_PLAYERS:
		var marker: Node3D = model.find_child("SPAWN_%d" % (i + 1), true, false)
		spawns.append(Transform3D(Basis.IDENTITY, marker.global_position + Vector3.UP * 0.05))
	_add_stations()
	ambience = Ambience.new()
	add_child(ambience)
	ambience.setup(model, self)


func _on_node_added(node: Node) -> void:
	if node is GeometryInstance3D:
		# Depois do quadro: quem criou a malha ainda pode estar trocando os materiais dela.
		_toon_later.call_deferred(node)


func _toon_later(node: GeometryInstance3D) -> void:
	if is_instance_valid(node):
		Toon.apply_one(node)


## As máquinas viram filhas das malhas delas (o referencial é o do modelo).
func _add_stations() -> void:
	printer = Printer.new()
	model.find_child("MACHINE_Printer", true, false).add_child(printer)
	paper_supply = PaperSupply.new()
	model.find_child("SUPPLY_Paper", true, false).add_child(paper_supply)
	guillotine = Guillotine.new()
	model.find_child("MACHINE_Guillotine", true, false).add_child(guillotine)


func _setup_light(light: Light3D) -> void:
	var zone := String(light.name).get_slice("_", 1)
	var cfg: Array = ZONE_LIGHT.get(zone, [4.0, 0.8, false])
	if light is OmniLight3D:
		light.omni_range = cfg[0]
	light.light_energy = cfg[1]
	light.shadow_enabled = cfg[2]


func _add_door(leaf: MeshInstance3D) -> void:
	var door := Door.new()
	door.adopt(leaf)
	door.locked = door.key in LOCKED_DOORS
	doors[door.key] = door


func _add_collision(mesh: MeshInstance3D) -> void:
	# Os pisos são lajes retas: uma caixa sólida segura melhor o que fica parado em cima do que
	# uma malha de triângulos (por ela, uma resma às vezes afundava devagar e caía do mapa).
	var shape: Shape3D
	var center := Vector3.ZERO
	if String(mesh.name).begins_with("Floor_"):
		var aabb := mesh.mesh.get_aabb()
		var box := BoxShape3D.new()
		box.size = aabb.size
		shape = box
		center = aabb.get_center()
	else:
		shape = mesh.mesh.create_trimesh_shape()
	if shape == null:
		return
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = center
	body.add_child(col)
	mesh.add_child(body)


func _build_environment() -> void:
	var env := Environment.new()
	# Céu de cidade à noite: azul-escuro em cima, alaranjado no horizonte (luz de sódio).
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.01, 0.015, 0.035)
	sky_mat.sky_horizon_color = Color(0.13, 0.08, 0.06)
	sky_mat.ground_horizon_color = Color(0.06, 0.04, 0.035)
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.01)
	sky_mat.sun_angle_max = 0.0
	sky_mat.energy_multiplier = 1.0
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Visual de desenho: a sombra é um tom arroxeado chapado, não um breu (ver scripts/toon.gd).
	env.ambient_light_color = Color(0.55, 0.5, 0.75)
	env.ambient_light_energy = 0.3
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	# Só um pouco de sombra de contato nos cantos; a luz rebatida suave e a neblina saíram (o
	# desenho tem tons duros).
	env.ssao_enabled = true
	env.ssao_intensity = 0.8
	env.glow_enabled = true
	env.glow_bloom = 0.06
	env.glow_intensity = 0.7
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.2
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


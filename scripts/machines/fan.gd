extends Node3D
## Ventilador de coluna do serviço, virado para o varal (filho do MACHINE_Fan do kitnet.glb).
##
##   [E] liga ou desliga.
##
## Ligado, as pás giram (o ambience.gd lê `spin`), as folhas do varal tremulam e secam
## clothesline.gd FAN_FACTOR vezes mais rápido. Faz um barulho baixo (`noise`). Começa desligado.
## O host manda e repassa.

const InteractZone := preload("res://scripts/interact_zone.gd")

## Quanto tempo as pás levam para chegar na velocidade (ou parar), s.
const SPIN_TIME := 1.2
const NOISE := 0.12

var powered := false
## De 0 (parado) a 1 (na velocidade): sobe e desce devagar quando liga e desliga.
var spin := 0.0
var zone: Area3D
var _kitnet: Node


func _ready() -> void:
	name = "Fan"
	add_to_group("station")
	add_to_group("noise_source")
	_kitnet = get_tree().get_first_node_in_group("kitnet")
	zone = InteractZone.new()
	zone.setup(self, "Zone_Fan", Vector3(0.0, 1.15, 0.0), Vector3(0.6, 0.65, 0.35))
	zone.prompt_fn = _prompt
	zone.press_fn = _toggle


func _process(delta: float) -> void:
	spin = move_toward(spin, 1.0 if powered else 0.0, delta / SPIN_TIME)


func noise() -> float:
	return NOISE if powered else 0.0


func _prompt(_player: Node) -> String:
	return "[E] Turn the fan off" if powered else "[E] Turn the fan on (dries the sheets faster)"


func _toggle(_peer: int) -> void:
	_set_powered(not powered)
	_kitnet.rpc_roster(self, &"_set_powered", [powered])


func send_state_to(peer: int) -> void:
	_set_powered.rpc_id(peer, powered)


@rpc("authority", "call_remote", "reliable")
func _set_powered(on: bool) -> void:
	powered = on

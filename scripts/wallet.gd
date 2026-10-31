extends Node
## O dinheiro do grupo (limpo, de verdade): um caixa só para todos (nó "Wallet" do mapa). O host
## manda e repassa; o HUD de cada um mostra.
##
## Começa com as economias (START_CASH). Por enquanto só sai, nas compras do PC; vender as notas
## falsas vem depois.

signal changed(cash: int)

const START_CASH := 150

var cash := START_CASH
var _kitnet: Node


func _ready() -> void:
	name = "Wallet"
	add_to_group("station")
	_kitnet = get_parent()


## Host: paga `amount`, se tiver. Devolve se pagou.
func spend(amount: int) -> bool:
	if amount < 0 or amount > cash:
		return false
	_set_cash(cash - amount)
	_kitnet.rpc_roster(self, &"_set_cash", [cash])
	return true


## Host: entra dinheiro.
func earn(amount: int) -> void:
	_set_cash(cash + maxi(amount, 0))
	_kitnet.rpc_roster(self, &"_set_cash", [cash])


func send_state_to(peer: int) -> void:
	_set_cash.rpc_id(peer, cash)


@rpc("authority", "call_remote", "reliable")
func _set_cash(value: int) -> void:
	cash = value
	changed.emit(cash)

extends RefCounted
## Cenários para testar jogando: o mapa já começa numa situação (`--scenario=<nome>` na linha de
## comando; o tools/play.ps1 passa). Só o host monta, depois que o mapa carregou.
##
##   fuga   o dinheiro todo à vista (notas e maços na mesa, folhas no chão) e o vizinho saindo do
##          303 para bater na porta. A 301 fica destrancada: ele entra, vê tudo e foge pela escada
##          ligando para a polícia. É para correr atrás dele (docs/vizinho.md).

## Segundos depois de carregar até o vizinho sair de casa.
const NEIGHBOR_DELAY := 2.0

## Onde cada coisa aparece (Godot): na mesa do meio, perto da entrada, e no chão do caminho dele.
const FUGA_ITEMS := [
	["bills", Vector3(3.6, 0.85, -1.9), {"count": 6}],
	["bills", Vector3(3.3, 0.85, -2.05), {"count": 10}],
	["bundle", Vector3(3.0, 0.85, -1.85), {"count": 20, "worth": 20.0}],
	["bundle", Vector3(3.15, 0.9, -1.75), {"count": 20, "worth": 20.0}],
	["sheet", Vector3(3.9, 0.1, -1.4), {}],
	["sheet", Vector3(3.5, 0.1, -1.2), {}],
]


## O cenário pedido na linha de comando ("" = nenhum).
static func requested() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			return arg.get_slice("=", 1)
	return ""


## Host: monta o cenário no mapa recém-carregado.
static func start(kitnet: Node, scenario: String) -> void:
	match scenario:
		"fuga":
			await _fuga(kitnet)
		_:
			push_warning("Cenário desconhecido: %s (os que existem: fuga)" % scenario)


static func _fuga(kitnet: Node) -> void:
	for entry: Array in FUGA_ITEMS:
		var xform := Transform3D(Basis(Vector3.UP, randf() * TAU), entry[1])
		kitnet.items.spawn(entry[0], xform, entry[2].duplicate())
	var door: Node = kitnet.doors["301"]
	door.set_locked(false)
	door.set_open(false)
	await kitnet.get_tree().create_timer(NEIGHBOR_DELAY).timeout
	kitnet.neighbor.visit()

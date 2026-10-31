extends Node3D
## Guilhotina de mesa (filha do MACHINE_Guillotine do kitnet.glb; o referencial é o do modelo, com
## a frente, onde fica a lâmina, para +Z). Os números vêm de um GuillotineStats
## (data/machines/guillotine_*.tres).
##
##   [E] com uma folha impressa na mão: põe a folha na mesa, com a borda da frente na lâmina, e
##       começa a operar.
##   [E] de mão vazia com uma folha na mesa: começa a operar. Sem folha, só bate a alavanca.
##
## Operando, a câmera de quem opera vai para cima da mesa e as luvas do boneco seguram a folha.
## O mouse desliza a folha para a frente e para trás (passando da lâmina no máximo uma peça; com
## Shift, devagar) e o clique desce a alavanca: quando a lâmina chega embaixo, corta o que passou
## dela (uma linha-guia vermelha, como o laser das guilhotinas de verdade, mostra onde), com o som
## do golpe e um tranco na câmera. Do clique até a alavanca voltar, a folha fica parada. Outro
## jogador pode puxar a alavanca pelo pegador vermelho ([E]): o corte vai onde quem opera está
## segurando a folha.
##
## A folha é cortada como numa gráfica, em duas fases:
##   Linhas: os cortes horizontais soltam tiras (uma linha de notas, ainda grudadas lado a lado),
##     que vão para uma pilha do lado da lâmina. O corte que deixa só a última linha na mesa solta
##     também ela (atrás dela só tem a margem).
##   Colunas: a pilha gira 90° e vai para a lâmina, e um corte vertical separa as colunas de todas
##     as tiras de uma vez (a última coluna sai junto do mesmo jeito). Só aí as notas vão para o
##     montinho. Uma folha de 2 x 3 notas pede 3 cortes.
##
## O corte certo é no meio do vão entre duas peças (as marcas na margem da folha mostram onde).
## Cada peça que sai numa tira tem o erro das duas pontas dela: sobra de papel além do meio do vão,
## ou nota comida pelo corte (as margens da folha não contam). Uma peça com mais que ruin_error
## estraga. Cortar fundo numa peça também estraga ela, e o resto dela fica grudado na frente da
## próxima até alguém aparar no vão. Cada nota vale pelo erro das quatro bordas, o da linha mais o
## da coluna: até perfect_error sai perfeita; até ruin_error, torta (vale menos, e a de cima do
## montinho mostra o corte torto); passando disso, estraga. [E] sai (a folha e a pilha ficam na
## mesa); acabou a folha, sai sozinho.
##
## Rede: o host manda no estado (fase, onde já foi cortado, a pilha, quem opera) e repassa para
## todos. Quem opera manda a posição da folha para os outros, e o corte vai com ela para o host.

const InteractZone := preload("res://scripts/interact_zone.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const Toon := preload("res://scripts/toon.gd")
const DEFAULT_STATS := preload("res://data/machines/guillotine_manual.tres")
const SHEET_FRONT := preload("res://assets/textures/sheet_front.png")

enum Phase { ROWS, COLUMNS }
## Para onde vai uma tira cortada.
enum Dest { SCRAP, STACK, PILE }

## Medidas do modelo (art_source/blender/machines.py, convertidas para o Godot: y do Blender = -z).
const CUT_Z := 0.1                       # linha da lâmina
const TOP_Y := 0.0315                    # tampo, logo acima do quadriculado
## Altura da folha posta: por cima da contra-lâmina de aço (vai até 0,0335), senão o aço tapa o vão
## entre as notas bem na linha de corte.
const SHEET_Y := 0.034
const SHEET_X := -0.0835                 # centro da folha (encostada no esquadro da esquerda)
const SHEET_SIZE := Vector2(0.297, 0.21)
## A pilha de tiras: na parte livre do tapete, à direita da folha, já girada (o comprido dela vai
## para a lâmina), esperando STACK_GAP atrás da lâmina para não ser cortada junto com as linhas.
const STACK_X := 0.17
const STACK_GAP := 0.03
const OPEN_ANGLE := deg_to_rad(50.0)     # alavanca levantada (gira no Z do Godot)
## Alavanca levantada com alguém operando: quase em pé, para não tapar a folha de quem olha de cima.
const OPERATE_ANGLE := deg_to_rad(82.0)
## Onde nasce o montinho de notas: na mesa, logo na frente da guilhotina.
const PILE_POS := Vector3(-0.0835, 0.0, 0.26)
const PILE_STEP := Vector3(0.16, 0.0, 0.0)
## Desenho da folha (art_source/paper_textures.py): tamanho em pixels, margem e vão entre as notas.
## A borda de baixo da imagem é a da frente da folha (a que vai para a lâmina); a da esquerda é a
## frente da pilha girada.
const SHEET_PX := Vector2(2000.0, 1414.0)
const SHEET_MARGIN_PX := 54.0
const SHEET_GUTTER_PX := 20.0

## Operando: a folha passa da lâmina no máximo uma peça com a margem e mais esta folga (m), para
## não dar para passar duas de uma vez (feed_max). Quanto ela anda por pixel de mouse (com Shift,
## FEED_FINE disso, para o ajuste fino), onde o boneco fica em pé (no chão, na frente da mesa) e a
## câmera em cima da mesa (de onde e para onde olha, e o campo de visão: quase de cima, para a
## alavanca e os braços não taparem a linha; o x acompanha o que está na lâmina).
const FEED_SLACK := 0.015
const FEED_PER_PIXEL := 0.00012
const FEED_FINE := 0.25
const STAND := Vector3(SHEET_X, 0.0, 0.62)
const VIEW_FROM := Vector3(SHEET_X, 0.5, CUT_Z + 0.12)
const VIEW_AT := Vector3(SHEET_X, TOP_Y, CUT_Z - 0.08)
const VIEW_FOV := 55.0
## Quantas vezes por segundo quem opera manda a posição da folha.
const FEED_RATE := 30.0
## Pegador vermelho da alavanca, no referencial dela (o braço vai pelo +X a partir do pivô):
## a zona onde outro jogador aperta [E] para puxar.
const LEVER_GRIP := Vector3(0.585, 0.01, 0.0)
const LEVER_GRIP_SIZE := Vector3(0.2, 0.08, 0.08)
## Tranco da câmera no golpe: de quem opera e de quem está perto (até CHOP_KICK_REACH m).
const CHOP_KICK := 0.5
const CHOP_KICK_REACH := 1.5
## A tira cortada: quanto tempo leva até a pilha ou o montinho, quanto a segunda (a última peça,
## que saiu junto) espera para ir atrás, e o retalho estragado até parar na mesa, quanto tempo ele
## fica lá e quanto leva para sumir. A pilha leva PILE_SLIDE para chegar na lâmina.
const STRIP_TO_PILE := 0.22
const STRIP_NEXT := 0.1
const SCRAP_SLIDE := 0.25
const SCRAP_STAY := 0.5
const SCRAP_FADE := 0.2
const PILE_SLIDE := 0.25

var stats: Resource = DEFAULT_STATS
## Peças (linhas ou colunas, conforme a fase) que ainda faltam cortar (0 = guilhotina vazia).
var pieces_left := 0
var phase := Phase.ROWS
var sheet_wet := false
## Quanto já foi cortado na fase de agora, medido da frente (m): a frente do que sobrou.
var cut_pos := 0.0
## Quanto a frente do que sobrou passou da lâmina (m). Quem opera mexe; os outros seguem.
var feed := 0.0
## Peer operando (0 = ninguém).
var operator := 0
## Tiras na pilha e qual pedaço da folha é a de cima (m da frente: [frente, trás]).
var stack_count := 0
var top_strip := Vector2.ZERO
var zone: Area3D
## Zona do pegador da alavanca (filha dela, gira junto).
var lever_zone: Area3D

var _kitnet: Node
var _arm: Node3D
var _sheet: MeshInstance3D
var _stack: MeshInstance3D
## A pilha como ela aparece: só muda quando a tira que chega nela pousa (`_landing` = quantas
## ainda estão no ar).
var _shown_count := 0
var _shown_top := Vector2.ZERO
var _landing := 0
## Quanto a pilha ainda está atrás da lâmina (m, negativo) enquanto anda até ela.
var _stack_shift := 0.0
var _view_x := SHEET_X
## As tiras que acabaram de ser cortadas, indo para a pilha, o montinho ou a mesa (retalho), e o
## tween de cada uma.
var _strips: Array[MeshInstance3D] = []
var _strip_tweens: Array[Tween] = []
var _guide: MeshInstance3D
var _chop_player: AudioStreamPlayer3D
var _busy := false
var _pile_id := 0
var _noise_until := 0.0
## O único tween que mexe na alavanca (o golpe ou a ida para onde ela fica parada).
var _tween: Tween
## A alavanca está no golpe (descendo ou voltando).
var _arm_swinging := false
## Até quando (s, Time.get_ticks_msec) a folha fica parada: do clique até a alavanca voltar.
var _locked_until := 0.0
var _feed_target := 0.0
var _feed_timer := 0.0
var _feed_dirty := false
## O boneco que está com `operating` apontando para esta guilhotina.
var _operating_player: Node = null
## Só no host: as linhas das tiras da pilha, cada uma com o erro dela (m) e o pedaço da folha que
## aparece na nota ("shown", m da frente, sem a margem).
var _rows: Array[Dictionary] = []


func _ready() -> void:
	name = "Guillotine"
	add_to_group("station")
	add_to_group("noise_source")
	_kitnet = get_tree().get_first_node_in_group("kitnet")
	_arm = get_parent().find_child("MACHINE_Guillotine_Arm", false, false)
	zone = InteractZone.new()
	zone.setup(self, "Zone_Cut", Vector3(0, 0.06, 0), Vector3(0.52, 0.1, 0.42))
	zone.prompt_fn = _prompt
	zone.press_fn = _press
	if _arm:
		_arm.rotation = Vector3(0, 0, OPEN_ANGLE)
		lever_zone = InteractZone.new()
		lever_zone.setup(_arm, "Zone_Lever", LEVER_GRIP, LEVER_GRIP_SIZE)
		lever_zone.prompt_fn = _lever_prompt
		lever_zone.press_fn = _press_lever
	_sheet = _paper_mesh("Sheet")
	_stack = _paper_mesh("StripStack")
	for i in 2:
		# Duas porque o corte que separa a última peça solta também ela.
		_strips.append(_paper_mesh("CutStrip%d" % i))
		_strip_tweens.append(null)
	_build_guide()
	_build_chop_sound()
	_update_paper()
	if multiplayer.is_server():
		_kitnet.items.picked.connect(_on_item_picked)


func _process(delta: float) -> void:
	if not _is_mine():
		feed = lerpf(feed, _feed_target, clampf(20.0 * delta, 0.0, 1.0))
	elif _feed_dirty:
		_feed_timer -= delta
		if _feed_timer <= 0.0:
			_feed_timer = 1.0 / FEED_RATE
			_feed_dirty = false
			_kitnet.rpc_roster(self, &"_remote_feed", [feed])
	_view_x = lerpf(_view_x, _work_x(), clampf(6.0 * delta, 0.0, 1.0))
	_update_paper()


## Barulho agora: o golpe da lâmina, por um instante.
func noise() -> float:
	return stats.noise if Time.get_ticks_msec() / 1000.0 < _noise_until else 0.0


func has_sheet() -> bool:
	return pieces_left > 0


## Onde fica a borda de cada linha de notas, medida da frente da folha (m): [frente, trás].
func row_edges(row: int) -> Vector2:
	return _edges(row, stats.rows_per_sheet, SHEET_PX.y, SHEET_SIZE.y)


## Onde fica a borda de cada coluna de notas, medida da borda esquerda da folha (a frente da pilha
## girada) (m): [frente, trás].
func column_edges(column: int) -> Vector2:
	return _edges(column, stats.bills_per_row, SHEET_PX.x, SHEET_SIZE.x)


## As bordas da peça `i` na fase de agora (linha ou coluna).
func piece_edges(i: int) -> Vector2:
	return row_edges(i) if phase == Phase.ROWS else column_edges(i)


## Notas enfileiradas num lado da folha (`size_px` pixels, `size_m` metros): a borda da peça
## `index` de `count`, com a margem e os vãos do desenho.
func _edges(index: int, count: int, size_px: float, size_m: float) -> Vector2:
	var bill := (size_px - 2.0 * SHEET_MARGIN_PX - (count - 1) * SHEET_GUTTER_PX) / count
	var front := SHEET_MARGIN_PX + index * (bill + SHEET_GUTTER_PX)
	return Vector2(front, front + bill) * size_m / size_px


## O corte certo da próxima peça: no meio do vão logo atrás dela (m, da frente).
func ideal_cut() -> float:
	for i in _count():
		var edges := piece_edges(i)
		if edges.y > cut_pos + 0.001:
			return edges.y + _gutter() / 2.0
	return _length()


## Quanto a folha (ou a pilha) pode passar da lâmina (m): a primeira peça com a margem e o vão,
## mais a folga. Duas de uma vez não passam.
func feed_max() -> float:
	return piece_edges(0).y + _gutter() + FEED_SLACK


## Quantas peças a fase de agora tem, o comprimento da folha nessa direção e o vão entre as peças.
func _count() -> int:
	return stats.rows_per_sheet if phase == Phase.ROWS else stats.bills_per_row


func _length() -> float:
	return SHEET_SIZE.y if phase == Phase.ROWS else SHEET_SIZE.x


func _gutter() -> float:
	return SHEET_GUTTER_PX * SHEET_SIZE.y / SHEET_PX.y if phase == Phase.ROWS \
			else SHEET_GUTTER_PX * SHEET_SIZE.x / SHEET_PX.x


## Se a peça já saiu com a frente do que sobrou em `pos` (m): saiu numa tira (ficou para trás no
## máximo ruin_error dela) ou estragou (o corte entrou mais que isso nela). Os cortes só andam para
## trás, então isso basta, sem guardar nada por peça.
func _out(i: int, pos: float) -> bool:
	var edges := piece_edges(i)
	return edges.y - pos <= stats.ruin_error or pos - edges.x > stats.ruin_error


# --- Host -------------------------------------------------------------------------------------

func _press(peer: int) -> void:
	if _busy or (operator != 0 and operator != peer):
		return
	var held: Node = _kitnet.items.held_by(peer)
	if held != null:
		if held.kind == "sheet" and not has_sheet():
			sheet_wet = held.data.get("wet", false)
			phase = Phase.ROWS
			pieces_left = stats.rows_per_sheet
			cut_pos = 0.0
			feed = 0.0
			_rows.clear()
			_kitnet.items.consume(held)
			operator = peer
			_send_state()
		return
	if has_sheet():
		operator = peer
		feed = 0.0
		_send_state()
		return
	# Mão vazia e sem folha: a alavanca desce à toa.
	_start_swing()


## Host: a alavanca desce em todas as máquinas, com a folha parada passando `at` m da lâmina.
func _start_swing(at := 0.0) -> void:
	_busy = true
	_kitnet.rpc_roster(self, &"_swing", [at])
	_swing(at)
	get_tree().create_timer(stats.swing_down + stats.swing_up).timeout.connect(func(): _busy = false)


## Host: o clique de quem opera (`at` = quanto a folha passou da lâmina, m).
func _cut(peer: int, at: float) -> void:
	if _busy or peer != operator or not has_sheet():
		return
	_pull(at, [peer])


## Host: [E] no pegador da alavanca. Com alguém operando, quem puxa é outro jogador, e o corte vai
## onde quem opera está segurando a folha; sem ninguém operando, a alavanca desce à toa.
func _press_lever(peer: int) -> void:
	if _busy:
		return
	if operator == 0:
		_start_swing()
	elif peer != operator and has_sheet():
		_pull(_operator_feed(), [operator, peer])


## Onde o host vê a folha de quem opera: a dele mesmo, ou a última posição que chegou.
func _operator_feed() -> float:
	return feed if _is_mine() else _feed_target


## Host: a alavanca desce, e o corte acontece quando a lâmina chega embaixo (se quem opera não
## saiu antes). `tell` = quem fica sabendo como saiu.
func _pull(at: float, tell: Array) -> void:
	at = clampf(at, 0.0, feed_max())
	_start_swing(at)
	if at < 0.001:
		return
	var op := operator
	get_tree().create_timer(stats.swing_down).timeout.connect(func():
		if operator == op and has_sheet():
			_resolve_cut(at, tell))


## Host: a lâmina chegou embaixo. Sai a tira que passou dela, da frente do que sobrou (`cut_pos`)
## até o corte. Se sobrou só a última peça (no máximo um resto pequeno de outra na frente dela),
## ela já está solta e sai junto, numa segunda tira; com um resto maior, ela espera alguém aparar
## no vão. Nas linhas, as tiras vão para a pilha; nas colunas, viram as notas do montinho.
func _resolve_cut(at: float, tell: Array) -> void:
	var op := operator
	var cut := minf(cut_pos + at, _length())
	var spans: Array[Vector2] = [Vector2(cut_pos, cut)]
	var last := _count() - 1
	var only_last := not _out(last, cut) and range(last).all(func(i): return _out(i, cut))
	if only_last and piece_edges(last).x - cut - _gutter() / 2.0 <= stats.ruin_error:
		spans.append(Vector2(cut, _length()))
	var released: Array[Dictionary] = []
	var ruined := 0
	var dests: Array[int] = []
	var bills := {"bills": 0, "crooked": 0, "worth": 0.0, "top_cut": Rect2(), "ruined": 0}
	var new_top := top_strip
	for span in spans:
		var out := _released(span.x, span.y)
		var pieces: Array[Dictionary] = out["pieces"]
		released.append_array(pieces)
		ruined += out["ruined"]
		if phase == Phase.ROWS:
			dests.append(Dest.STACK if not pieces.is_empty() else Dest.SCRAP)
			if not pieces.is_empty():
				new_top = span
		else:
			var from_span := _stack_bills(pieces)
			_add_bills(bills, from_span)
			dests.append(Dest.PILE if from_span["bills"] > 0 else Dest.SCRAP)
	var text: String
	if phase == Phase.ROWS:
		_rows.append_array(released)
		text = _rows_text(released, ruined)
	else:
		# Uma coluna estragada perde a nota dela em cada tira da pilha.
		bills["ruined"] += ruined * _rows.size()
		text = _bills_text(bills)
	var pile_at := Vector3.ZERO
	if bills["bills"] > 0:
		pile_at = to_local(_add_to_pile(bills["bills"], bills["crooked"], bills["worth"], bills["top_cut"]))
	# As tiras saem (com o estado de antes do corte, para saber de onde) e depois a folha anda.
	for i in spans.size():
		var args := [i, spans[i].x, spans[i].y, dests[i], pile_at]
		_kitnet.rpc_roster(self, &"_strip_fell", args)
		_strip_fell.callv(args)
	cut_pos = spans.back().y
	feed = 0.0
	top_strip = new_top
	stack_count = _rows.size()
	pieces_left = range(_count()).filter(func(i): return not _out(i, cut_pos)).size()
	if pieces_left == 0:
		var direct := _next_phase()
		if direct["bills"] > 0 or direct["ruined"] > 0:
			text = _bills_text(direct)
	_send_result(tell, text)
	_send_state()
	if not has_sheet():
		# Acabou a folha: quem opera sai quando a alavanca volta.
		get_tree().create_timer(stats.swing_up).timeout.connect(func():
			if not has_sheet() and operator == op:
				operator = 0
				_send_state())


## Host: acabaram as peças da fase. Das linhas, a pilha de tiras gira e vai para a lâmina (com uma
## coluna só não tem o que separar: as tiras já são as notas). Das colunas, acabou a folha.
## Devolve as notas que saíram direto (só com uma coluna).
func _next_phase() -> Dictionary:
	var bills := {"bills": 0, "crooked": 0, "worth": 0.0, "top_cut": Rect2(), "ruined": 0}
	cut_pos = 0.0
	if phase == Phase.ROWS and not _rows.is_empty():
		if stats.bills_per_row > 1:
			phase = Phase.COLUMNS
			pieces_left = stats.bills_per_row
			return bills
		bills = _stack_bills([{"error": 0.0, "shown": Vector2(0.0, SHEET_SIZE.x)}])
		if bills["bills"] > 0:
			_add_to_pile(bills["bills"], bills["crooked"], bills["worth"], bills["top_cut"])
	phase = Phase.ROWS
	pieces_left = 0
	_rows.clear()
	stack_count = 0
	return bills


## Host: as peças (linhas ou colunas, conforme a fase) que saem numa tira de `front` a `back` (m,
## da frente). Cada uma vale pelo erro das duas pontas da tira: sobra de papel além do meio do vão,
## ou nota comida pelo corte. As margens da folha não contam (a frente da primeira peça e a trás da
## última podem sobrar). A partir da segunda peça de uma tira, a frente dela é a frente da tira:
## veio grudada na de antes. Devolve "pieces" (as que saíram inteiras, com "error" e "shown", o
## pedaço que aparece na nota, sem a margem) e "ruined" (quantas estragaram).
func _released(front: float, back: float) -> Dictionary:
	var pieces: Array[Dictionary] = []
	var ruined := 0
	var last := _count() - 1
	var half_gutter := _gutter() / 2.0
	for i in _count():
		# Só as peças que saem nesta tira.
		if _out(i, front) or not _out(i, back):
			continue
		var edges := piece_edges(i)
		var left_behind := maxf(0.0, edges.y - back)
		if left_behind > stats.ruin_error:
			# O corte entrou fundo nela: estragou, e o resto dela fica grudado na frente da próxima.
			# (Uma lasca da frente, até ruin_error, não tira a peça: vira erro de quando ela sair.)
			ruined += 1
			continue
		var error := maxf(0.0, front - edges.x) + left_behind
		if i > 0:
			error += maxf(0.0, edges.x - front - half_gutter)
		if i < last:
			error += maxf(0.0, back - edges.y - half_gutter)
		if error > stats.ruin_error:
			ruined += 1
			continue
		var shown := Vector2(front if i > 0 else maxf(front, edges.x - half_gutter),
				back if i < last else minf(back, edges.y + half_gutter))
		pieces.append({"error": error, "shown": shown})
	return {"pieces": pieces, "ruined": ruined}


## Host: as notas das colunas `columns` em todas as tiras da pilha. Cada nota vale pelo erro das
## quatro bordas: o da linha dela mais o da coluna.
func _stack_bills(columns: Array) -> Dictionary:
	var out := {"bills": 0, "crooked": 0, "worth": 0.0, "top_cut": Rect2(), "ruined": 0}
	for column: Dictionary in columns:
		for row in _rows:
			var error: float = row["error"] + column["error"]
			if error > stats.ruin_error:
				out["ruined"] += 1
				continue
			out["bills"] += 1
			var bill_worth := 1.0
			# A nota de cima do montinho é a última: reta, ou o pedaço da folha que ela é de verdade.
			out["top_cut"] = Rect2()
			if error > stats.perfect_error:
				out["crooked"] += 1
				var t: float = (error - stats.perfect_error) / (stats.ruin_error - stats.perfect_error)
				bill_worth = lerpf(stats.crooked_worth.x, stats.crooked_worth.y, t)
				out["top_cut"] = _bill_region(row["shown"], column["shown"])
			out["worth"] += bill_worth
	return out


## Soma as notas de `more` em `into` (a de cima passa a ser a de `more`, se tiver alguma).
func _add_bills(into: Dictionary, more: Dictionary) -> void:
	for key in ["bills", "crooked", "worth", "ruined"]:
		into[key] += more[key]
	if more["bills"] > 0:
		into["top_cut"] = more["top_cut"]


## Pedaço da folha (linha de `row` e coluna de `column`, m da frente de cada lado) que vira a nota
## de cima de um montinho torto, na textura da folha inteira.
func _bill_region(row: Vector2, column: Vector2) -> Rect2:
	var v_top := 1.0 - row.y / SHEET_SIZE.y
	var v_bottom := 1.0 - row.x / SHEET_SIZE.y
	return Rect2(column.x / SHEET_SIZE.x, v_top, (column.y - column.x) / SHEET_SIZE.x, v_bottom - v_top)


## Soma as notas no montinho parado na frente (ou começa outro) e devolve onde fica o alto dele.
func _add_to_pile(bills: int, crooked: int, worth: float, top_cut: Rect2) -> Vector3:
	var smudged := bills if sheet_wet else 0
	var pile: Node = _kitnet.items.items.get(_pile_id)
	var pile_ok: bool = pile != null and pile.holder == 0 and pile.data.get("resting", false) \
			and pile.data.get("count", 0) + bills <= stats.pile_max
	if pile_ok:
		var count: int = pile.data["count"]
		_kitnet.items.set_data(pile, "worth", pile.data.get("worth", float(count)) + worth)
		_kitnet.items.set_data(pile, "crooked", pile.data.get("crooked", 0) + crooked)
		_kitnet.items.set_data(pile, "smudged", pile.data.get("smudged", 0) + smudged)
		_kitnet.items.set_data(pile, "top_smudged", sheet_wet)
		_kitnet.items.set_data(pile, "top_cut", top_cut)
		_kitnet.items.set_data(pile, "count", count + bills)
	else:
		var spot := _free_pile_spot()
		var data := {"count": bills, "smudged": smudged, "top_smudged": sheet_wet, "crooked": crooked,
				"worth": worth, "top_cut": top_cut, "resting": true}
		var height: float = maxf(bills * ItemKinds.BILL_THICKNESS, 0.0015)
		pile = _kitnet.items.spawn("bills", global_transform * Transform3D(Basis.IDENTITY, spot + Vector3.UP * height / 2.0), data)
		_pile_id = pile.id
	var top: float = pile.data["count"] * ItemKinds.BILL_THICKNESS / 2.0
	return pile.global_position + global_basis.y * top


## O lugar do montinho na frente da guilhotina, ou um do lado se já tiver um parado lá.
func _free_pile_spot() -> Vector3:
	for i in 3:
		var spot := PILE_POS + PILE_STEP * i
		var taken := false
		for item in _kitnet.items.items.values():
			if item.kind == "bills" and item.holder == 0 and \
					(global_transform * spot).distance_to(item.global_position) < 0.08:
				taken = true
		if not taken:
			return spot
	return PILE_POS


func _on_item_picked(item: Node) -> void:
	if item.id == _pile_id:
		_pile_id = 0


## Host: quem operava saiu da sala.
func drop_peer(peer: int) -> void:
	if operator == peer:
		operator = 0
		_send_state()


func send_state_to(peer: int) -> void:
	_sync.rpc_id(peer, pieces_left, phase, cut_pos, sheet_wet, operator, stack_count, top_strip)


func _send_state() -> void:
	var args := [pieces_left, phase, cut_pos, sheet_wet, operator, stack_count, top_strip]
	_kitnet.rpc_roster(self, &"_sync", args)
	_sync.callv(args)


## Como saiu um corte das linhas: as tiras ainda não são notas, então só se o corte foi reto.
func _rows_text(released: Array[Dictionary], ruined: int) -> String:
	var text := ""
	if not released.is_empty():
		var clean := released.all(func(p): return p["error"] <= stats.perfect_error)
		text = "Clean cut!" if clean else "Crooked cut"
	if ruined > 0:
		text = ("%s\n" % text if not text.is_empty() else "") + "Ruined %d row%s" % [ruined, "" if ruined == 1 else "s"]
	return text


## Como saíram as notas do corte das colunas.
func _bills_text(bills: Dictionary) -> String:
	var count: int = bills["bills"]
	var ruined: int = bills["ruined"]
	var text := ""
	if count > 0 and bills["crooked"] == 0:
		text = "Clean cut!"
	elif count > 0:
		text = "Crooked cut: bills worth %d%%" % roundi(100.0 * bills["worth"] / count)
	if ruined > 0:
		text = ("%s\n" % text if not text.is_empty() else "") + "Ruined %d bill%s" % [ruined, "" if ruined == 1 else "s"]
	return text


## Host: conta como saiu para quem cortou (quem opera e, se foi outro, quem puxou a alavanca).
func _send_result(tell: Array, text: String) -> void:
	if text.is_empty():
		return
	for peer: int in tell:
		if peer == multiplayer.get_unique_id():
			_show_result(text)
		elif _kitnet.players.has(peer):
			_show_result.rpc_id(peer, text)


# --- Pedidos de quem opera --------------------------------------------------------------------

func is_operated_by(player: Node) -> bool:
	return operator != 0 and operator == player.name.to_int()


## Quem opera mexeu o mouse: a folha anda (pixels para baixo = a folha vem para quem opera,
## passando da lâmina). `fine` (Shift segurado) anda bem menos, para acertar a marca.
func slide(pixels: float, fine := false) -> void:
	if _locked():
		return
	var per_pixel := FEED_PER_PIXEL * (FEED_FINE if fine else 1.0)
	feed = clampf(feed + pixels * per_pixel, 0.0, feed_max())
	_feed_dirty = true


## Põe a folha passando `amount` m da lâmina (testes).
func slide_to(amount: float) -> void:
	slide((amount - feed) / FEED_PER_PIXEL)


## Clique de quem opera. A folha já para aqui, sem esperar o host; o golpe que vem dele renova a
## trava. Clicar de novo antes da alavanca voltar não faz nada.
func request_cut() -> void:
	if _locked():
		return
	_lock_for_swing()
	if multiplayer.is_server():
		_cut(multiplayer.get_unique_id(), feed)
	else:
		_rpc_cut.rpc_id(1, feed)


func request_leave() -> void:
	if multiplayer.is_server():
		_leave(multiplayer.get_unique_id())
	else:
		_rpc_leave.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_cut(at: float) -> void:
	if multiplayer.is_server():
		_cut(multiplayer.get_remote_sender_id(), at)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_leave() -> void:
	if multiplayer.is_server():
		_leave(multiplayer.get_remote_sender_id())


func _leave(peer: int) -> void:
	if operator == peer:
		operator = 0
		feed = 0.0
		_send_state()


# --- Aplicado em todas as máquinas ------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _sync(pieces: int, new_phase: Phase, cut: float, wet: bool, op: int, stack: int, top: Vector2) -> void:
	var to_columns := new_phase == Phase.COLUMNS and phase != Phase.COLUMNS
	pieces_left = pieces
	phase = new_phase
	cut_pos = cut
	sheet_wet = wet
	operator = op
	stack_count = stack
	top_strip = top
	if _landing == 0:
		_shown_count = stack
		_shown_top = top
	if to_columns:
		# A pilha gira na lâmina: espera as tiras pousarem e anda de onde estava até ela.
		_stack_shift = -STACK_GAP
		create_tween().tween_property(self, "_stack_shift", 0.0, PILE_SLIDE) \
				.set_delay(STRIP_NEXT + STRIP_TO_PILE).set_trans(Tween.TRANS_SINE)
	# Cada mudança (pôs a folha, cortou, entrou, saiu) começa com a folha na lâmina.
	feed = 0.0
	_feed_target = 0.0
	_guide.visible = op != 0
	var now: Node = _kitnet.players.get(op) if op != 0 else null
	if now != _operating_player:
		if is_instance_valid(_operating_player) and _operating_player.operating == self:
			_operating_player.operating = null
		_operating_player = now
		if now != null:
			now.operating = self
		_settle_arm()
	_update_paper()


## Onde a alavanca fica parada: mais em pé com alguém operando.
func _rest_angle() -> float:
	return OPERATE_ANGLE if operator != 0 else OPEN_ANGLE


## A alavanca vai para onde fica parada. No meio do golpe não precisa: a volta dele já mira lá.
func _settle_arm() -> void:
	if _arm == null or _arm_swinging:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_arm, "rotation:z", _rest_angle(), 0.3).set_trans(Tween.TRANS_SINE)


## A volta do golpe (t de 0, embaixo, a 1, parada). Lê o ângulo a cada quadro, porque quem opera
## pode sair no meio (acabou a folha, caiu).
func _lift_arm(t: float) -> void:
	_arm.rotation.z = _rest_angle() * t


func _locked() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _locked_until


func _lock_for_swing() -> void:
	_locked_until = Time.get_ticks_msec() / 1000.0 + stats.swing_down + stats.swing_up


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _remote_feed(amount: float) -> void:
	# Durante o golpe a folha está parada: uma posição atrasada, de antes do clique, não vale.
	if multiplayer.get_remote_sender_id() == operator and not _locked():
		_feed_target = clampf(amount, 0.0, feed_max())


@rpc("authority", "call_remote", "reliable")
func _show_result(text: String) -> void:
	var me: Node = _kitnet.local_player()
	if me != null:
		me.hud.show_message(text, 1.6)


## O golpe, em todas as máquinas: a folha fica parada passando `at` m da lâmina até a alavanca
## voltar, e o resultado do corte chega do host quando a lâmina está embaixo.
@rpc("authority", "call_remote", "reliable")
func _swing(at: float) -> void:
	_noise_until = Time.get_ticks_msec() / 1000.0 + stats.swing_down + 0.25
	_lock_for_swing()
	_feed_target = at
	if _is_mine():
		feed = at
	if _arm == null:
		get_tree().create_timer(stats.swing_down).timeout.connect(_chop)
		return
	if _tween:
		_tween.kill()
	_arm_swinging = true
	_tween = create_tween()
	_tween.tween_property(_arm, "rotation:z", 0.0, stats.swing_down).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_chop)
	_tween.tween_method(_lift_arm, 0.0, 1.0, stats.swing_up).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): _arm_swinging = false)


## A lâmina bateu embaixo: o som do golpe e um tranco na câmera de quem opera ou está perto.
func _chop() -> void:
	_chop_player.play()
	var me: Node = _kitnet.local_player()
	if me == null:
		return
	var near: float = 1.0 - me.global_position.distance_to(global_position) / CHOP_KICK_REACH
	var strength := 1.0 if is_operated_by(me) else clampf(near, 0.0, 1.0) * 0.5
	if strength > 0.0:
		me.kick_camera(CHOP_KICK * strength)


## Em todas as máquinas: a tira `index`, de `from` a `to` (m, da frente, na fase de agora), acabou
## de ser cortada (a segunda vai um pouco depois da primeira) e vai para `dest`:
##   STACK: gira e pousa na pilha de tiras, do lado da lâmina.
##   PILE: escorrega até o alto do montinho em `pile_at` (no referencial da guilhotina) e some ali,
##     onde as notas dela já estão.
##   SCRAP: retalho, sem nota nenhuma: escorrega para a frente, fica um pouco na mesa e some.
@rpc("authority", "call_remote", "reliable")
func _strip_fell(index: int, from: float, to: float, dest: Dest, pile_at: Vector3) -> void:
	var strip := _strips[index]
	# Onde ela estava: a frente do que sobrou (`cut_pos`, ainda o de antes do corte) está na frente
	# do que está na lâmina, e a tira começa `from - cut_pos` atrás dela.
	_pose_paper(strip, phase == Phase.COLUMNS, from, to, _front_z() - (from - cut_pos), top_strip)
	strip.scale = Vector3.ONE
	strip.visible = true
	if _strip_tweens[index]:
		_strip_tweens[index].kill()
	var tween := create_tween()
	_strip_tweens[index] = tween
	tween.tween_interval(STRIP_NEXT * index)
	tween.set_parallel()
	match dest:
		Dest.STACK:
			_landing += 1
			var spot := Vector3(STACK_X, SHEET_Y + 0.002, CUT_Z - STACK_GAP - SHEET_SIZE.x / 2.0)
			tween.chain().tween_property(strip, "position", spot, STRIP_TO_PILE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(strip, "rotation:y", PI / 2.0, STRIP_TO_PILE).set_trans(Tween.TRANS_SINE)
			tween.chain().tween_callback(func():
				strip.hide()
				_landing -= 1
				if _landing == 0:
					_shown_count = stack_count
					_shown_top = top_strip)
		Dest.PILE:
			tween.chain().tween_property(strip, "position", pile_at + Vector3.UP * 0.002, STRIP_TO_PILE) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(strip, "rotation:y", strip.rotation.y + randf_range(-0.25, 0.25), STRIP_TO_PILE)
			tween.chain().tween_callback(strip.hide)
		_:
			var rest := strip.position + Vector3(randf_range(-0.03, 0.03), 0.0, 0.14)
			rest.y = 0.002
			tween.chain().tween_property(strip, "position", rest, SCRAP_SLIDE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(strip, "rotation:y", strip.rotation.y + randf_range(-0.6, 0.6), SCRAP_SLIDE)
			tween.chain().tween_property(strip, "scale", Vector3(0.01, 0.01, 1.0), SCRAP_FADE).set_delay(SCRAP_STAY)
			tween.chain().tween_callback(strip.hide)


# --- O que cada jogador vê --------------------------------------------------------------------

func _is_mine() -> bool:
	return operator != 0 and operator == multiplayer.get_unique_id()


func _prompt(player: Node) -> String:
	if operator != 0 and not is_operated_by(player):
		return "Someone is holding the sheet (pull the red lever to cut for them)"
	var held: Node = player.held_item()
	if held != null:
		if held.kind != "sheet":
			return "Needs a printed sheet"
		if has_sheet():
			return "There's already a sheet in the guillotine"
		if held.data.get("wet", false):
			return "[E] Place sheet (still wet: bills will smudge)"
		return "[E] Place sheet"
	if _busy:
		return ""
	if phase == Phase.COLUMNS:
		return "[E] Cut  (split the columns)"
	if has_sheet():
		return "[E] Cut  (%d row%s left)" % [pieces_left, "" if pieces_left == 1 else "s"]
	return "[E] Pull the lever  (place a printed sheet to cut)"


## Pegador da alavanca: com alguém segurando a folha, outro jogador corta para ele.
func _lever_prompt(player: Node) -> String:
	if _busy or is_operated_by(player):
		return ""
	if operator != 0:
		return "[E] Pull the lever (cut where they hold the sheet)" if has_sheet() else ""
	return "[E] Pull the lever"


## Um pedaço de papel com a textura da folha, deitado na mesa e escondido.
func _paper_mesh(mesh_name: String) -> MeshInstance3D:
	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = SHEET_FRONT
	quad.material = mat
	var mesh := MeshInstance3D.new()
	mesh.name = mesh_name
	mesh.mesh = quad
	mesh.visible = false
	add_child(mesh)
	return mesh


## O que está na mesa: a folha (da borda de trás até onde já foi cortada, andando com `feed`) e a
## pilha de tiras (esperando do lado da lâmina, ou nela, na fase das colunas).
func _update_paper() -> void:
	_sheet.visible = phase == Phase.ROWS and has_sheet()
	if _sheet.visible:
		_pose_paper(_sheet, false, cut_pos, SHEET_SIZE.y, _front_z(), top_strip)
	_stack.visible = _shown_count > 0
	if not _stack.visible:
		return
	if phase == Phase.COLUMNS:
		_pose_paper(_stack, true, cut_pos, SHEET_SIZE.x, _front_z(), _shown_top)
	else:
		_pose_paper(_stack, true, 0.0, SHEET_SIZE.x, CUT_Z - STACK_GAP, _shown_top)


## Põe um pedaço de papel `mesh` deitado na mesa, com a frente em `front_z`. Da folha (`columns`
## falso): de `from` a `to` (m da frente), na largura inteira. Da pilha girada (`columns`): de
## `from` a `to` ao longo da largura da folha, com a tira `strip` (m da frente da folha) à mostra.
func _pose_paper(mesh: MeshInstance3D, columns: bool, from: float, to: float, front_z: float, strip: Vector2) -> void:
	var length := to - from
	var size: Vector2
	var uv_scale: Vector3
	var uv_offset: Vector3
	if columns:
		var strip_h := strip.y - strip.x
		size = Vector2(length, strip_h)
		uv_scale = Vector3(length / SHEET_SIZE.x, strip_h / SHEET_SIZE.y, 1.0)
		uv_offset = Vector3(from / SHEET_SIZE.x, 1.0 - strip.y / SHEET_SIZE.y, 0.0)
		# Girada: a borda esquerda da imagem (a frente da pilha) vira para a lâmina.
		mesh.rotation = Vector3(-PI / 2.0, PI / 2.0, 0.0)
		mesh.position = Vector3(STACK_X, SHEET_Y, front_z - length / 2.0)
	else:
		# A borda de baixo da imagem é a da frente.
		size = Vector2(SHEET_SIZE.x, length)
		uv_scale = Vector3(1.0, length / SHEET_SIZE.y, 1.0)
		uv_offset = Vector3(0.0, 1.0 - to / SHEET_SIZE.y, 0.0)
		mesh.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
		mesh.position = Vector3(SHEET_X, SHEET_Y, front_z - length / 2.0)
	var quad := mesh.mesh as QuadMesh
	if not quad.size.is_equal_approx(size):
		quad.size = size
	var mat := quad.material as StandardMaterial3D
	# A versão toon do material guarda cópia da escala e do deslocamento: muda junto.
	var changed := mat.uv1_scale != uv_scale or mat.uv1_offset != uv_offset
	mat.uv1_scale = uv_scale
	mat.uv1_offset = uv_offset
	if _paint_paper(mat) or changed:
		Toon.sync(mat)


## Cor e brilho do papel (molhado: escuro e brilhando). Devolve se mudou.
func _paint_paper(mat: StandardMaterial3D) -> bool:
	var wet_color := Color(0.75, 0.84, 0.76) if sheet_wet else Color.WHITE
	if mat.albedo_color == wet_color:
		return false
	mat.albedo_color = wet_color
	mat.roughness = 0.15 if sheet_wet else 0.8
	return true


## z da frente do que está na lâmina (a folha, ou a pilha na fase das colunas).
func _front_z() -> float:
	return CUT_Z + feed + (_stack_shift if phase == Phase.COLUMNS else 0.0)


## x do meio do que está na lâmina, e a meia largura dele.
func _work_x() -> float:
	return STACK_X if phase == Phase.COLUMNS else SHEET_X


func _work_half_width() -> float:
	return (_shown_top.y - _shown_top.x) / 2.0 if phase == Phase.COLUMNS else SHEET_SIZE.x / 2.0


## O som do golpe, feito aqui mesmo: o estalo da lâmina no papel, a pancada surda na mesa e o
## metal tinindo um pouco.
func _build_chop_sound() -> void:
	const RATE := 22050
	var count := int(RATE * 0.4)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var crunch := 0.0
	for i in count:
		var t := float(i) / RATE
		crunch = lerpf(crunch, rng.randf_range(-1.0, 1.0), 0.4)
		var s := crunch * exp(-t * 40.0) * 0.7 \
				+ sin(TAU * 85.0 * t) * exp(-t * 20.0) * 0.6 \
				+ sin(TAU * 1870.0 * t) * exp(-t * 11.0) * 0.1 \
				+ sin(TAU * 2930.0 * t) * exp(-t * 16.0) * 0.05
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	_chop_player = AudioStreamPlayer3D.new()
	_chop_player.name = "ChopSound"
	_chop_player.stream = wav
	_chop_player.position = Vector3(0.0, TOP_Y, CUT_Z)
	_chop_player.unit_size = 2.0
	add_child(_chop_player)


## Linha-guia da lâmina: um risco vermelho fininho por cima da folha, só com alguém operando.
func _build_guide() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.44, 0.0012)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.15, 0.1, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	_guide = MeshInstance3D.new()
	_guide.name = "CutGuide"
	_guide.mesh = quad
	_guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_guide.rotation.x = -PI / 2
	_guide.position = Vector3(0.0, SHEET_Y + 0.0012, CUT_Z)
	_guide.visible = false
	add_child(_guide)


## Onde fica a luva de quem opera (side 1 = direita, -1 = esquerda): segurando a folha (ou a
## pilha) pelos lados, atrás da lâmina, com os dedos para dentro em cima do papel (os braços vêm de
## fora e não tapam a linha de corte); anda junto com ela.
func hand_transform(side: int) -> Transform3D:
	var back := _front_z() - (_length() - cut_pos)
	var z := clampf(back + 0.05, back + 0.02, CUT_Z - 0.035)
	var local := Transform3D(Basis(Vector3.UP, side * PI / 2),
			Vector3(_work_x() + side * (_work_half_width() + 0.06), SHEET_Y + 0.01, z))
	return global_transform * local


## Câmera de quem opera, em cima da mesa olhando para a lâmina (de lado, acompanhando o que está
## nela).
func view_transform() -> Transform3D:
	var shift := Vector3(_view_x - SHEET_X, 0.0, 0.0)
	var from := global_transform * (VIEW_FROM + shift)
	return Transform3D(Basis.IDENTITY, from).looking_at(global_transform * (VIEW_AT + shift), global_basis.y)


## Onde quem opera fica em pé (no chão) e para onde olha.
func stand_point() -> Vector3:
	return global_transform * STAND


func stand_yaw() -> float:
	return global_basis.get_euler().y

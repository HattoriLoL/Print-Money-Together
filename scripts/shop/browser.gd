extends Control
## O navegador de 1998 na tela do PC (fica num SubViewport de computer.gd, que vira a textura do
## monitor). Desenha as lojas a partir do estado (página, carrinho, aviso, os pedidos feitos) e
## diz que botão está embaixo de um ponto (`action_at`).
##
## É igual em todas as máquinas: o estado vem do host e o cursor de quem usa chega pela rede, então
## quem olha por cima do ombro vê a mesma tela, com o cursor andando.
##
## Ações dos botões: "go:<página>" (office, ink, cart), "add:<produto>", "inc:<produto>",
## "dec:<produto>" e "checkout".

const Catalog := preload("res://scripts/shop/catalog.gd")
const REAM_WRAPPER := preload("res://assets/textures/ream_wrapper.png")

const SIZE := Vector2(640, 480)
const GRAY := Color(0.75, 0.75, 0.75)
const DARK := Color(0.5, 0.5, 0.5)
const NAVY := Color(0.0, 0.0, 0.5)
const LINK := Color(0.0, 0.0, 0.85)
const PAGE_TOP := 86.0
const PAGE_BOTTOM := 456.0

var page := "office"
var cart := {}
var notice := ""
## Números dos últimos pedidos (a página "done").
var receipt: Array = []
var cursor := SIZE / 2.0

var _kitnet: Node
var _buttons: Array[Control] = []
var _hover: Control
var _cursor: Polygon2D
var _root: Control
var _balance: Label
var _status: Label
var _blink: Array[CanvasItem] = []
var _tick := 0.0


func setup(kitnet: Node) -> void:
	_kitnet = kitnet


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor = Polygon2D.new()
	_cursor.polygon = PackedVector2Array([Vector2(0, 0), Vector2(0, 17), Vector2(4, 13), Vector2(7, 20),
			Vector2(10, 19), Vector2(7, 12), Vector2(12, 12)])
	_cursor.color = Color.WHITE
	var outline := Line2D.new()
	outline.points = _cursor.polygon
	outline.add_point(Vector2.ZERO)
	outline.width = 1.2
	outline.default_color = Color.BLACK
	_cursor.add_child(outline)
	_cursor.z_index = 10
	add_child(_cursor)
	render()


## Refaz a tela inteira a partir do estado.
func render() -> void:
	if _root != null:
		_root.queue_free()
	_buttons.clear()
	_blink.clear()
	_hover = null
	_root = Control.new()
	_root.size = SIZE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	move_child(_root, 0)
	_chrome()
	match page:
		"cart":
			_cart_page()
		"done":
			_done_page()
		_:
			_store_page(page if Catalog.STORES.has(page) else "office")
	_refresh_live()


## O botão embaixo de `pos` (pixels da tela), ou "".
func action_at(pos: Vector2) -> String:
	for b in _buttons:
		if is_instance_valid(b) and b.get_meta("enabled", true) and b.get_global_rect().has_point(pos):
			return b.get_meta("action")
	return ""


func _process(delta: float) -> void:
	_cursor.position = cursor
	var over: Control = null
	for b in _buttons:
		if is_instance_valid(b) and b.get_meta("enabled", true) and b.get_global_rect().has_point(cursor):
			over = b
	if over != _hover:
		if is_instance_valid(_hover):
			_hover.modulate = Color.WHITE
		_hover = over
		if _hover:
			_hover.modulate = Color(0.85, 0.9, 1.15)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		_refresh_live()


## O que muda sozinho: o saldo, a contagem das entregas e o que pisca.
func _refresh_live() -> void:
	if _kitnet == null or _balance == null:
		return
	_balance.text = "Balance: $%d" % _kitnet.wallet.cash
	var lines: Array[String] = []
	for entry in _kitnet.deliveries.on_the_way:
		var left := int(ceil(_kitnet.deliveries.seconds_left(entry)))
		lines.append("Order #%d (%s): arriving in %d:%02d" % [entry["id"], Catalog.STORES[entry["store"]]["name"], left / 60, left % 60])
	if not notice.is_empty():
		_status.text = notice
	elif not lines.is_empty():
		_status.text = "   ".join(lines)
	else:
		_status.text = "Done"
	var on := int(Time.get_ticks_msec() / 400) % 2 == 0
	for item in _blink:
		if is_instance_valid(item):
			item.visible = on


# --- Janela ---------------------------------------------------------------------------------------

func _chrome() -> void:
	_rect(_root, Rect2(Vector2.ZERO, SIZE), GRAY)
	# Barra de título.
	_rect(_root, Rect2(2, 2, 636, 22), NAVY)
	_rect(_root, Rect2(320, 2, 318, 22), Color(0.1, 0.45, 0.8)).modulate.a = 0.6
	_text(_root, Rect2(8, 3, 420, 20), "WebSurfer 98 - " + _page_title(), 14, Color.WHITE)
	for i in 3:
		_bevel(_root, Rect2(578 + i * 20, 5, 17, 16))
	_text(_root, Rect2(578, 3, 17, 16), "_", 12, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)
	_text(_root, Rect2(618, 4, 17, 16), "x", 12, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)
	# Favoritos (as lojas e o carrinho) e o saldo.
	var x := 6.0
	for store in Catalog.STORE_ORDER:
		_button(_root, Rect2(x, 28, 112, 24), Catalog.STORES[store]["name"], "go:" + store, page == store)
		x += 116.0
	var n := Catalog.count(cart)
	_button(_root, Rect2(x, 28, 100, 24), "Cart (%d)" % n, "go:cart", page == "cart")
	_balance = _text(_root, Rect2(430, 30, 200, 20), "", 15, Color(0.0, 0.35, 0.0), HORIZONTAL_ALIGNMENT_RIGHT)
	# Endereço.
	_text(_root, Rect2(6, 58, 60, 20), "Address", 13, Color.BLACK)
	var field := _rect(_root, Rect2(66, 57, 566, 22), Color.WHITE)
	_frame(field, DARK)
	_text(_root, Rect2(72, 58, 556, 20), _url(), 13, Color.BLACK)
	# Página (branca) e a barra de status.
	var body := _rect(_root, Rect2(4, PAGE_TOP, 632, PAGE_BOTTOM - PAGE_TOP), Color.WHITE)
	_frame(body, DARK)
	_status = _text(_root, Rect2(8, 459, 624, 18), "", 12, Color.BLACK)


func _page_title() -> String:
	match page:
		"cart":
			return "Shopping Cart"
		"done":
			return "Order Confirmed"
	return Catalog.STORES.get(page, Catalog.STORES["office"])["title"]


func _url() -> String:
	match page:
		"cart":
			return "https://secure.shopcart.net/checkout.cgi"
		"done":
			return "https://secure.shopcart.net/thankyou.cgi?order=%s" % ",".join(receipt.map(func(n): return str(n)))
	return Catalog.STORES.get(page, Catalog.STORES["office"])["url"]


# --- Páginas --------------------------------------------------------------------------------------

func _store_page(store: String) -> void:
	var info: Dictionary = Catalog.STORES[store]
	var top := PAGE_TOP + 4.0
	if store == "office":
		_rect(_root, Rect2(8, top, 624, 64), Color(0.05, 0.2, 0.6))
		_text(_root, Rect2(20, top + 2, 300, 40), info["name"], 34, Color(1.0, 0.85, 0.1))
		_text(_root, Rect2(20, top + 40, 600, 20), info["slogan"], 14, Color.WHITE)
		_text(_root, Rect2(380, top + 8, 240, 20), "Free coffee with every order*", 12, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_rect(_root, Rect2(8, top, 624, 64), Color(0.85, 0.0, 0.6))
		_text(_root, Rect2(20, top + 2, 400, 40), info["title"], 34, Color(1.0, 1.0, 0.2))
		_text(_root, Rect2(20, top + 40, 600, 20), info["slogan"], 14, Color.WHITE)
		var star := _text(_root, Rect2(470, top + 10, 150, 30), "* NEW DEALS *", 18, Color(0.2, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		_blink.append(star)
	var ids := Catalog.PRODUCT_ORDER.filter(func(id): return Catalog.PRODUCTS[id]["store"] == store)
	var x := SIZE.x / 2.0 - (ids.size() * 204.0 - 8.0) / 2.0
	for id in ids:
		_product_card(id, Rect2(x, top + 74, 196, 232))
		x += 204.0
	var counter := "You are visitor #00%d" % (301 + Catalog.count(cart))
	_text(_root, Rect2(8, PAGE_BOTTOM - 22, 624, 18), counter, 11, DARK, HORIZONTAL_ALIGNMENT_CENTER)


func _product_card(id: String, r: Rect2) -> void:
	var product: Dictionary = Catalog.PRODUCTS[id]
	var soon: bool = product.get("soon", false)
	var card := _rect(_root, r, Color(0.96, 0.96, 0.92) if not soon else Color(0.9, 0.9, 0.9))
	_frame(card, Color(0.7, 0.7, 0.7))
	_product_picture(id, Rect2(r.position + Vector2(48, 8), Vector2(100, 70)))
	_text(_root, Rect2(r.position.x + 6, r.position.y + 82, r.size.x - 12, 20), product["name"], 14, LINK if not soon else DARK,
			HORIZONTAL_ALIGNMENT_CENTER)
	_text(_root, Rect2(r.position.x + 8, r.position.y + 104, r.size.x - 16, 44), product["blurb"], 12, Color(0.2, 0.2, 0.2),
			HORIZONTAL_ALIGNMENT_CENTER)
	if soon:
		_text(_root, Rect2(r.position.x, r.position.y + 156, r.size.x, 30), "SOLD OUT", 20, Color(0.75, 0.1, 0.1), HORIZONTAL_ALIGNMENT_CENTER)
		return
	_text(_root, Rect2(r.position.x, r.position.y + 152, r.size.x, 30), "$%d" % product["price"], 24, Color(0.75, 0.1, 0.1),
			HORIZONTAL_ALIGNMENT_CENTER)
	var in_cart := int(cart.get(id, 0))
	var full := in_cart >= Catalog.MAX_PER_PRODUCT
	_button(_root, Rect2(r.position.x + 28, r.position.y + 192, r.size.x - 56, 28),
			"Add to cart" + (" (%d)" % in_cart if in_cart > 0 else ""), "add:" + id, false, not full)


## Desenhinho do produto, como a foto de um catálogo.
func _product_picture(id: String, r: Rect2) -> void:
	match id:
		"ream":
			var tex := AtlasTexture.new()
			tex.atlas = REAM_WRAPPER
			tex.region = Rect2(0, 0, 1024, 716)
			var pic := TextureRect.new()
			pic.texture = tex
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.position = r.position
			pic.size = r.size
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_root.add_child(pic)
		"cotton_paper":
			_rect(_root, Rect2(r.position + Vector2(12, 8), Vector2(76, 54)), Color(0.93, 0.9, 0.8))
			_text(_root, Rect2(r.position + Vector2(12, 14), Vector2(76, 40)), "?", 32, Color(0.6, 0.55, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
		_:
			var original := id == "ink_original"
			_rect(_root, Rect2(r.position + Vector2(28, 4), Vector2(44, 62)), Color(0.08, 0.08, 0.09))
			_rect(_root, Rect2(r.position + Vector2(28, 22), Vector2(44, 22)),
					Color(0.15, 0.7, 0.3) if original else Color(0.85, 0.25, 0.65))
			_text(_root, Rect2(r.position + Vector2(28, 23), Vector2(44, 20)), "INK", 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)


func _cart_page() -> void:
	var top := PAGE_TOP + 8.0
	_text(_root, Rect2(16, top, 600, 30), "Your shopping cart", 24, NAVY)
	top += 38.0
	if Catalog.count(cart) == 0:
		_text(_root, Rect2(16, top + 10, 600, 24), "Your cart is empty. Go buy something!", 15, Color.BLACK)
		return
	_text(_root, Rect2(16, top, 300, 18), "Item", 12, DARK)
	_text(_root, Rect2(330, top, 120, 18), "Qty", 12, DARK, HORIZONTAL_ALIGNMENT_CENTER)
	_text(_root, Rect2(500, top, 116, 18), "Price", 12, DARK, HORIZONTAL_ALIGNMENT_RIGHT)
	top += 20.0
	for id in Catalog.PRODUCT_ORDER:
		var qty := int(cart.get(id, 0))
		if qty <= 0:
			continue
		var product: Dictionary = Catalog.PRODUCTS[id]
		_rect(_root, Rect2(12, top, 616, 30), Color(0.94, 0.94, 0.98))
		_text(_root, Rect2(18, top + 5, 310, 20), "%s  (%s)" % [product["name"], Catalog.STORES[product["store"]]["name"]], 14, Color.BLACK)
		_button(_root, Rect2(340, top + 3, 24, 24), "-", "dec:" + id)
		_text(_root, Rect2(366, top + 5, 48, 20), str(qty), 15, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)
		_button(_root, Rect2(416, top + 3, 24, 24), "+", "inc:" + id, false, qty < Catalog.MAX_PER_PRODUCT)
		_text(_root, Rect2(500, top + 5, 116, 20), "$%d" % (product["price"] * qty), 15, Color.BLACK, HORIZONTAL_ALIGNMENT_RIGHT)
		top += 34.0
	for store in Catalog.stores_in(cart):
		_text(_root, Rect2(18, top, 400, 18), "Shipping (%s)" % Catalog.STORES[store]["name"], 13, Color(0.25, 0.25, 0.25))
		_text(_root, Rect2(500, top, 116, 18), "$%d" % Catalog.SHIPPING, 13, Color(0.25, 0.25, 0.25), HORIZONTAL_ALIGNMENT_RIGHT)
		top += 20.0
	_rect(_root, Rect2(12, top + 2, 616, 2), DARK)
	var total := Catalog.total(cart)
	_text(_root, Rect2(18, top + 8, 400, 24), "TOTAL", 18, Color.BLACK)
	_text(_root, Rect2(440, top + 8, 176, 24), "$%d" % total, 18, Color.BLACK, HORIZONTAL_ALIGNMENT_RIGHT)
	var afford: bool = _kitnet == null or total <= _kitnet.wallet.cash
	_button(_root, Rect2(440, top + 40, 176, 32), "Place order", "checkout", false, afford)
	if not afford:
		_text(_root, Rect2(18, top + 46, 410, 20), "Not enough money in the account.", 14, Color(0.8, 0.1, 0.1))
	else:
		_text(_root, Rect2(18, top + 46, 410, 20), "Delivered to your door in about %d seconds." % int(Catalog.DELIVERY_SECONDS),
				13, Color(0.2, 0.2, 0.2))


func _done_page() -> void:
	var top := PAGE_TOP + 30.0
	_text(_root, Rect2(16, top, 608, 34), "Thank you for your order!", 26, Color(0.0, 0.45, 0.0), HORIZONTAL_ALIGNMENT_CENTER)
	var numbers := ", ".join(receipt.map(func(n): return "#%d" % n))
	_text(_root, Rect2(16, top + 50, 608, 22), "Order %s confirmed." % numbers, 16, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER)
	_text(_root, Rect2(40, top + 78, 560, 48),
			"The courier will ring the bell and leave the parcel\nat your door in about %d seconds." % int(Catalog.DELIVERY_SECONDS),
			15, Color(0.2, 0.2, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	_text(_root, Rect2(16, top + 140, 608, 20), "No signature required. No questions asked.", 13, DARK, HORIZONTAL_ALIGNMENT_CENTER)
	_button(_root, Rect2(220, top + 180, 200, 32), "Continue shopping", "go:office")


# --- Peças ----------------------------------------------------------------------------------------

func _rect(parent: Control, r: Rect2, color: Color) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _text(parent: Control, r: Rect2, text: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Borda fina em volta de um retângulo.
func _frame(c: Control, color: Color) -> void:
	for r in [Rect2(0, 0, c.size.x, 1), Rect2(0, c.size.y - 1, c.size.x, 1), Rect2(0, 0, 1, c.size.y), Rect2(c.size.x - 1, 0, 1, c.size.y)]:
		_rect(c, r, color)


## Botão cinza de relevo (claro em cima e à esquerda, escuro embaixo e à direita).
func _bevel(parent: Control, r: Rect2, pressed := false) -> ColorRect:
	var b := _rect(parent, r, GRAY)
	var light := Color.WHITE if not pressed else Color(0.35, 0.35, 0.35)
	var shade := Color(0.35, 0.35, 0.35) if not pressed else Color.WHITE
	_rect(b, Rect2(0, 0, r.size.x, 1), light)
	_rect(b, Rect2(0, 0, 1, r.size.y), light)
	_rect(b, Rect2(0, r.size.y - 1, r.size.x, 1), shade)
	_rect(b, Rect2(r.size.x - 1, 0, 1, r.size.y), shade)
	return b


func _button(parent: Control, r: Rect2, text: String, action: String, pressed := false, enabled := true) -> ColorRect:
	var b := _bevel(parent, r, pressed)
	_text(b, Rect2(Vector2.ZERO, r.size), text, 14, Color.BLACK if enabled else DARK, HORIZONTAL_ALIGNMENT_CENTER)
	b.set_meta("action", action)
	b.set_meta("enabled", enabled)
	_buttons.append(b)
	return b

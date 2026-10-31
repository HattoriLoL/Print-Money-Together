extends RefCounted
## O que dá para comprar no PC da kitnet (scripts/machines/computer.gd): as lojas da internet e os
## produtos. Preços em dólares inteiros. Cada produto comprado vira um item (`kind` + `data`)
## dentro da caixa que o entregador deixa na porta (scripts/shop/deliveries.gd).
##
## `blurb` já vem quebrado em linhas (o cartão do produto é estreito).
##
## O grupo começa no amador: papel de escritório e cartucho de jato de tinta. Os produtos com
## `soon` aparecem esgotados, para mostrar que tem coisa melhor vindo.

const STORES := {
	"office": {
		"name": "OFFICE+",
		"title": "OFFICE+ Supplies",
		"url": "http://www.officeplus.biz/shop",
		"slogan": "Everything for the modern office!",
	},
	"ink": {
		"name": "INK-O-RAMA",
		"title": "INK-O-RAMA!!!",
		"url": "http://members.webcity.net/~inkorama/deals.htm",
		"slogan": "The cheapest ink on the World Wide Web!!!",
	},
}
## Ordem em que as lojas aparecem nos favoritos.
const STORE_ORDER := ["office", "ink"]

const PRODUCTS := {
	"ream": {
		"store": "office", "name": "A4 copy paper", "price": 9,
		"blurb": "One ream, bright white.\nJams less!",
		"kind": "ream", "data": {},
	},
	"cotton_paper": {
		"store": "office", "name": "Cotton paper", "price": 60,
		"blurb": "Feels like the\nreal thing.",
		"soon": true,
	},
	"ink_generic": {
		"store": "ink", "name": "Compatible ink cartridge", "price": 19,
		"blurb": "Fits most printers!\nColors may vary.",
		"kind": "cartridge", "data": {"ink": 1.0, "brand": "generic"},
	},
	"ink_original": {
		"store": "ink", "name": "Original ink cartridge", "price": 49,
		"blurb": "The real deal.\nAccept no substitutes.",
		"kind": "cartridge", "data": {"ink": 1.0, "brand": "original"},
	},
}
## Ordem dos produtos nas páginas.
const PRODUCT_ORDER := ["ream", "cotton_paper", "ink_generic", "ink_original"]

## Frete de cada loja que entra no pedido (cada loja manda a sua caixa).
const SHIPPING := 5
## Quantas unidades de um produto cabem no carrinho.
const MAX_PER_PRODUCT := 9
## Segundos do pedido até a caixa chegar na porta.
const DELIVERY_SECONDS := 30.0


static func can_buy(product_id: String) -> bool:
	return PRODUCTS.has(product_id) and not PRODUCTS[product_id].get("soon", false)


## Lojas que aparecem no carrinho, na ordem dos favoritos.
static func stores_in(cart: Dictionary) -> Array:
	var stores := []
	for store in STORE_ORDER:
		for id in cart:
			if PRODUCTS[id]["store"] == store and cart[id] > 0:
				stores.append(store)
				break
	return stores


static func subtotal(cart: Dictionary) -> int:
	var sum := 0
	for id in cart:
		sum += PRODUCTS[id]["price"] * int(cart[id])
	return sum


static func shipping(cart: Dictionary) -> int:
	return SHIPPING * stores_in(cart).size()


static func total(cart: Dictionary) -> int:
	return subtotal(cart) + shipping(cart)


static func count(cart: Dictionary) -> int:
	var n := 0
	for id in cart:
		n += int(cart[id])
	return n

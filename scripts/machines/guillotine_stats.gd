extends Resource
## Números de um modelo de guilhotina (data/machines/guillotine_*.tres). Os níveis de upgrade são
## outros arquivos com os mesmos campos.

@export var display_name := "Lever guillotine"
## Linhas de notas numa folha A4 (os cortes horizontais soltam uma por vez, em tiras).
@export var rows_per_sheet := 3
## Notas em cada linha: as colunas, que o corte vertical separa nas tiras.
@export var bills_per_row := 2
## Segundos da alavanca descendo (o corte acontece embaixo) e voltando.
@export var swing_down := 0.16
@export var swing_up := 0.4
## Máximo de notas num montinho; passando disso, começa outro do lado.
@export var pile_max := 60
## Barulho do golpe da lâmina, de 0 a 1 (dura um instante).
@export_range(0.0, 1.0) var noise := 0.3
## Corte: até que erro (m, somando os dois cortes de uma linha) as notas saem perfeitas, a partir
## de qual a linha estraga, e quanto vale uma nota torta (do erro mínimo ao máximo; perfeita vale 1).
@export var perfect_error := 0.002
@export var ruin_error := 0.01
@export var crooked_worth := Vector2(0.9, 0.3)

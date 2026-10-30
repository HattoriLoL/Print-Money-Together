extends Resource
## Números de um modelo de guilhotina (data/machines/guillotine_*.tres). Os níveis de upgrade são
## outros arquivos com os mesmos campos.

@export var display_name := "Lever guillotine"
## Linhas de notas numa folha A4 (cada corte solta uma).
@export var rows_per_sheet := 3
## Notas em cada linha.
@export var bills_per_row := 2
## Segundos da alavanca descendo (o corte acontece embaixo) e voltando.
@export var swing_down := 0.16
@export var swing_up := 0.4
## Máximo de notas num montinho; passando disso, começa outro do lado.
@export var pile_max := 60
## Barulho do golpe da lâmina, de 0 a 1 (dura um instante).
@export_range(0.0, 1.0) var noise := 0.3

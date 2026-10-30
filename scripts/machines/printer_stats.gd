extends Resource
## Números de um modelo de impressora (data/machines/printer_*.tres). Os níveis de upgrade são
## outros arquivos com os mesmos campos: mais rápida, mais folhas, mais barulho...

@export var display_name := "Old office printer"
## Segundos esquentando depois de ligar, antes da primeira folha.
@export var warmup_seconds := 3.0
## Segundos para cada folha sair.
@export var seconds_per_sheet := 5.0
## Folhas A4 que cada resma rende.
@export var sheets_per_ream := 5
## Quantas folhas cabem no alimentador.
@export var paper_capacity := 15
## Quantas folhas impressas cabem na bandeja de saída antes de a impressora parar.
@export var output_capacity := 8
## Tinta (toner) gasta por folha; o cartucho vai de 0 a 1.
@export var ink_per_sheet := 0.02
## Barulho enquanto imprime, de 0 a 1 (vai alimentar a suspeita dos vizinhos).
@export_range(0.0, 1.0) var noise := 0.35
## Consumo de energia ligada (o disjuntor da kitnet vai somar isso).
@export var power_watts := 300.0

"""Planta da kitnet 301 (metros, coordenadas do Blender: +X direita, +Y fundo, +Z cima).

O interior vai de x 0 a 7 e y 0 a 5 (35 m²). A porta de entrada fica na parede da frente (y = 0)
e dá para o corredor do prédio, que corre na frente da kitnet. No Godot (+Y para cima) o +Y daqui
vira -Z.

    y=5 +----------------------------+-----------+
        | sofá-cama   [impressora]   |  serviço  |
        |                  [papel]   | (lavar,   |
        | guarda-                    vão  varal, |
        | roupa       [mesa: corte,  |  tanque)  |
        |              contadora]    +-----------+
        | geladeira                  | banheiro  |
        | [pia  tinta  fogão]       porta (forro)|
    y=0 +-----------------[porta]----+-----------+
        corredor: 303 em frente, 302 ao lado, escada no fim
"""

WALL_H = 2.6
EXT_T = 0.2    # parede externa (e a do corredor)
INT_T = 0.12   # parede interna
DOOR_H = 2.1

W = 7.0
D = 5.0

# Parede interna que separa banheiro e serviço do cômodo principal.
PART_X = 5.0
# Parede entre banheiro (frente) e serviço (fundo).
BATH_Y = 2.2

BATH = (PART_X + INT_T, 0.0, W, BATH_Y)               # x0, y0, x1, y1
SERVICE = (PART_X + INT_T, BATH_Y + INT_T, W, D)

# Vãos (início, fim) ao longo da parede.
ENTRANCE = (3.7, 4.5)          # x, parede da frente
BATH_DOOR = (0.9, 1.6)         # y, parede x = PART_X
SERVICE_OPENING = (2.9, 4.1)   # y, parede x = PART_X (sem porta)

# Janelas: (início, fim, peitoril, topo).
WINDOW_MAIN = (1.6, 3.4, 1.0, 2.2)      # x, parede do fundo
WINDOW_SERVICE = (5.5, 6.6, 1.3, 2.2)   # x, parede do fundo (basculante)
WINDOW_BATH = (1.1, 1.6, 1.8, 2.2)      # y, parede leste

# Forro de PVC rebaixado do banheiro, com o alçapão em cima do vaso.
BATH_CEILING_Z = 2.35
BATH_HATCH = (6.15, 6.65, 1.5, 2.0)     # x0, x1, y0, y1

# Corredor do prédio (na frente da kitnet).
HALL_Y = (-EXT_T - 1.3, -EXT_T)         # piso livre
HALL_X = (-1.5, 10.0)
DOOR_302 = (8.2, 9.0)                   # x, mesma parede da entrada
DOOR_303 = (3.0, 3.8)                   # x, parede do outro lado (em frente)
STAIRS_DOOR = (-1.2, -0.4)              # y, fim oeste do corredor (porta corta-fogo)

# Onde os 4 jogadores nascem (x, y), longe dos móveis.
SPAWNS = [(1.5, 3.4), (3.7, 3.3), (4.2, 1.4), (1.4, 1.2)]

# Escada do prédio, atrás da porta corta-fogo no fim oeste do corredor: desce do 3º andar até o
# térreo em lances de ida e volta (dois por andar, com um patamar no meio). O térreo fica na altura
# da calçada (exterior.STREET_Z + 0,15), com o hall de entrada e a porta da rua.
STAIR_FLOORS = 3
STAIR_FLOOR_H = 8.45 / STAIR_FLOORS
STAIR_X = (-4.6, -1.7)            # vão livre (a parede leste é a do fim do corredor)
STAIR_SPLIT = (-3.15, -3.05)      # parede do meio, entre o lance de descer (oeste) e o de voltar
STAIR_LANDING_Y = (-1.7, -0.2)    # patamar de cada andar, na frente da porta
STAIR_STEPS = 8                   # espelhos por lance
STAIR_TREAD = 0.28
STAIR_MID_Y = (STAIR_LANDING_Y[1] + (STAIR_STEPS - 1) * STAIR_TREAD,
               STAIR_LANDING_Y[1] + (STAIR_STEPS - 1) * STAIR_TREAD + 1.4)   # patamar do meio
LOBBY_Y = (-4.7, -1.7)            # hall do térreo, na frente do patamar
STREET_DOOR = (-3.7, -2.6)        # x, parede norte do hall do térreo

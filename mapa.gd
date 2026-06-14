extends Node2D

const TAMANHO_CELULA = 64

var paredes: Array = []
var saida_pos: Vector2i = Vector2i(-1, -1)
var sala_atual: int = 0

signal jogador_na_saida

# Pool de layouts possíveis — cada '#' é parede, '.' chão, 'E' saída
var layouts = [
	# Sala 0 — Tutorial (layout fixo e espaçoso para ensinar movimentação)
	[
		"#########",
		"#.......#",
		"#.......#",
		"#.......#",
		"#.......#",
		"#......E#",
		"#########",
	],
	# Sala 1
	[
		"#########",
		"#.......#",
		"#.###...#",
		"#...#...#",
		"#...#.E.#",
		"#.......#",
		"#########",
	],
	# Sala 2
	[
		"#########",
		"#...#...#",
		"#...#...#",
		"#.......#",
		"###.###.#",
		"#.....E.#",
		"#########",
	],
	# Sala 3
	[
		"#########",
		"#.......#",
		"#.#####.#",
		"#.#.E.#.#",
		"#.#...#.#",
		"#.......#",
		"#########",
	],
	# Sala 4
	[
		"#########",
		"#..E....#",
		"#.#####.#",
		"#.......#",
		"#.###.#.#",
		"#.......#",
		"#########",
	],
]

func _ready():
	carregar_sala(0)

func carregar_sala(indice: int):
	sala_atual = indice
	
	# Limpa a sala anterior
	for filho in get_children():
		filho.queue_free()
	paredes.clear()
	saida_pos = Vector2i(-1, -1)
	
	# Escolhe layout — após esgotar os fixos, gera aleatório
	var layout = []
	if indice < layouts.size():
		layout = layouts[indice]
	else:
		layout = _gerar_layout_aleatorio()
	
	_construir_sala(layout)

func _construir_sala(layout: Array):
	for y in range(layout.size()):
		var linha = layout[y]
		for x in range(linha.length()):
			var cel = linha[x]
			var pos_pixel = Vector2(x, y) * TAMANHO_CELULA
			
			if cel == "#":
				_criar_parede(pos_pixel, Vector2i(x, y))
			elif cel == "E":
				saida_pos = Vector2i(x, y)
				_criar_saida(pos_pixel)

func _criar_parede(pos_pixel: Vector2, grid_pos: Vector2i):
	paredes.append(grid_pos)
	var parede = ColorRect.new()
	parede.size = Vector2(TAMANHO_CELULA, TAMANHO_CELULA)
	parede.position = pos_pixel
	parede.color = Color(0.3, 0.3, 0.35)
	add_child(parede)

func _criar_saida(pos_pixel: Vector2):
	var saida = ColorRect.new()
	saida.size = Vector2(TAMANHO_CELULA, TAMANHO_CELULA)
	saida.position = pos_pixel
	saida.color = Color(0.2, 0.8, 0.4) # verde
	add_child(saida)
	
	# Label indicando a saída
	var label = Label.new()
	label.text = "▶"
	label.position = pos_pixel + Vector2(20, 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	add_child(label)

func eh_parede(grid_pos: Vector2i) -> bool:
	return grid_pos in paredes

func checar_saida(grid_pos: Vector2i) -> bool:
	return grid_pos == saida_pos

# Geração procedural simples para salas além das fixas
func _gerar_layout_aleatorio() -> Array:
	var layout = []
	var linhas = 7
	var colunas = 9
	
	for y in range(linhas):
		var linha = ""
		for x in range(colunas):
			# Bordas sempre são paredes
			if x == 0 or x == colunas - 1 or y == 0 or y == linhas - 1:
				linha += "#"
			else:
				# 20% de chance de ser parede interna
				if randf() < 0.2:
					linha += "#"
				else:
					linha += "."
		layout.append(linha)
	
	# Garante saída em posição aleatória na borda direita
	var saida_y = randi_range(1, linhas - 2)
	var linha_saida = layout[saida_y]
	layout[saida_y] = linha_saida.substr(0, colunas - 2) + "E#"
	
	return layout

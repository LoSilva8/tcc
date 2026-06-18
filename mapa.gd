extends Node2D

const TAMANHO_CELULA = 64

const FLOOR_A = Color(0.105, 0.12, 0.13)
const FLOOR_B = Color(0.125, 0.145, 0.155)
const GRID = Color(0.26, 0.36, 0.38, 0.32)
const WALL = Color(0.17, 0.2, 0.23)
const WALL_DARK = Color(0.07, 0.08, 0.095)
const WALL_LIGHT = Color(0.39, 0.48, 0.5, 0.5)
const EXIT = Color(0.18, 0.78, 0.44)
const EXIT_GLOW = Color(0.34, 1.0, 0.62, 0.55)

var paredes: Array = []
var saida_pos: Vector2i = Vector2i(-1, -1)
var sala_atual: int = 0
var layout_atual: Array = []

signal jogador_na_saida

var layouts = [
	[
		"#########",
		"#.......#",
		"#.......#",
		"#.......#",
		"#.......#",
		"#......E#",
		"#########",
	],
	[
		"#########",
		"#.......#",
		"#.###...#",
		"#...#...#",
		"#...#.E.#",
		"#.......#",
		"#########",
	],
	[
		"#########",
		"#...#...#",
		"#...#...#",
		"#.......#",
		"###.###.#",
		"#.....E.#",
		"#########",
	],
	[
		"#########",
		"#.......#",
		"#.#####.#",
		"#.#.E.#.#",
		"#.#...#.#",
		"#.......#",
		"#########",
	],
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
	z_index = -10
	carregar_sala(0)

func carregar_sala(indice: int):
	sala_atual = indice
	
	for filho in get_children():
		filho.queue_free()
	paredes.clear()
	saida_pos = Vector2i(-1, -1)
	
	var layout = []
	if indice < layouts.size():
		layout = layouts[indice]
	else:
		layout = _gerar_layout_aleatorio()
	
	layout_atual = layout
	_construir_sala(layout)
	queue_redraw()

func _construir_sala(layout: Array):
	for y in range(layout.size()):
		var linha = layout[y]
		for x in range(linha.length()):
			var cel = linha.substr(x, 1)
			var pos_pixel = Vector2(x, y) * TAMANHO_CELULA
			
			if cel == "#":
				_criar_parede(pos_pixel, Vector2i(x, y))
			elif cel == "E":
				saida_pos = Vector2i(x, y)
				_criar_saida(pos_pixel)

func _draw():
	if layout_atual.is_empty():
		return
	
	var linhas = layout_atual.size()
	var colunas = layout_atual[0].length()
	var sala_rect = Rect2(Vector2.ZERO, Vector2(colunas, linhas) * TAMANHO_CELULA)
	
	draw_rect(sala_rect.grow(18), Color(0.025, 0.028, 0.036))
	draw_rect(sala_rect.grow(6), Color(0.16, 0.23, 0.25, 0.45), false, 3.0)
	
	for y in range(linhas):
		for x in range(colunas):
			var pos = Vector2(x, y) * TAMANHO_CELULA
			var rect = Rect2(pos, Vector2(TAMANHO_CELULA, TAMANHO_CELULA))
			var cel = layout_atual[y].substr(x, 1)
			
			if cel == "#":
				_desenhar_parede(rect)
			elif cel == "E":
				_desenhar_chao(rect, x, y)
				_desenhar_saida(rect)
			else:
				_desenhar_chao(rect, x, y)
	
	for x in range(colunas + 1):
		var px = x * TAMANHO_CELULA
		draw_line(Vector2(px, 0), Vector2(px, linhas * TAMANHO_CELULA), GRID, 1.0)
	for y in range(linhas + 1):
		var py = y * TAMANHO_CELULA
		draw_line(Vector2(0, py), Vector2(colunas * TAMANHO_CELULA, py), GRID, 1.0)

func _desenhar_chao(rect: Rect2, x: int, y: int):
	var base = FLOOR_A if (x + y) % 2 == 0 else FLOOR_B
	draw_rect(rect, base)
	draw_rect(rect.grow(-8), Color(1, 1, 1, 0.018))
	draw_circle(rect.position + Vector2(14, 14), 2.0, Color(0.42, 0.55, 0.56, 0.18))
	draw_circle(rect.position + Vector2(49, 45), 1.5, Color(0.42, 0.55, 0.56, 0.14))

func _desenhar_parede(rect: Rect2):
	draw_rect(rect, WALL_DARK)
	draw_rect(rect.grow(-4), WALL)
	draw_line(rect.position + Vector2(7, 8), rect.position + Vector2(rect.size.x - 8, 8), WALL_LIGHT, 2.0)
	draw_line(rect.position + Vector2(8, rect.size.y - 8), rect.position + Vector2(rect.size.x - 8, rect.size.y - 8), Color(0, 0, 0, 0.35), 2.0)
	draw_rect(rect.grow(-14), Color(0.11, 0.135, 0.155, 0.42), false, 1.0)

func _desenhar_saida(rect: Rect2):
	var center = rect.position + rect.size / 2
	draw_rect(rect.grow(-5), Color(0.055, 0.18, 0.12))
	draw_circle(center, 24, EXIT_GLOW)
	draw_circle(center, 17, EXIT)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-7, -12),
		center + Vector2(12, 0),
		center + Vector2(-7, 12)
	]), Color(0.92, 1.0, 0.78))
	draw_arc(center, 26, 0.0, TAU, 44, Color(0.72, 1.0, 0.72, 0.8), 2.0)

func _criar_parede(_pos_pixel: Vector2, grid_pos: Vector2i):
	paredes.append(grid_pos)

func _criar_saida(_pos_pixel: Vector2):
	pass

func eh_parede(grid_pos: Vector2i) -> bool:
	return grid_pos in paredes

func checar_saida(grid_pos: Vector2i) -> bool:
	return grid_pos == saida_pos

func _gerar_layout_aleatorio() -> Array:
	var layout = []
	var linhas = 7
	var colunas = 9
	
	for y in range(linhas):
		var linha = ""
		for x in range(colunas):
			if x == 0 or x == colunas - 1 or y == 0 or y == linhas - 1:
				linha += "#"
			else:
				if randf() < 0.2:
					linha += "#"
				else:
					linha += "."
		layout.append(linha)
	
	var saida_y = randi_range(1, linhas - 2)
	var linha_saida = layout[saida_y]
	layout[saida_y] = linha_saida.substr(0, colunas - 2) + "E#"
	
	return layout

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
const FOREST_FLOOR_A = Color(0.11, 0.22, 0.12)
const FOREST_FLOOR_B = Color(0.13, 0.27, 0.15)
const FOREST_WALL = Color(0.08, 0.18, 0.08)
const FOREST_WALL_DARK = Color(0.035, 0.075, 0.04)
const FOREST_WALL_LIGHT = Color(0.3, 0.55, 0.2, 0.5)
const BOSS_SAIDA_AREA_INICIO = Vector2i(9, 3)
const BOSS_SAIDA_AREA_TAMANHO = Vector2i(4, 5)
const BAU_POS = Vector2i(3, 7)
const PORTA_POS = Vector2i(8, 5)
var bau_aberto = false
var porta_aberta = false

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
		"##############",
		"#.......######",
		"#.......######",
		"#.###...#....#",
		"#...#...#....#",
		"#.####.......#",
		"#.#.....#....#",
		"#.#..#..#...E#",
		"##############",
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
	bau_aberto = false
	porta_aberta = false
	
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
	
	if _eh_floresta():
		draw_rect(sala_rect.grow(18), Color(0.025, 0.06, 0.03))
		draw_rect(sala_rect.grow(6), Color(0.2, 0.42, 0.16, 0.45), false, 3.0)
	else:
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
	
	if _eh_floresta():
		_desenhar_area_boss_saida()
		_desenhar_desafios()
	
	for x in range(colunas + 1):
		var px = x * TAMANHO_CELULA
		draw_line(Vector2(px, 0), Vector2(px, linhas * TAMANHO_CELULA), GRID, 1.0)
	for y in range(linhas + 1):
		var py = y * TAMANHO_CELULA
		draw_line(Vector2(0, py), Vector2(colunas * TAMANHO_CELULA, py), GRID, 1.0)

func _desenhar_chao(rect: Rect2, x: int, y: int):
	var base = FLOOR_A if (x + y) % 2 == 0 else FLOOR_B
	if _eh_floresta():
		base = FOREST_FLOOR_A if (x + y) % 2 == 0 else FOREST_FLOOR_B
	draw_rect(rect, base)
	draw_rect(rect.grow(-8), Color(1, 1, 1, 0.018))
	if _eh_floresta():
		draw_circle(rect.position + Vector2(14, 14), 2.2, Color(0.55, 0.8, 0.24, 0.28))
		draw_circle(rect.position + Vector2(49, 45), 1.7, Color(0.75, 0.55, 0.22, 0.2))
		_desenhar_detalhe_floresta(rect, x, y)
	else:
		draw_circle(rect.position + Vector2(14, 14), 2.0, Color(0.42, 0.55, 0.56, 0.18))
		draw_circle(rect.position + Vector2(49, 45), 1.5, Color(0.42, 0.55, 0.56, 0.14))

func _desenhar_parede(rect: Rect2):
	var parede_escura = FOREST_WALL_DARK if _eh_floresta() else WALL_DARK
	var parede = FOREST_WALL if _eh_floresta() else WALL
	var brilho = FOREST_WALL_LIGHT if _eh_floresta() else WALL_LIGHT
	draw_rect(rect, parede_escura)
	draw_rect(rect.grow(-4), parede)
	draw_line(rect.position + Vector2(7, 8), rect.position + Vector2(rect.size.x - 8, 8), brilho, 2.0)
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

func _desenhar_detalhe_floresta(rect: Rect2, x: int, y: int):
	var detalhe = _tile_hash(x, y, 1) % 100
	var centro = rect.position + Vector2(10 + (_tile_hash(x, y, 2) % 45), 10 + (_tile_hash(x, y, 3) % 43))
	
	if detalhe < 14:
		var petala = Color(0.98, 0.72, 0.42, 0.58)
		draw_circle(centro + Vector2(-2, 0), 1.8, petala)
		draw_circle(centro + Vector2(2, 0), 1.8, petala)
		draw_circle(centro + Vector2(0, -2), 1.8, petala)
		draw_circle(centro + Vector2(0, 2), 1.8, petala)
		draw_circle(centro, 1.2, Color(1.0, 0.92, 0.42, 0.78))
	elif detalhe < 32:
		var raiz = centro + Vector2(-4, 6)
		draw_line(raiz, raiz + Vector2(3, -8), Color(0.42, 0.78, 0.25, 0.42), 1.5)
		draw_line(raiz + Vector2(5, 0), raiz + Vector2(9, -7), Color(0.52, 0.9, 0.3, 0.36), 1.5)
		draw_line(raiz + Vector2(-3, 1), raiz + Vector2(-7, -5), Color(0.32, 0.65, 0.23, 0.34), 1.5)
	elif detalhe < 43:
		draw_circle(centro, 3.2, Color(0.06, 0.11, 0.08, 0.46))
		draw_circle(centro + Vector2(1, -1), 1.6, Color(0.28, 0.36, 0.23, 0.42))

func _tile_hash(x: int, y: int, salt: int) -> int:
	return abs(x * 928371 + y * 689287 + salt * 283923)

func _desenhar_area_boss_saida():
	var area_rect = Rect2(
		Vector2(BOSS_SAIDA_AREA_INICIO) * TAMANHO_CELULA,
		Vector2(BOSS_SAIDA_AREA_TAMANHO) * TAMANHO_CELULA
	)
	
	for y in range(BOSS_SAIDA_AREA_INICIO.y, BOSS_SAIDA_AREA_INICIO.y + BOSS_SAIDA_AREA_TAMANHO.y):
		for x in range(BOSS_SAIDA_AREA_INICIO.x, BOSS_SAIDA_AREA_INICIO.x + BOSS_SAIDA_AREA_TAMANHO.x):
			var pos = Vector2i(x, y)
			if not posicao_valida(pos) and pos != saida_pos:
				continue
			
			var tile_rect = Rect2(Vector2(pos) * TAMANHO_CELULA, Vector2(TAMANHO_CELULA, TAMANHO_CELULA))
			draw_rect(tile_rect.grow(-5), Color(0.92, 0.52, 0.18, 0.14))
			draw_rect(tile_rect.grow(-12), Color(1.0, 0.82, 0.36, 0.05), false, 1.0)
	
	draw_rect(area_rect.grow(-5), Color(1.0, 0.62, 0.22, 0.82), false, 3.0)
	draw_rect(area_rect.grow(-10), Color(0.72, 1.0, 0.42, 0.32), false, 1.5)

func _criar_parede(_pos_pixel: Vector2, grid_pos: Vector2i):
	paredes.append(grid_pos)

func _criar_saida(_pos_pixel: Vector2):
	pass

func eh_parede(grid_pos: Vector2i) -> bool:
	if sala_atual == 1 and (grid_pos == BAU_POS or (grid_pos == PORTA_POS and not porta_aberta)):
		return true
	return grid_pos in paredes

func _desenhar_desafios():
	var b = Vector2(BAU_POS) * TAMANHO_CELULA
	draw_rect(Rect2(b + Vector2(9, 23), Vector2(46, 31)), Color("81542d"))
	draw_rect(Rect2(b + Vector2(8, 14 if bau_aberto else 21), Vector2(48, 12)), Color("d4a94e"))
	for x in [18, 30, 42]:
		draw_circle(b + Vector2(x, 40), 3, Color("ffe699"))
	draw_string(ThemeDB.fallback_font, b + Vector2(4, 12), "BAU", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	var p = Vector2(PORTA_POS) * TAMANHO_CELULA
	draw_rect(Rect2(p + Vector2(4, 2), Vector2(56, 60)), Color("83999a"), false, 4)
	if not porta_aberta:
		draw_rect(Rect2(p + Vector2(9, 5), Vector2(46, 56)), Color("354b62"))
		draw_circle(p + Vector2(36, 33), 6, Color("f3ce68"))
	draw_string(ThemeDB.fallback_font, p + Vector2(4, 17), "PORTA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func posicao_valida(grid_pos: Vector2i) -> bool:
	if layout_atual.is_empty():
		return false
	if grid_pos.y < 0 or grid_pos.y >= layout_atual.size():
		return false
	if grid_pos.x < 0 or grid_pos.x >= layout_atual[grid_pos.y].length():
		return false
	return not eh_parede(grid_pos)

func checar_saida(grid_pos: Vector2i) -> bool:
	return grid_pos == saida_pos

func _eh_floresta() -> bool:
	return sala_atual == 1

func area_boss_saida_inicio() -> Vector2i:
	return BOSS_SAIDA_AREA_INICIO

func area_boss_saida_tamanho() -> Vector2i:
	return BOSS_SAIDA_AREA_TAMANHO

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

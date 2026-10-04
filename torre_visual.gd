extends Node2D

# Visual das criaturas da Torre das Funcoes (mesmo padrao de _draw() dos outros inimigos).

@export var tipo: String = "sentinela"

var progresso: float = 1.0

func _ready():
	queue_redraw()

func definir_progresso(valor: float):
	progresso = clampf(valor, 0.0, 1.0)
	queue_redraw()

func _draw():
	_desenhar_sentinela()

# Obelisco de pedra com a runa "def" acesa; rachaduras aparecem a cada golpe.
func _desenhar_sentinela():
	draw_circle(Vector2(0, 20), 18, Color(0.02, 0.02, 0.04, 0.45))
	var corpo = PackedVector2Array([Vector2(-14, 22), Vector2(-11, -20), Vector2(0, -28), Vector2(11, -20), Vector2(14, 22)])
	draw_colored_polygon(corpo, Color(0.2, 0.24, 0.36))
	draw_polyline(corpo + PackedVector2Array([corpo[0]]), Color(0.42, 0.85, 1.0, 0.55), 1.5)
	draw_rect(Rect2(Vector2(-9, -6), Vector2(18, 14)), Color(0.08, 0.1, 0.16))
	var brilho = Color(0.45, 0.92, 1.0, 0.35 + 0.6 * progresso)
	draw_string(ThemeDB.fallback_font, Vector2(-9, 5), "def", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, brilho)
	if progresso < 1.0:
		draw_polyline(PackedVector2Array([Vector2(-8, -18), Vector2(-2, -10), Vector2(-6, -2), Vector2(1, 8)]), Color(0.02, 0.02, 0.03, 0.9), 2.0)
	if progresso < 0.5:
		draw_polyline(PackedVector2Array([Vector2(9, -14), Vector2(4, -4), Vector2(9, 6), Vector2(5, 18)]), Color(0.02, 0.02, 0.03, 0.9), 2.0)

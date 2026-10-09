extends Node2D

# Visual das criaturas da Torre das Funcoes (mesmo padrao de _draw() dos outros inimigos).

@export var tipo: String = "sentinela"

var progresso: float = 1.0
var runa: String = "def"

func _ready():
	queue_redraw()

func definir_progresso(valor: float):
	progresso = clampf(valor, 0.0, 1.0)
	queue_redraw()

func _draw():
	if tipo == "arquimago":
		_desenhar_arquimago()
	else:
		_desenhar_sentinela()

# Mago de manto roxo com coroa e cajado; a aura de corrupcao encolhe com os selos.
func _desenhar_arquimago():
	draw_circle(Vector2(0, 22), 22, Color(0.03, 0.01, 0.04, 0.5))
	draw_circle(Vector2.ZERO, 18 + 12 * progresso, Color(0.6, 0.1, 0.45, 0.18 + 0.2 * progresso))
	var manto = PackedVector2Array([Vector2(-16, 24), Vector2(-9, -6), Vector2(0, -12), Vector2(9, -6), Vector2(16, 24)])
	draw_colored_polygon(manto, Color(0.32, 0.1, 0.38))
	draw_polyline(manto + PackedVector2Array([manto[0]]), Color(0.95, 0.45, 0.85, 0.7), 1.5)
	draw_circle(Vector2(0, -16), 8, Color(0.82, 0.74, 0.86))
	draw_circle(Vector2(-3, -17), 1.6, Color(1.0, 0.2, 0.45))
	draw_circle(Vector2(3, -17), 1.6, Color(1.0, 0.2, 0.45))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -22), Vector2(-6, -30), Vector2(-2, -24), Vector2(0, -32), Vector2(2, -24), Vector2(6, -30), Vector2(8, -22)]), Color(0.95, 0.75, 0.3))
	draw_line(Vector2(18, -26), Vector2(18, 24), Color(0.45, 0.3, 0.2), 3.0)
	draw_circle(Vector2(18, -28), 5, Color(0.95, 0.3, 0.75, 0.9))

# Obelisco de pedra com a runa "def" acesa; rachaduras aparecem a cada golpe.
func _desenhar_sentinela():
	draw_circle(Vector2(0, 20), 18, Color(0.02, 0.02, 0.04, 0.45))
	var corpo = PackedVector2Array([Vector2(-14, 22), Vector2(-11, -20), Vector2(0, -28), Vector2(11, -20), Vector2(14, 22)])
	draw_colored_polygon(corpo, Color(0.2, 0.24, 0.36))
	draw_polyline(corpo + PackedVector2Array([corpo[0]]), Color(0.42, 0.85, 1.0, 0.55), 1.5)
	var fonte = ThemeDB.fallback_font
	var largura = fonte.get_string_size(runa, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_rect(Rect2(Vector2(-largura / 2 - 2, -6), Vector2(largura + 4, 14)), Color(0.08, 0.1, 0.16))
	var brilho = Color(0.45, 0.92, 1.0, 0.35 + 0.6 * progresso)
	draw_string(fonte, Vector2(-largura / 2, 5), runa, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, brilho)
	if progresso < 1.0:
		draw_polyline(PackedVector2Array([Vector2(-8, -18), Vector2(-2, -10), Vector2(-6, -2), Vector2(1, 8)]), Color(0.02, 0.02, 0.03, 0.9), 2.0)
	if progresso < 0.5:
		draw_polyline(PackedVector2Array([Vector2(9, -14), Vector2(4, -4), Vector2(9, 6), Vector2(5, 18)]), Color(0.02, 0.02, 0.03, 0.9), 2.0)

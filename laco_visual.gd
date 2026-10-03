extends Node2D

# Visual das criaturas do Labirinto dos Lacos (mesmo padrao de _draw() dos outros inimigos).

@export var tipo: String = "elo"

var progresso: float = 1.0

func _ready():
	queue_redraw()

func definir_progresso(valor: float):
	progresso = clampf(valor, 0.0, 1.0)
	queue_redraw()

func _draw():
	if tipo == "elo":
		_desenhar_elo()
	else:
		_desenhar_ouroboros()

func _desenhar_elo():
	draw_circle(Vector2(0, 7), 17, Color(0.02, 0.02, 0.02, 0.45))
	draw_arc(Vector2(-7, 0), 13, 0.0, TAU, 32, Color(0.5, 0.4, 0.2), 7.0)
	draw_arc(Vector2(7, 0), 13, 0.0, TAU, 32, Color(0.86, 0.7, 0.36), 7.0)
	draw_arc(Vector2(7, 0), 13, -2.2, -0.6, 12, Color(1.0, 0.94, 0.66, 0.8), 2.0)
	draw_arc(Vector2(-7, 0), 13, 0.6, 1.6, 10, Color(0.86, 0.7, 0.36), 7.0)

func _desenhar_ouroboros():
	var raio = 25.0
	draw_circle(Vector2(0, 8), 29, Color(0.02, 0.03, 0.02, 0.45))
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 64, Color(0.18, 0.3, 0.2, 0.45), 11.0)
	var fim = -PI / 2 + TAU * progresso
	draw_arc(Vector2.ZERO, raio, -PI / 2, fim, 64, Color(0.3, 0.72, 0.4), 11.0)
	draw_arc(Vector2.ZERO, raio + 3, -PI / 2, fim, 64, Color(0.75, 1.0, 0.62, 0.55), 2.0)
	for i in range(8):
		var a = -PI / 2 + TAU * (i + 0.5) / 8.0
		if a <= fim:
			draw_circle(Vector2(cos(a), sin(a)) * raio, 2.2, Color(0.95, 0.85, 0.35, 0.8))
	var cabeca = Vector2(0, -raio)
	draw_colored_polygon(PackedVector2Array([cabeca + Vector2(-11, 4), cabeca + Vector2(0, -12), cabeca + Vector2(11, 4), cabeca + Vector2(0, 9)]), Color(0.24, 0.6, 0.32))
	draw_circle(cabeca + Vector2(-4, -1), 2.4, Color(1.0, 0.82, 0.25))
	draw_circle(cabeca + Vector2(4, -1), 2.4, Color(1.0, 0.82, 0.25))

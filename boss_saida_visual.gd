extends Node2D

func _ready():
	queue_redraw()

func _draw():
	draw_circle(Vector2(0, 6), 25, Color(0.025, 0.02, 0.015, 0.48))
	_desenhar_braco(-1)
	_desenhar_braco(1)
	draw_circle(Vector2(0, 0), 24, Color(0.34, 0.18, 0.08))
	draw_arc(Vector2(0, 0), 25, 0.0, TAU, 48, Color(1.0, 0.64, 0.22, 0.88), 3.0)
	draw_arc(Vector2(0, 0), 17, 0.25, TAU - 0.25, 42, Color(0.72, 0.95, 0.48, 0.45), 2.0)
	
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, -11),
		Vector2(-10, -29),
		Vector2(-2, -12)
	]), Color(0.74, 0.34, 0.12))
	draw_colored_polygon(PackedVector2Array([
		Vector2(17, -11),
		Vector2(10, -29),
		Vector2(2, -12)
	]), Color(0.74, 0.34, 0.12))
	
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -21),
		Vector2(-6, -33),
		Vector2(0, -22),
		Vector2(6, -33),
		Vector2(13, -21)
	]), Color(1.0, 0.75, 0.28))
	draw_polyline(PackedVector2Array([
		Vector2(-13, -21),
		Vector2(-6, -33),
		Vector2(0, -22),
		Vector2(6, -33),
		Vector2(13, -21)
	]), Color(1.0, 0.94, 0.5), 2.0)
	
	draw_circle(Vector2(-8, -4), 3.0, Color(1.0, 0.84, 0.32))
	draw_circle(Vector2(8, -4), 3.0, Color(1.0, 0.84, 0.32))
	draw_line(Vector2(-10, 10), Vector2(10, 10), Color(0.09, 0.035, 0.02), 3.0)

func _desenhar_braco(lado: float):
	var ombro = Vector2(20 * lado, 3)
	var cotovelo = Vector2(29 * lado, 9)
	var mao = Vector2(31 * lado, 19)
	var contorno = Color(0.18, 0.09, 0.04)
	var pele = Color(0.52, 0.29, 0.12)
	var pontos = PackedVector2Array([ombro, cotovelo, mao])
	draw_polyline(pontos, contorno, 12.0, true)
	draw_polyline(pontos, pele, 8.0, true)
	draw_circle(cotovelo, 4.0, pele)
	draw_line(cotovelo + Vector2(-4, 4), cotovelo + Vector2(4, 4), Color(1.0, 0.7, 0.25), 3.0, true)
	draw_circle(mao, 7.0, contorno)
	draw_circle(mao, 5.5, pele)
	draw_circle(mao + Vector2(-3 * lado, -2), 2.5, Color(0.7, 0.4, 0.17))
	for dedo in [-2, 1]:
		draw_line(mao + Vector2(dedo, 2), mao + Vector2(dedo, 5), contorno, 1.0, true)

extends Node2D

func _ready():
	queue_redraw()

func _draw():
	draw_circle(Vector2(0, 5), 23, Color(0.04, 0.03, 0.055, 0.48))
	draw_circle(Vector2(0, 0), 24, Color(0.38, 0.16, 0.66))
	draw_arc(Vector2(0, 0), 27, 0, TAU, 48, Color(0.96, 0.62, 1.0, 0.9), 3)
	draw_arc(Vector2(0, 0), 18, 0.35, TAU - 0.35, 42, Color(0.35, 0.9, 1.0, 0.72), 2)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -16),
		Vector2(15, -6),
		Vector2(10, 14),
		Vector2(0, 21),
		Vector2(-10, 14),
		Vector2(-15, -6)
	]), Color(0.18, 0.72, 0.95, 0.36))
	draw_polyline(PackedVector2Array([
		Vector2(0, -16),
		Vector2(15, -6),
		Vector2(10, 14),
		Vector2(0, 21),
		Vector2(-10, 14),
		Vector2(-15, -6),
		Vector2(0, -16)
	]), Color(0.78, 0.96, 1.0), 2.0)
	draw_circle(Vector2(-7, -4), 3, Color(1.0, 0.88, 0.36))
	draw_circle(Vector2(7, -4), 3, Color(1.0, 0.88, 0.36))

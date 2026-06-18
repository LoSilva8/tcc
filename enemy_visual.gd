extends Node2D

func _ready():
	queue_redraw()

func _draw():
	draw_circle(Vector2(0, 5), 21, Color(0.04, 0.03, 0.035, 0.48))
	draw_circle(Vector2(0, 0), 22, Color(0.62, 0.09, 0.14))
	draw_arc(Vector2(0, 0), 22, 0, TAU, 36, Color(1.0, 0.36, 0.33), 3)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, -8),
		Vector2(-9, -28),
		Vector2(-2, -10)
	]), Color(0.88, 0.25, 0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(18, -8),
		Vector2(9, -28),
		Vector2(2, -10)
	]), Color(0.88, 0.25, 0.2))
	draw_circle(Vector2(-7, -4), 3, Color(1.0, 0.86, 0.32))
	draw_circle(Vector2(7, -4), 3, Color(1.0, 0.86, 0.32))
	draw_line(Vector2(-9, 9), Vector2(9, 9), Color(0.12, 0.02, 0.03), 3)

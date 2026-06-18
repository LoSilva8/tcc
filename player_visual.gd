extends Node2D

func _ready():
	queue_redraw()

func _draw():
	draw_circle(Vector2(0, 3), 18, Color(0.04, 0.05, 0.065, 0.55))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, 15),
		Vector2(-10, -5),
		Vector2(0, -16),
		Vector2(10, -5),
		Vector2(18, 15)
	]), Color(0.18, 0.78, 0.88))
	draw_polyline(PackedVector2Array([
		Vector2(-18, 15),
		Vector2(-10, -5),
		Vector2(0, -16),
		Vector2(10, -5),
		Vector2(18, 15),
		Vector2(-18, 15)
	]), Color(0.78, 0.98, 1.0), 2.0)
	draw_circle(Vector2(0, 0), 10, Color(0.95, 0.88, 0.62))
	draw_circle(Vector2(-4, -2), 1.5, Color(0.06, 0.08, 0.1))
	draw_circle(Vector2(4, -2), 1.5, Color(0.06, 0.08, 0.1))
	draw_arc(Vector2(0, 2), 4, 0.25, 2.9, 12, Color(0.08, 0.1, 0.12), 1.5)
	draw_line(Vector2(-13, 18), Vector2(-7, 8), Color(0.04, 0.05, 0.065), 3)
	draw_line(Vector2(13, 18), Vector2(7, 8), Color(0.04, 0.05, 0.065), 3)
	draw_circle(Vector2(0, -19), 4, Color(1.0, 0.85, 0.26))

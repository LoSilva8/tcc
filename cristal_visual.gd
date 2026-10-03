extends Node2D

# Visual das criaturas de cristal das Cavernas Condicionais.
# Mesmo padrao de enemy_visual.gd / boss_saida_visual.gd: desenho via _draw().

@export var escala: float = 1.0
@export var chefe: bool = false

var cor: Color = Color(0.58, 0.38, 0.92)

func _ready():
	queue_redraw()

func definir_cor(nova_cor: Color):
	cor = nova_cor
	queue_redraw()

func _draw():
	var e = escala
	var escura = cor.darkened(0.5)
	var clara = cor.lightened(0.45)
	draw_circle(Vector2(0, 7) * e, 19 * e, Color(0.03, 0.02, 0.05, 0.5))

	if chefe:
		draw_arc(Vector2.ZERO, 31 * e, 0.0, TAU, 48, Color(clara, 0.5), 2.0)
		# Os dois "ramos" do Oraculo Bifurcado
		for lado in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([
				Vector2(6 * lado, -14) * e,
				Vector2(21 * lado, -37) * e,
				Vector2(17 * lado, -9) * e
			]), escura)
			draw_line(Vector2(6 * lado, -14) * e, Vector2(21 * lado, -37) * e, clara, 2.0)

	var topo = Vector2(0, -25) * e
	var direita = Vector2(18, -2) * e
	var base = Vector2(0, 22) * e
	var esquerda = Vector2(-18, -2) * e
	var centro = Vector2(0, -2) * e

	draw_colored_polygon(PackedVector2Array([topo, direita, base, esquerda]), escura)
	draw_colored_polygon(PackedVector2Array([topo, centro, esquerda]), cor)
	draw_colored_polygon(PackedVector2Array([topo, direita, centro]), clara)
	draw_colored_polygon(PackedVector2Array([esquerda, centro, base]), cor.darkened(0.2))
	draw_polyline(PackedVector2Array([topo, direita, base, esquerda, topo]), clara, 2.0)

	draw_circle(Vector2(-6, 3) * e, 2.8 * e, Color(1.0, 0.96, 0.82))
	draw_circle(Vector2(6, 3) * e, 2.8 * e, Color(1.0, 0.96, 0.82))
	draw_circle(Vector2(-6, 3) * e, 1.2 * e, Color(0.08, 0.04, 0.12))
	draw_circle(Vector2(6, 3) * e, 1.2 * e, Color(0.08, 0.04, 0.12))

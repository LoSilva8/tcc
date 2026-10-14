extends Node2D

# Visual do Guardiao de Runas (chefe da Floresta): golem de raizes com tres runas.
# Mao esquerda = runa do numero, mao direita = runa da palavra, peito = Nucleo.
# A runa da vez brilha; as quebradas ficam apagadas; as seguintes, adormecidas.

const COR_PEDRA = Color(1.0, 0.7, 0.25)
const COR_CRISTAL = Color(0.45, 0.85, 1.0)
const COR_NUCLEO = Color(0.62, 1.0, 0.45)

# Indice da runa da vez (0 = pedra, 1 = cristal, 2 = nucleo, 3 = todas quebradas).
var estado: int = 0

func _ready():
	queue_redraw()

func definir_estado(indice: int):
	estado = indice
	queue_redraw()

func _draw():
	draw_circle(Vector2(0, 6), 25, Color(0.025, 0.02, 0.015, 0.48))
	_desenhar_raizes()
	_desenhar_braco(-1)
	_desenhar_braco(1)
	draw_circle(Vector2(0, 0), 24, Color(0.3, 0.2, 0.1))
	draw_arc(Vector2(0, 0), 25, 0.0, TAU, 48, Color(0.62, 0.86, 0.38, 0.85), 3.0)

	# Coroa de galhos
	draw_polyline(PackedVector2Array([
		Vector2(-13, -21), Vector2(-9, -33), Vector2(-4, -24),
		Vector2(0, -35), Vector2(4, -24), Vector2(9, -33), Vector2(13, -21)
	]), Color(0.45, 0.3, 0.14), 4.0, true)
	draw_circle(Vector2(-9, -33), 3.0, Color(0.5, 0.85, 0.35))
	draw_circle(Vector2(9, -33), 3.0, Color(0.5, 0.85, 0.35))

	draw_circle(Vector2(-8, -9), 3.0, Color(1.0, 0.86, 0.4))
	draw_circle(Vector2(8, -9), 3.0, Color(1.0, 0.86, 0.4))

	_desenhar_runa(Vector2(-31, 19), 0, COR_PEDRA)
	_desenhar_runa(Vector2(31, 19), 1, COR_CRISTAL)
	_desenhar_runa(Vector2(0, 7), 2, COR_NUCLEO)

func _desenhar_raizes():
	var raiz = Color(0.32, 0.2, 0.09, 0.85)
	for lado in [-1, 1]:
		draw_polyline(PackedVector2Array([
			Vector2(8 * lado, 20), Vector2(16 * lado, 27), Vector2(27 * lado, 29)
		]), raiz, 3.0, true)
		draw_polyline(PackedVector2Array([
			Vector2(3 * lado, 22), Vector2(6 * lado, 30)
		]), raiz, 2.0, true)

func _desenhar_braco(lado: float):
	var ombro = Vector2(20 * lado, 3)
	var cotovelo = Vector2(29 * lado, 9)
	var mao = Vector2(31 * lado, 19)
	var pontos = PackedVector2Array([ombro, cotovelo, mao])
	draw_polyline(pontos, Color(0.16, 0.1, 0.04), 12.0, true)
	draw_polyline(pontos, Color(0.46, 0.3, 0.13), 8.0, true)
	draw_circle(cotovelo, 4.0, Color(0.46, 0.3, 0.13))

# Runa: circulo com um traco. Brilha se for a da vez, apaga se ja quebrou.
func _desenhar_runa(centro: Vector2, indice: int, cor: Color):
	var raio = 8.0 if indice == 2 else 7.0
	if indice < estado:
		draw_circle(centro, raio, Color(0.12, 0.1, 0.08))
		draw_line(centro + Vector2(-raio, -raio) * 0.6, centro + Vector2(raio, raio) * 0.6, Color(0.35, 0.3, 0.25), 2.0)
		return
	var ativa = indice == estado
	var preenchimento = cor if ativa else cor.darkened(0.6)
	if ativa:
		draw_circle(centro, raio + 4.0, Color(cor, 0.25))
	draw_circle(centro, raio, preenchimento)
	draw_arc(centro, raio, 0.0, TAU, 24, cor.lightened(0.4) if ativa else cor.darkened(0.3), 1.5)
	draw_line(centro + Vector2(0, -raio * 0.6), centro + Vector2(0, raio * 0.6), Color(0.1, 0.06, 0.03), 2.0)
	draw_line(centro + Vector2(-raio * 0.45, 0), centro + Vector2(raio * 0.45, -raio * 0.35), Color(0.1, 0.06, 0.03), 2.0)

extends Node2D

# Elo da corrente do Labirinto: passivo (so bloqueia o corredor) e so se parte
# com golpes executados DENTRO de um laco (for ou while).

const TAMANHO_CELULA = 64

var grid_pos: Vector2i = Vector2i(0, 0)
var hp: int = 1
var vivo: bool = true
var xp_gerado: int = 0

@onready var hp_label = $HPLabel

func inicializar(pos: Vector2i):
	grid_pos = pos
	call_deferred("_aplicar_posicao")

func _aplicar_posicao():
	position = Vector2(grid_pos) * TAMANHO_CELULA + Vector2(TAMANHO_CELULA / 2, TAMANHO_CELULA / 2)

func pode_ocupar(pos: Vector2i) -> bool:
	return pos == grid_pos

func pode_agir_contra(_pos_jogador: Vector2i) -> bool:
	return false

func receber_dano(_dano: int, em_laco: bool) -> String:
	if not vivo:
		return "Esse elo ja se partiu."
	if not em_laco:
		return "O Elo absorveu o golpe solto. Elos so se partem com golpes repetidos por um laco (for ou while)."
	hp = 0
	vivo = false
	xp_gerado = 2
	if hp_label:
		hp_label.text = ""
	_morrer()
	return "Elo partido! (+2 XP)"

func _morrer():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

extends Node2D

const TAMANHO_CELULA = 64

var grid_pos: Vector2i = Vector2i(0, 0)
var hp: int = 3
var hp_max: int = 3
var vivo: bool = true

@onready var hp_label = $HPLabel

func inicializar(pos: Vector2i):
	grid_pos = pos
	position = Vector2(grid_pos) * TAMANHO_CELULA + Vector2(TAMANHO_CELULA / 2, TAMANHO_CELULA / 2)
	_atualizar_hp()

func receber_dano(dano: int) -> String:
	if not vivo:
		return "O inimigo já está derrotado!"
	
	hp -= dano
	_atualizar_hp()
	
	if hp <= 0:
		vivo = false
		_morrer()
		return "Inimigo derrotado! ⚔️ +" + str(10) + " XP"
	
	return "Inimigo atingido! HP restante: " + str(hp) + "/" + str(hp_max)

func _atualizar_hp():
	if hp_label:
		hp_label.text = "❤ " + str(max(hp, 0)) + "/" + str(hp_max)

func _morrer():
	# Animação simples de morte
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

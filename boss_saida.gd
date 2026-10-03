extends Node2D

const TAMANHO_CELULA = 64

var grid_pos: Vector2i = Vector2i(0, 0)
var hp: int = 6
var hp_max: int = 6
var vivo: bool = true
var xp_gerado: int = 0
var area_inicio: Vector2i = Vector2i(9, 5)
var area_tamanho: Vector2i = Vector2i(3, 3)

@onready var hp_label = $HPLabel
@onready var area_label = $AreaLabel

func inicializar(pos: Vector2i, inicio: Vector2i, tamanho: Vector2i):
	grid_pos = pos
	area_inicio = inicio
	area_tamanho = tamanho
	position = _grid_para_pixel(grid_pos)
	_atualizar_labels()

func eh_boss_saida() -> bool:
	return true

func pode_ocupar(pos: Vector2i) -> bool:
	return _pos_na_area(pos)

func pode_agir_contra(pos_player: Vector2i) -> bool:
	return _pos_na_area(pos_player)

func pode_ser_atacado_por(pos_player: Vector2i) -> bool:
	return _pos_na_area(pos_player)

func mensagem_fora_da_area() -> String:
	return "O Guardiao da Saida esta protegido pela arena.\nEntre na area marcada perto da saida para ataca-lo."

func receber_dano(dano: int) -> String:
	if not vivo:
		return "O Guardiao da Saida ja foi derrotado."
	
	hp -= dano
	hp = max(hp, 0)
	_atualizar_labels()
	
	if hp <= 0:
		vivo = false
		xp_gerado = 8
		_morrer()
		return "Guardiao da Saida derrotado! A saida perdeu a protecao. (+8 XP)"
	
	return "Guardiao da Saida atingido. HP restante: " + str(hp) + "/" + str(hp_max)

func _pos_na_area(pos: Vector2i) -> bool:
	return pos.x >= area_inicio.x \
		and pos.x < area_inicio.x + area_tamanho.x \
		and pos.y >= area_inicio.y \
		and pos.y < area_inicio.y + area_tamanho.y

func _grid_para_pixel(pos: Vector2i) -> Vector2:
	return Vector2(pos) * TAMANHO_CELULA + Vector2(TAMANHO_CELULA / 2, TAMANHO_CELULA / 2)

func _atualizar_labels():
	if hp_label:
		hp_label.text = "BOSS " + str(max(hp, 0)) + "/" + str(hp_max)
	if area_label:
		area_label.text = "ARENA"

func _morrer():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.28, 1.28), 0.16)
	tween.tween_property(self, "modulate:a", 0.0, 0.38)
	tween.tween_callback(queue_free)

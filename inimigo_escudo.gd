extends Node2D

const TAMANHO_CELULA = 64

var grid_pos: Vector2i = Vector2i(0, 0)
var hp: int = 5
var hp_max: int = 5
var vivo: bool = true
var escudo_ativo: bool = true
var xp_gerado: int = 0

@onready var hp_label = $HPLabel
@onready var escudo_label = $EscudoLabel

func inicializar(pos: Vector2i, hp_inicial: int = 5):
	grid_pos = pos
	hp = hp_inicial
	hp_max = hp_inicial
	call_deferred("_aplicar_posicao")

func _aplicar_posicao():
	position = Vector2(
		grid_pos.x * TAMANHO_CELULA + TAMANHO_CELULA / 2,
		grid_pos.y * TAMANHO_CELULA + TAMANHO_CELULA / 2
	)
	_atualizar_hp()

func receber_dano(dano: int, usando_variavel: bool) -> String:
	if not vivo:
		return "O inimigo ja foi derrotado!"
	
	if escudo_ativo and not usando_variavel:
		return "O escudo magico bloqueou o ataque!\nEste inimigo so pode ser ferido com magia variavel.\nDica: defina golpes = 5 e use atacar_com(golpes, 'direcao')"
	
	if escudo_ativo and usando_variavel:
		escudo_ativo = false
		escudo_label.text = ""
	
	hp -= dano
	hp = max(hp, 0)
	_atualizar_hp()
	
	if hp <= 0:
		vivo = false
		xp_gerado = 6
		_morrer()
		return "Escudo quebrado e inimigo derrotado! (+6 XP)"
	
	return "Escudo quebrado! Inimigo atingido! HP: " + str(hp) + "/" + str(hp_max)

func _atualizar_hp():
	if hp_label:
		var prefixo = "SHD " if escudo_ativo else "HP "
		hp_label.text = prefixo + str(max(hp, 0)) + "/" + str(hp_max)

func _morrer():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.32)
	tween.tween_callback(queue_free)

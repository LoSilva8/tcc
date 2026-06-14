extends Node2D

const TAMANHO_CELULA = 64

var grid_pos: Vector2i = Vector2i(0, 0)
var hp: int = 5
var hp_max: int = 5
var vivo: bool = true
var escudo_ativo: bool = true

@onready var hp_label = $HPLabel
@onready var escudo_label = $EscudoLabel

func inicializar(pos: Vector2i):
	grid_pos = pos
	call_deferred("_aplicar_posicao")

func _aplicar_posicao():
	position = Vector2(
		grid_pos.x * TAMANHO_CELULA + TAMANHO_CELULA / 2,
		grid_pos.y * TAMANHO_CELULA + TAMANHO_CELULA / 2
	)
	print("Parent position:", get_parent().position)
	print("Parent global:", get_parent().global_position)
	print("Minha position:", position)
	print("Minha global:", global_position)

func receber_dano(dano: int, usando_variavel: bool) -> String:
	if not vivo:
		return "O inimigo já foi derrotado!"
	
	# Escudo bloqueia dano normal
	if escudo_ativo and not usando_variavel:
		return "🛡 O escudo mágico bloqueou o ataque!\n   Este inimigo só pode ser ferido com magia variável.\n   Dica: defina 'golpes = 5' e use atacar_com(golpes, 'direção')"
	
	# Quebra o escudo na primeira vez que usa variável
	if escudo_ativo and usando_variavel:
		escudo_ativo = false
		escudo_label.text = ""
		hp_label.modulate = Color(1, 1, 1)
	
	hp -= dano
	hp = max(hp, 0)
	_atualizar_hp()
	
	if hp <= 0:
		vivo = false
		_morrer()
		return "💥 Escudo quebrado e inimigo derrotado!\n   A magia variável funcionou! +20 XP"
	
	return "✨ Escudo quebrado! Inimigo atingido! HP: " + str(hp) + "/" + str(hp_max)

func _atualizar_hp():
	if hp_label:
		var prefixo = "🛡 " if escudo_ativo else "❤ "
		hp_label.text = prefixo + str(max(hp, 0)) + "/" + str(hp_max)

func _morrer():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

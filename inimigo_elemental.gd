extends Node2D

const TAMANHO_CELULA = 64
const ELEMENTOS = ["fogo", "gelo", "arcano"]

var grid_pos: Vector2i = Vector2i(0, 0)
var hp: int = 4
var hp_max: int = 4
var vivo: bool = true
var xp_gerado: int = 0
var elemento_fraqueza: String = "fogo"

@onready var cor_rect = $ColorRect
@onready var hp_label = $HPLabel
@onready var elemento_label = $ElementoLabel
@onready var visual = $Visual

func inicializar(pos: Vector2i, hp_inicial: int = 4, elemento: String = ""):
	grid_pos = pos
	hp = hp_inicial
	hp_max = hp_inicial
	elemento_fraqueza = elemento if elemento in ELEMENTOS else ELEMENTOS[randi() % ELEMENTOS.size()]
	call_deferred("_aplicar_posicao")

func _aplicar_posicao():
	position = Vector2(
		grid_pos.x * TAMANHO_CELULA + TAMANHO_CELULA / 2,
		grid_pos.y * TAMANHO_CELULA + TAMANHO_CELULA / 2
	)
	_atualizar_labels()

# usando_variavel: true quando o ataque veio de fireball(variavel, 'direcao').
# nome_variavel: o nome da variavel usada na fireball.
func receber_dano(dano: int, usando_variavel: bool, nome_variavel: String = "") -> String:
	if not vivo:
		return "O eco ja se dissipou."

	if not usando_variavel:
		return "Ataques comuns atravessam o Eco " + elemento_fraqueza.capitalize() + ".\nObserve a cor dele e use fireball com a variavel do elemento certo."

	if nome_variavel != elemento_fraqueza:
		return "Fireball de '" + nome_variavel + "' nao afeta o Eco " + elemento_fraqueza.capitalize() + ".\nEle so reage ao elemento " + elemento_fraqueza + "."

	hp -= dano
	hp = max(hp, 0)
	_atualizar_labels()

	if hp <= 0:
		vivo = false
		xp_gerado = 7
		_morrer()
		return "Eco " + elemento_fraqueza.capitalize() + " dissipado! (+7 XP)"

	return "Eco atingido! HP: " + str(hp) + "/" + str(hp_max)

func _atualizar_labels():
	if hp_label:
		hp_label.text = "HP " + str(max(hp, 0)) + "/" + str(hp_max)
	if elemento_label:
		elemento_label.text = elemento_fraqueza.capitalize()
	var cor = Color(0.58, 0.38, 0.92, 1)
	match elemento_fraqueza:
		"fogo": cor = Color(0.9, 0.4, 0.18, 1)
		"gelo": cor = Color(0.38, 0.72, 0.95, 1)
	if cor_rect:
		cor_rect.color = cor
	if visual:
		visual.definir_cor(cor)

func _morrer():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

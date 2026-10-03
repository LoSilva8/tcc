extends Node2D

const TAMANHO_CELULA = 64
const SINAIS = ["fogo", "gelo", "arcano"]
const COR_OCULTA = Color(0.82, 0.84, 0.92, 1)

var grid_pos: Vector2i = Vector2i(0, 0)
var vivo: bool = true
var xp_gerado: int = 0

var fases = ["eco_fogo", "eco_gelo", "nucleo_arcano"]
var hp_fases = {"eco_fogo": 4, "eco_gelo": 5, "nucleo_arcano": 6}
var hp_max_fases = {"eco_fogo": 4, "eco_gelo": 5, "nucleo_arcano": 6}
var fase_index = 0
var sinal_atual: String = "fogo"

signal chefe_derrotado

@onready var nucleo_rect = $NucleoRect
@onready var hp_label = $HPLabel
@onready var fase_label = $FaseLabel
@onready var sinal_label = $SinalLabel
@onready var visual = $Visual

func inicializar(pos: Vector2i):
	grid_pos = pos
	_sortear_sinal()
	call_deferred("_aplicar_posicao")

func _aplicar_posicao():
	position = Vector2(
		grid_pos.x * TAMANHO_CELULA + TAMANHO_CELULA / 2,
		grid_pos.y * TAMANHO_CELULA + TAMANHO_CELULA / 2
	)
	_atualizar_labels()

# O Oraculo esta preso ao cristal: nunca sai da propria casa.
# (gerenciador_inimigos consulta pode_ocupar no pathfinding)
func pode_ocupar(pos: Vector2i) -> bool:
	return pos == grid_pos

func fase_atual() -> String:
	return fases[fase_index]

func _sortear_sinal():
	sinal_atual = SINAIS[randi() % SINAIS.size()]

# nome_variavel: elemento usado na fireball do jogador.
# encadeado: true quando o comando daquele turno veio de uma cadeia
# if/elif/else (ver interpretador.gd -> ultimo_encadeado).
func receber_dano(dano: int, nome_variavel: String, encadeado: bool = false) -> String:
	if not vivo:
		return "O Oraculo ja se calou."

	var fase = fase_atual()
	var exige_encadeado = fase == "nucleo_arcano"

	if nome_variavel != sinal_atual:
		var pista = ""
		if fase != "nucleo_arcano":
			pista = "\nO Oraculo sussurra o elemento " + sinal_atual + "."
		_sortear_sinal()
		_atualizar_labels()
		return "'" + nome_variavel + "' nao e o elemento certo agora." + pista + "\nO sinal mudou."

	if exige_encadeado and not encadeado:
		return "O Nucleo Arcano ignora respostas isoladas.\nResponda com uma unica linha if / elif / else que teste sinal_oraculo e cubra todos os sinais possiveis."

	hp_fases[fase] -= dano
	hp_fases[fase] = max(hp_fases[fase], 0)

	if hp_fases[fase] <= 0:
		var nome_fase = _nome_legivel(fase)
		fase_index += 1

		if fase_index >= fases.size():
			xp_gerado = 20
			vivo = false
			_atualizar_labels()
			_morrer()
			return nome_fase.capitalize() + " silenciado!\nORACULO BIFURCADO DERROTADO! (+20 XP)"

		xp_gerado = 7
		_sortear_sinal()
		_atualizar_labels()
		var aviso = ""
		if fase_atual() == "nucleo_arcano":
			aviso = "\nO Nucleo Arcano acorda e esconde o sinal. Ele agora so existe em sinal_oraculo. Nenhuma dica sera mostrada."
		return nome_fase.capitalize() + " silenciado! (+7 XP)\nUma nova voz desperta: " + _nome_legivel(fase_atual()) + "." + aviso

	_sortear_sinal()
	_atualizar_labels()
	var linha_sinal = "" if fase == "nucleo_arcano" else ("\nO sinal mudou para: " + sinal_atual)
	return _nome_legivel(fase).capitalize() + " atingido! HP: " + str(hp_fases[fase]) + "/" + str(hp_max_fases[fase]) + linha_sinal

func _nome_legivel(fase: String) -> String:
	match fase:
		"eco_fogo": return "eco do fogo"
		"eco_gelo": return "eco do gelo"
		"nucleo_arcano": return "nucleo arcano"
	return fase

func _atualizar_labels():
	if not vivo:
		hp_label.text = ""
		fase_label.text = "DERROTADO"
		sinal_label.text = ""
		return

	var fase = fase_atual()
	hp_label.text = "HP " + str(hp_fases[fase]) + "/" + str(hp_max_fases[fase])
	fase_label.text = _nome_legivel(fase).capitalize()
	sinal_label.text = "???" if fase == "nucleo_arcano" else ("sinal: " + sinal_atual)
	_atualizar_cor()

func _atualizar_cor():
	var cor = COR_OCULTA
	# No Nucleo o sinal e secreto: a cor tambem nao pode denuncia-lo.
	if fase_atual() != "nucleo_arcano":
		match sinal_atual:
			"fogo": cor = Color(0.9, 0.35, 0.15, 1)
			"gelo": cor = Color(0.35, 0.7, 0.95, 1)
			"arcano": cor = Color(0.55, 0.35, 0.9, 1)
	nucleo_rect.color = cor
	if visual:
		visual.definir_cor(cor)

func _morrer():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
	emit_signal("chefe_derrotado")

extends Node2D

# Sentinela Runica da Torre das Funcoes: passiva (so sela a passagem) e so sente
# golpes executados DENTRO de uma funcao do jogador (def). A Sentinela Gemea
# (exige_parametro) so sente funcoes que recebem parametros.

const TAMANHO_CELULA = 64

var grid_pos: Vector2i = Vector2i(0, 0)
var golpes_max: int = 2
var golpes_restantes: int = 2
var exige_parametro: bool = false
var vivo: bool = true
var xp_gerado: int = 0

@onready var hp_label = $HPLabel
@onready var visual = $Visual

func inicializar(pos: Vector2i, golpes: int = 2, com_parametro: bool = false):
	grid_pos = pos
	golpes_max = golpes
	golpes_restantes = golpes
	exige_parametro = com_parametro
	call_deferred("_aplicar_posicao")

func _aplicar_posicao():
	position = Vector2(grid_pos) * TAMANHO_CELULA + Vector2(TAMANHO_CELULA / 2, TAMANHO_CELULA / 2)
	_atualizar()

# Rotulo embaixo do obelisco, para nao parecer ser do mago parado logo acima.
func rotulo_embaixo():
	hp_label.offset_top = 26
	hp_label.offset_bottom = 49

func pode_ocupar(pos: Vector2i) -> bool:
	return pos == grid_pos

func pode_agir_contra(_pos_jogador: Vector2i) -> bool:
	return false

# Cada golpe vindo de uma funcao tira 1, qualquer que seja o dano: o que conta e
# repetir a magia com nome, nao a forca dela.
func receber_dano(_dano: int, em_funcao: bool, com_parametros: bool = false) -> String:
	if not vivo:
		return "Essa Sentinela ja se desfez."
	if not em_funcao:
		return "A Sentinela ignora o golpe solto. Ela so reconhece magias com nome: ataque de dentro de uma funcao (def) e chame-a."
	if exige_parametro and not com_parametros:
		return "A Sentinela Gemea ignora funcoes sem parametros. Ela so reconhece magias que recebem valores, ex.: def golpear(direcao, vezes):"
	golpes_restantes -= 1
	if golpes_restantes > 0:
		_atualizar()
		return "A runa da Sentinela rachou! Falta" + ("" if golpes_restantes == 1 else "m") + " " + str(golpes_restantes) + " golpe" + ("" if golpes_restantes == 1 else "s") + "."
	vivo = false
	xp_gerado = 3
	_atualizar()
	_morrer()
	return "Sentinela desfeita! (+3 XP)"

func _atualizar():
	if hp_label:
		hp_label.text = "" if not vivo else "RUNA " + str(golpes_restantes) + "/" + str(golpes_max)
	if visual:
		visual.runa = "def(x)" if exige_parametro else "def"
		visual.definir_progresso(float(golpes_restantes) / golpes_max)

func _morrer():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

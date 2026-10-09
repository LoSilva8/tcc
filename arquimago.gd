extends Node2D

# Arquimago da Corrupcao, chefe final da Torre das Funcoes. Criterio da Tabela 11
# do TCC: so cai com uma solucao que use funcao, repeticao e condicional.
# - Salta para outro pedestal ao redor do mago a cada turno (so os sensores dizem onde).
# - So sente golpes de uma funcao do jogador, chamada dentro de um laco, que decide com if.
# - Se o programa terminar com ele de pe, os selos se refazem.
# - A cada 3 turnos lanca corrupcao (1 de dano).

const TAMANHO_CELULA = 64
const SELOS_MAX = 6

var grid_pos: Vector2i = Vector2i(0, 0)
var pedestais: Array = []
var selos: int = SELOS_MAX
var vivo: bool = true
var xp_gerado: int = 0
var turnos: int = 0

signal chefe_derrotado

@onready var hp_label = $HPLabel
@onready var nome_label = $NomeLabel
@onready var visual = $Visual

func inicializar(pos: Vector2i, lista_pedestais: Array):
	grid_pos = pos
	pedestais = lista_pedestais
	call_deferred("_aplicar_posicao")

func _aplicar_posicao():
	position = Vector2(grid_pos) * TAMANHO_CELULA + Vector2(TAMANHO_CELULA / 2, TAMANHO_CELULA / 2)
	_atualizar()

func pode_ocupar(pos: Vector2i) -> bool:
	return pos in pedestais

# Cada golpe da magia completa parte 1 selo, qualquer que seja o dano.
func receber_dano(_dano: int, em_funcao: bool, em_laco: bool, em_if: bool) -> String:
	if not vivo:
		return "O Arquimago ja caiu."
	if not em_funcao:
		return "O Arquimago desfaz golpes soltos. So uma magia completa o fere: uma funcao (def) que decide com if onde ele esta, chamada dentro de um laco."
	if not em_laco:
		return "A funcao acertou, mas o Arquimago se recompos: chame-a dentro de um laco (while) que so pare quando ele cair."
	if not em_if:
		return "O golpe veio as cegas e o Arquimago o desviou. Dentro da funcao, decida com if onde ele esta: inimigo_a_frente('direcao')."
	selos -= 1
	if selos <= 0:
		# Sem XP: o jogo termina aqui, e subir de nivel so cobriria a cena final.
		selos = 0
		vivo = false
		_atualizar()
		_morrer()
		return "O ARQUIMAGO DA CORRUPCAO CAIU!"
	_atualizar()
	return "Selo de corrupcao partido! Restam " + str(selos) + "/" + str(SELOS_MAX) + "."

# Chamado pelo gerenciador a cada turno dos inimigos (no lugar do movimento comum).
func turno_especial(jogador: Node) -> String:
	if not vivo:
		return ""
	turnos += 1
	if turnos % 3 == 0:
		return "[arquimago] O Arquimago lanca corrupcao. " + jogador.receber_dano_externo(1)
	return ""

# Depois de cada turno ele salta para outro pedestal (nunca o mesmo).
func proximo_pedestal() -> Vector2i:
	var opcoes = pedestais.filter(func(p): return p != grid_pos)
	return opcoes[randi() % opcoes.size()]

func ao_fim_do_programa() -> String:
	if not vivo or selos == SELOS_MAX:
		return ""
	selos = SELOS_MAX
	turnos = 0
	_atualizar()
	return "[arquimago] O programa terminou com o Arquimago de pe: os selos se refizeram (" + str(SELOS_MAX) + "/" + str(SELOS_MAX) + "). Use um laco que so pare quando ele cair, ex.: while inimigos_restantes() > 0:"

func _atualizar():
	if hp_label:
		hp_label.text = "" if not vivo else "SELOS " + str(selos) + "/" + str(SELOS_MAX)
	if nome_label:
		nome_label.text = "DERROTADO" if not vivo else "Arquimago"
	if visual:
		visual.definir_progresso(float(selos) / SELOS_MAX)

func _morrer():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)
	emit_signal("chefe_derrotado")

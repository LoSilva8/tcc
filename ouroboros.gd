extends Node2D

# Ouroboros, a Serpente do Laco (chefe do Labirinto).
# - So sente atacar(...) executado dentro de um while (laco com condicao de parada).
# - A cauda se renova (+1 segmento a cada 3 turnos): o numero de golpes nao e fixo.
# - Se o programa terminar com ela viva, ela se fecha de novo (segmentos cheios).

const TAMANHO_CELULA = 64
const SEGMENTOS_MAX = 8

var grid_pos: Vector2i = Vector2i(0, 0)
var segmentos: int = SEGMENTOS_MAX
var vivo: bool = true
var xp_gerado: int = 0
var turnos: int = 0

signal chefe_derrotado

@onready var hp_label = $HPLabel
@onready var nome_label = $NomeLabel
@onready var visual = $Visual

func inicializar(pos: Vector2i):
	grid_pos = pos
	call_deferred("_aplicar_posicao")

func _aplicar_posicao():
	position = Vector2(grid_pos) * TAMANHO_CELULA + Vector2(TAMANHO_CELULA / 2, TAMANHO_CELULA / 2)
	_atualizar()

func pode_ocupar(pos: Vector2i) -> bool:
	return pos == grid_pos

func receber_dano(dano: int, usando_variavel: bool, em_while: bool) -> String:
	if not vivo:
		return "O Ouroboros ja se rompeu."
	if usando_variavel:
		return "As escamas do Ouroboros refletem a magia. So golpes de atacar(...) dentro de um while o ferem."
	if not em_while:
		return "O Ouroboros se fecha a cada golpe solto. So um while, com condicao de parada, consegue parti-lo."
	segmentos = max(segmentos - max(dano, 1), 0)
	if segmentos == 0:
		vivo = false
		xp_gerado = 25
		_atualizar()
		_morrer()
		return "OUROBOROS PARTIDO! O laco infinito se rompeu. (+25 XP)"
	_atualizar()
	return "Segmento partido! Restam " + str(segmentos) + "/" + str(SEGMENTOS_MAX) + "."

# Chamado pelo gerenciador a cada turno dos inimigos (no lugar do movimento comum).
func turno_especial(jogador: Node) -> String:
	if not vivo:
		return ""
	turnos += 1
	var eventos: Array = []
	if turnos % 3 == 0 and segmentos < SEGMENTOS_MAX:
		segmentos += 1
		_atualizar()
		eventos.append("[ouroboros] A cauda se renova: " + str(segmentos) + "/" + str(SEGMENTOS_MAX) + ".")
	var distancia = absi(jogador.grid_pos.x - grid_pos.x) + absi(jogador.grid_pos.y - grid_pos.y)
	if distancia == 1 and turnos % 2 == 0:
		eventos.append("[ouroboros] O Ouroboros mordeu. " + jogador.receber_dano_externo(1))
	return "\n".join(eventos)

func ao_fim_do_programa() -> String:
	if not vivo or segmentos == SEGMENTOS_MAX:
		return ""
	segmentos = SEGMENTOS_MAX
	turnos = 0
	_atualizar()
	return "[ouroboros] O laco terminou antes da serpente: o Ouroboros se fechou de novo (" + str(SEGMENTOS_MAX) + "/" + str(SEGMENTOS_MAX) + "). Ataque dentro de um while que so pare quando ele cair."

func _atualizar():
	if hp_label:
		hp_label.text = "" if not vivo else "SEG " + str(segmentos) + "/" + str(SEGMENTOS_MAX)
	if nome_label:
		nome_label.text = "ROMPIDO" if not vivo else "Ouroboros"
	if visual:
		visual.definir_progresso(float(segmentos) / SEGMENTOS_MAX)

func _morrer():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
	emit_signal("chefe_derrotado")

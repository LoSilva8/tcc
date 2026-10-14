extends Node2D

# Guardiao de Runas, chefe da Floresta dos Primeiros Passos. Criterio da Tabela 11
# (derrotar o chefe com variaveis e sintaxe basica) e RA02 (tipos de dados): cada
# parte do corpo e uma runa que le as variaveis do mago.
# - Braco de Pedra (runa do numero): so sente fireball cuja variavel VALE o numero
#   da runa. O numero muda a cada golpe certo: o mago precisa trocar o valor.
# - Braco de Cristal (runa da palavra): so baixa a guarda quando a variavel feitico
#   guarda a palavra da runa como TEXTO (feitico = 'luz'); numero nao serve.
# - Nucleo: pede as duas coisas no mesmo golpe (numero e palavra), em sequencia.
# - Preso as raizes: nao sai do lugar e esmaga quem fica ao lado. A cada 3 turnos as
#   raizes ferem quem estiver na arena (o turno anterior avisa).
# - So pode ser atacado de dentro da arena, perto da saida.

const TAMANHO_CELULA = 64
const PARTES = ["braco_pedra", "braco_cristal", "nucleo"]
const GOLPES = {"braco_pedra": 2, "braco_cristal": 2, "nucleo": 1}
const NUMEROS = [1, 2, 3]
const PALAVRAS = ["luz", "raiz", "folha", "vento"]
const DANO_ESMAGAR = 2
const DANO_RAIZES = 1
const TURNOS_RAIZES = 3

var grid_pos: Vector2i = Vector2i(0, 0)
var vivo: bool = true
var xp_gerado: int = 0
var area_inicio: Vector2i = Vector2i.ZERO
var area_tamanho: Vector2i = Vector2i.ZERO

var parte_index: int = 0
var golpes_restantes: int = 0
var numero: int = 1
var palavra: String = "luz"
var turnos: int = 0

signal chefe_derrotado

@onready var hp_label = $HPLabel
@onready var parte_label = $ParteLabel
@onready var pedido_label = $PedidoLabel
@onready var visual = $Visual

func inicializar(pos: Vector2i, inicio: Vector2i = Vector2i.ZERO, tamanho: Vector2i = Vector2i.ZERO):
	grid_pos = pos
	area_inicio = inicio
	area_tamanho = tamanho
	parte_index = 0
	golpes_restantes = GOLPES[PARTES[0]]
	_sortear_numero()
	_sortear_palavra()
	call_deferred("_aplicar_posicao")

func _aplicar_posicao():
	position = Vector2(grid_pos) * TAMANHO_CELULA + Vector2(TAMANHO_CELULA / 2, TAMANHO_CELULA / 2)
	_atualizar()

func parte_atual() -> String:
	return PARTES[parte_index]

# Preso as raizes: nunca sai da propria casa.
func pode_ocupar(pos: Vector2i) -> bool:
	return pos == grid_pos

func pode_ser_atacado_por(pos_jogador: Vector2i) -> bool:
	return area_tamanho == Vector2i.ZERO or _na_area(pos_jogador)

func mensagem_fora_da_area() -> String:
	return "O Guardiao de Runas esta protegido pela arena.\nEntre na area marcada perto da saida para ataca-lo."

# nome_variavel/valor: a variavel usada na fireball. tem_feitico/feitico: a variavel
# feitico do mago, se existir (o Braco de Cristal e o Nucleo leem o texto dela).
func receber_dano(nome_variavel: String, valor, tem_feitico: bool, feitico) -> String:
	if not vivo:
		return "O Guardiao de Runas ja caiu."
	var parte = parte_atual()
	var recusa = ""
	if parte != "braco_cristal":
		recusa = _conferir_numero(nome_variavel, valor)
	if recusa == "" and parte != "braco_pedra":
		recusa = _conferir_palavra(tem_feitico, feitico)
	if recusa != "":
		return recusa

	golpes_restantes -= 1
	if golpes_restantes > 0:
		# A runa se refaz pedindo outro valor: a mesma variavel precisa mudar.
		if parte == "braco_pedra":
			_sortear_numero()
			_atualizar()
			return "Runa do numero rachada! A runa se refez e agora pede " + str(numero) + ".\nTroque o valor da variavel: " + nome_variavel + " = " + str(numero)
		_sortear_palavra()
		_atualizar()
		return "Runa da palavra rachada! A runa se refez e agora pede '" + palavra + "'.\nTroque o texto da variavel: feitico = '" + palavra + "'"

	parte_index += 1
	if parte_index >= PARTES.size():
		vivo = false
		xp_gerado = 8
		_atualizar()
		_morrer()
		return "Nucleo partido!\nGUARDIAO DE RUNAS DERROTADO! (+8 XP)"

	golpes_restantes = GOLPES[parte_atual()]
	_sortear_numero()
	_sortear_palavra()
	_atualizar()
	if parte_atual() == "braco_cristal":
		return "Braco de Pedra destruido!\nO Braco de Cristal acorda: ele so baixa a guarda para a palavra '" + palavra + "'.\nGuarde essa palavra como texto, entre aspas: feitico = '" + palavra + "'. Depois lance a fireball."
	return "Braco de Cristal destruido!\nO Nucleo se abre e pede as duas runas no mesmo golpe: o numero " + str(numero) + " e a palavra '" + palavra + "'.\nAjuste as duas variaveis e lance a fireball."

func _conferir_numero(nome_variavel: String, valor) -> String:
	if float(valor) == float(numero):
		return ""
	var quem = "A runa do numero" if parte_atual() == "braco_pedra" else "O Nucleo"
	return quem + " pede o numero " + str(numero) + ", mas " + nome_variavel + " vale " + str(valor) + ".\nA runa le o VALOR da variavel: troque-o com " + nome_variavel + " = " + str(numero) + " e lance de novo."

func _conferir_palavra(tem_feitico: bool, feitico) -> String:
	var quem = "O Braco de Cristal" if parte_atual() == "braco_cristal" else "O Nucleo"
	if not tem_feitico:
		return quem + " so baixa a guarda para a palavra '" + palavra + "'.\nGuarde essa palavra na variavel feitico, como texto entre aspas: feitico = '" + palavra + "'"
	if typeof(feitico) != TYPE_STRING:
		return quem + " pede um TEXTO, mas feitico guarda " + _descrever_valor(feitico) + ".\nTexto vai entre aspas: feitico = '" + palavra + "'"
	if feitico != palavra:
		return quem + " pede a palavra '" + palavra + "', mas feitico guarda '" + feitico + "'.\nO texto precisa ser igual, letra por letra: feitico = '" + palavra + "'"
	return ""

func _descrever_valor(v) -> String:
	match typeof(v):
		TYPE_BOOL:
			return "o valor logico " + ("True" if v else "False")
		TYPE_INT, TYPE_FLOAT:
			return "o numero " + str(v)
		TYPE_ARRAY:
			return "uma lista"
	return "outro tipo de valor"

# Chamado pelo gerenciador a cada turno dos inimigos (no lugar do movimento comum).
func turno_especial(jogador: Node) -> String:
	if not vivo:
		return ""
	turnos += 1
	var distancia = absi(jogador.grid_pos.x - grid_pos.x) + absi(jogador.grid_pos.y - grid_pos.y)
	if distancia == 1:
		return "[guardiao] O Guardiao de Runas esmagou o chao ao seu lado. " + jogador.receber_dano_externo(DANO_ESMAGAR)
	if area_tamanho == Vector2i.ZERO:
		return ""
	if turnos % TURNOS_RAIZES == TURNOS_RAIZES - 1:
		return "[guardiao] As raizes da arena tremem: no proximo turno elas brotam. Saia da arena para escapar."
	if turnos % TURNOS_RAIZES == 0 and _na_area(jogador.grid_pos):
		return "[guardiao] Raizes brotam do chao da arena. " + jogador.receber_dano_externo(DANO_RAIZES)
	return ""

func _na_area(pos: Vector2i) -> bool:
	return pos.x >= area_inicio.x and pos.x < area_inicio.x + area_tamanho.x \
		and pos.y >= area_inicio.y and pos.y < area_inicio.y + area_tamanho.y

func _sortear_numero():
	var opcoes = NUMEROS.filter(func(n): return n != numero)
	numero = opcoes[randi() % opcoes.size()]

func _sortear_palavra():
	var opcoes = PALAVRAS.filter(func(p): return p != palavra)
	palavra = opcoes[randi() % opcoes.size()]

func _nome_legivel(parte: String) -> String:
	match parte:
		"braco_pedra": return "Braco de Pedra"
		"braco_cristal": return "Braco de Cristal"
	return "Nucleo"

func _texto_pedido() -> String:
	match parte_atual():
		"braco_pedra":
			return "numero " + str(numero)
		"braco_cristal":
			return "feitico = '" + palavra + "'"
	return str(numero) + " e '" + palavra + "'"

func _atualizar():
	if not is_node_ready():
		return
	if not vivo:
		hp_label.text = ""
		parte_label.text = "DERROTADO"
		pedido_label.text = ""
	else:
		hp_label.text = "RUNA " + str(golpes_restantes) + "/" + str(GOLPES[parte_atual()])
		parte_label.text = _nome_legivel(parte_atual())
		pedido_label.text = _texto_pedido()
	if visual:
		visual.definir_estado(parte_index if vivo else PARTES.size())

func _morrer():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
	emit_signal("chefe_derrotado")

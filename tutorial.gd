extends Node

signal tutorial_concluido
signal aguardando_comando(comando_esperado)

@onready var tutorial_box = get_parent().get_node("UI/TutorialBox")
@onready var titulo_label = get_parent().get_node("UI/TutorialBox/VBoxContainer/TutorialTitulo")
@onready var texto_label = get_parent().get_node("UI/TutorialBox/VBoxContainer/TutorialTexto")
@onready var dica_label = get_parent().get_node("UI/TutorialBox/VBoxContainer/TutorialDica")
@onready var comando_label = get_parent().get_node("UI/TutorialBox/VBoxContainer/TutorialComando")

var etapa_atual: int = 0
var ativo: bool = false
var tentativas: int = 0
var variavel_fireball_tutorial: String = "poder"
var pagina_atual = 0
var pagina_label: Label
var pagina_anterior: Button
var pagina_proxima: Button

var etapas = [
	{
		"titulo": "PyAdventure - Tutorial",
		"paginas": [
			"ENTENDA\n\nNeste jogo, seu codigo controla o mago.\nVoce escreve uma instrucao e ele executa a acao.\n\nO terminal e o campo de texto na parte de baixo. Escreva nele e pressione Enter.",
			"LEIA O COMANDO\n\nmover('direita')\n\nmover e o nome da acao (uma funcao).\nOs parenteses ( ) recebem a direcao.\nAs aspas ' ' indicam que direita e um texto.",
			"SUA VEZ\n\nDigite mover('direita') no terminal.\nDepois, pressione Enter.\n\nO mago anda uma casa para a direita.\nConfira no mapa o resultado do seu codigo."
		],
		"comando": "mover('direita')",
		"dica": "Digite: mover('direita')\nmover e a acao; 'direita' e a direcao."
	},
	{
		"titulo": "Movimento",
		"paginas": [
			"MUDE UMA INFORMACAO\n\nO mesmo comando pode ter resultados diferentes.\nBasta trocar o texto dentro dos parenteses.\n\nmover('baixo')\n\nA acao continua sendo mover; a direcao mudou.",
			"ESCOLHA O CAMINHO\n\nDirecoes: 'direita', 'esquerda', 'cima', 'baixo'.\nCada comando move uma casa.\n\nAgora pratique com mover('baixo').\nSe houver uma parede, procure um caminho livre."
		],
		"comando": "mover('baixo')",
		"dica": "Digite: mover('baixo')\nA direcao sempre fica entre aspas."
	},
	{
		"titulo": "Combate",
		"paginas": [
			"UMA NOVA ACAO\n\natacar('direita')\n\natacar e outra funcao: ela desfere um golpe.\n'direita' indica para onde atacar.\n\nO ataque comum nao gasta mana (MP).",
			"OLHE ANTES DE ATACAR\n\nO golpe so alcanca a casa ao lado do mago.\nEle nao move o personagem.\n\nFique ao lado do inimigo e ataque na direcao dele.\nNo caminho sugerido, use atacar('direita')."
		],
		"comando": "atacar('direita')",
		"dica": "Digite: atacar('direita')\nO ataque olha para a casa ao lado."
	},
	{
		"titulo": "Bom ataque",
		"paginas": [
			"OBSERVE O RESULTADO\n\nHP significa pontos de vida.\nCada golpe diminui a vida do inimigo.\n\nSe ainda restou HP, ele precisa de outro golpe.\nVeja o numero sobre ele antes de agir.",
			"UM PASSO DEPOIS DO OUTRO\n\nUma sequencia e uma ordem de acoes.\nPrimeiro voce se aproxima; depois ataca.\n\nAgora ataque mais uma vez na direcao do inimigo.\nPode repetir o mesmo comando."
		],
		"comando": "atacar('direita')",
		"dica": "Repita: atacar('direita')\nRepetir comandos tambem faz parte do jogo."
	},
	{
		"titulo": "Ultimo golpe",
		"paginas": [
			"REPITA PARA CONCLUIR\n\nExecutar o mesmo comando repete a mesma acao.\n\nSe o inimigo continua na casa ao lado,\nataque novamente na direcao dele.\n\nQuando o HP chega a zero, ele e derrotado."
		],
		"comando": "atacar('direita')",
		"dica": "Digite: atacar('direita')\nDepois disso, vamos aprender variaveis."
	},
	{
		"titulo": "Inimigo magico",
		"paginas": [
			"INVESTIGUE O ESCUDO\n\nO inimigo roxo tem uma protecao magica.\n\nUse mover(...) para ficar ao lado dele.\nDepois, tente atacar(...) na direcao dele.\n\nLeia a resposta do jogo no terminal.",
			"APRENDA COM A RESPOSTA\n\nO escudo bloqueia o ataque comum.\nIsso e uma pista sobre o problema.\n\nVoce vai precisar de uma magia: fireball.\nAntes, vamos aprender a guardar o poder dela\nem uma variavel."
		],
		"comando": null,
		"dica": ""
	},
	{
		"titulo": "Variavel magica",
		"paginas": [
			"GUARDE UM VALOR\n\nUma variavel guarda um valor dentro do codigo.\nPense em uma caixinha com nome:\nvoce guarda algo nela para usar depois.\n\nAqui, vamos guardar a forca de uma magia.",
			"LEIA A ATRIBUICAO\n\npoder = 3\n\npoder e o nome da variavel.\n= guarda o valor que vem a direita.\n3 e o numero guardado.\nIsso se chama atribuicao.",
			"NUMERO E TEXTO SAO DIFERENTES\n\n3 e um numero. '3' e um texto, pois tem aspas.\nA magia precisa de um numero para seu poder.\n\nDigite poder = 3, sem aspas.\nCriar a variavel apenas guarda o valor;\na magia sera lancada no proximo passo."
		],
		"comando": "poder = 3",
		"dica": "Digite: poder = 3\nO sinal = guarda o valor dentro da variavel."
	},
	{
		"titulo": "Fireball",
		"paginas": [
			"USE O VALOR GUARDADO\n\nfireball({var_fireball}, 'direita')\n\nfireball lanca uma bola de fogo.\n{var_fireball} usa o valor da sua variavel, sem aspas.\n'direita' e a direcao, escrita como texto.\nA virgula separa essas duas informacoes.",
			"PLANEJE A MANA\n\nMP e a energia usada pelas magias.\nFireball custa 2 MP + o valor do poder.\n\nExemplo: poder 3 custa 2 + 3 = 5 MP.\nVoce recupera 1 MP por rodada valida.\nO ataque comum continua gratuito.",
			"MIRE NO ESCUDO\n\nA fireball viaja em linha reta e para em paredes.\nAlinhe o mago com o inimigo roxo.\n\nLance na direcao dele usando sua variavel.\nSe estiver a direita, use o exemplo abaixo.\nSe faltar mana, mova ou ataque para recupera-la."
		],
		"comando": "fireball({var_fireball}, 'direita')",
		"dica": "Digite: fireball({var_fireball}, 'direita')\nA variavel vai sem aspas; a direcao com aspas."
	},
	{
		"titulo": "Encontre a saida",
		"paginas": [
			"O QUE VOCE APRENDEU\n\nmover(...) muda a posicao.\natacar(...) atinge a casa ao lado, sem gastar MP.\npoder = 3 guarda um numero em uma variavel.\nfireball(...) usa esse numero para lancar magia.\n\nO Livro de Magias guarda os comandos ensinados.",
			"SUA PRIMEIRA MISSAO\n\nUse mover(...) para pisar na saida verde.\nEscolha as direcoes olhando o mapa.\n\nNa floresta, voce usara o que aprendeu\npara encontrar uma chave e enfrentar um boss."
		],
		"comando": null,
		"dica": ""
	},
]

func _ready():
	var coluna = texto_label.get_parent()
	var navegacao = HBoxContainer.new()
	coluna.add_child(navegacao)
	coluna.move_child(navegacao, texto_label.get_index() + 1)
	pagina_anterior = Button.new()
	pagina_anterior.text = "<"
	pagina_anterior.tooltip_text = "Explicacao anterior"
	pagina_anterior.custom_minimum_size = Vector2(32, 28)
	pagina_anterior.pressed.connect(func(): _mudar_pagina(-1))
	navegacao.add_child(pagina_anterior)
	pagina_label = Label.new()
	pagina_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pagina_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navegacao.add_child(pagina_label)
	pagina_proxima = Button.new()
	pagina_proxima.text = ">"
	pagina_proxima.tooltip_text = "Proxima explicacao"
	pagina_proxima.custom_minimum_size = Vector2(32, 28)
	pagina_proxima.pressed.connect(func(): _mudar_pagina(1))
	navegacao.add_child(pagina_proxima)
	texto_label.custom_minimum_size.y = 180
	comando_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _mudar_pagina(direcao: int):
	pagina_atual = clampi(pagina_atual + direcao, 0, etapas[etapa_atual]["paginas"].size() - 1)
	_atualizar_pagina()
	get_parent().input_line.grab_focus()

func _atualizar_pagina():
	var paginas = etapas[etapa_atual]["paginas"]
	texto_label.text = _formatar_texto_tutorial(paginas[pagina_atual])
	pagina_label.text = "Explicacao %d de %d" % [pagina_atual + 1, paginas.size()]
	pagina_anterior.disabled = pagina_atual == 0
	pagina_proxima.disabled = pagina_atual == paginas.size() - 1

func iniciar():
	ativo = true
	etapa_atual = 0
	tentativas = 0
	variavel_fireball_tutorial = "poder"
	_mostrar_etapa(0)

func _mostrar_etapa(indice: int):
	if indice >= etapas.size():
		_concluir()
		return
	
	var etapa = etapas[indice]
	tutorial_box.visible = true
	titulo_label.text = "%d/%d | %s" % [indice + 1, etapas.size(), etapa["titulo"]]
	pagina_atual = 0
	_atualizar_pagina()
	dica_label.text = ""
	dica_label.visible = false
	
	if etapa["comando"] == null:
		comando_label.text = "Agora: aproxime-se do inimigo roxo e teste atacar(...)." if indice == 5 else "Agora: use mover(...) ate pisar na saida verde."
	else:
		comando_label.text = "Pratique: " + _formatar_texto_tutorial(str(etapa["comando"])) + "\nDigite no terminal e pressione Enter."
	comando_label.visible = true

func verificar_comando(comando_digitado: String, resposta_jogo: String = "") -> bool:
	if not ativo:
		return false
	
	if _aplicar_progresso_da_etapa(comando_digitado, resposta_jogo):
		tentativas = 0
		return true
	
	tentativas += 1
	_mostrar_dica_contextual(comando_digitado, resposta_jogo)
	return false

func _aplicar_progresso_da_etapa(comando_digitado: String, resposta_jogo: String) -> bool:
	var comando = _normalizar_comando(comando_digitado)
	var resposta = resposta_jogo.to_lower()
	
	if "encontrou a saida" in resposta:
		_concluir()
		return true
	
	match etapa_atual:
		0:
			if _resposta_tem_movimento(resposta, "direita"):
				_avancar()
				return true
		1:
			if _resposta_tem_movimento(resposta, "baixo"):
				_avancar()
				return true
		2, 3, 4:
			if _resposta_tem_ataque_com_sucesso(resposta):
				if "inimigo derrotado" in resposta:
					_ir_para_etapa(5)
				else:
					_avancar()
				return true
		5:
			if _resposta_tem_ataque_com_sucesso(resposta) and "escudo" in resposta and "fireball(" in comando:
				_ir_para_etapa(8)
				return true
			if "escudo magico bloqueou" in resposta or ("escudo" in resposta and "bloqueou" in resposta):
				_avancar()
				return true
		6:
			if _resposta_tem_ataque_com_sucesso(resposta) and "fireball(" in comando:
				_ir_para_etapa(8)
				return true
			
			var nome_variavel = _nome_variavel_numerica(comando_digitado)
			if nome_variavel != "" and nome_variavel in resposta:
				variavel_fireball_tutorial = nome_variavel
				_avancar()
				return true
		7:
			if "fireball(" in comando and _resposta_tem_ataque_com_sucesso(resposta):
				_avancar()
				return true
		8:
			if "saida" in resposta:
				_avancar()
				return true
	
	return false

func _normalizar_comando(comando: String) -> String:
	return comando.strip_edges().to_lower().replace("\"", "'").replace(" ", "").replace("\t", "")

func _formatar_texto_tutorial(texto: String) -> String:
	return texto.replace("{var_fireball}", variavel_fireball_tutorial)

func _resposta_tem_movimento(resposta: String, direcao: String) -> bool:
	return ("moveu para " + direcao) in resposta

func _resposta_tem_ataque_com_sucesso(resposta: String) -> bool:
	if "nenhum inimigo" in resposta:
		return false
	if "bloqueou" in resposta:
		return false
	if "direcao invalida" in resposta:
		return false
	
	return "inimigo atingido" in resposta or "inimigo derrotado" in resposta or "escudo quebrado" in resposta

func _nome_variavel_numerica(comando: String) -> String:
	var partes = comando.split("=", false, 1)
	if partes.size() != 2:
		return ""
	
	var nome = partes[0].strip_edges()
	var valor = partes[1].strip_edges()
	
	if not (valor.is_valid_int() or valor.is_valid_float()):
		return ""
	
	return nome

func _mostrar_dica_contextual(_comando_digitado: String, resposta_jogo: String):
	dica_label.visible = true
	var etapa = etapas[etapa_atual]
	var dica_base = _formatar_texto_tutorial(str(etapa["dica"]))
	var resposta = resposta_jogo.to_lower()
	
	if dica_base == "":
		if etapa_atual == 5:
			dica_label.text = "Explore com mover('direcao') ate ficar perto do inimigo roxo. Depois tente ataca-lo para descobrir o escudo."
		elif etapa_atual == 8:
			dica_label.text = "Continue usando mover('direcao') ate pisar na saida verde."
		else:
			dica_label.text = ""
		return
	
	if "moveu para" in resposta or _resposta_tem_ataque_com_sucesso(resposta):
		dica_label.text = "Tudo bem explorar, mas para continuar esta parte:\n" + dica_base
	else:
		dica_label.text = dica_base

func _avancar():
	etapa_atual += 1
	tentativas = 0
	
	if etapa_atual >= etapas.size():
		_concluir()
	else:
		_mostrar_etapa(etapa_atual)

func _ir_para_etapa(indice: int):
	etapa_atual = indice
	tentativas = 0
	
	if etapa_atual >= etapas.size():
		_concluir()
	else:
		_mostrar_etapa(etapa_atual)

func _concluir():
	encerrar()
	emit_signal("tutorial_concluido")

# Desliga o tutorial sem o sinal de conclusao: a run comeca direto em um bioma
# porque o tutorial ja foi feito em outra partida (US01).
func encerrar():
	ativo = false
	tutorial_box.visible = false

func esta_ativo() -> bool:
	return ativo

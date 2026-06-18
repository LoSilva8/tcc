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

var etapas = [
	{
		"titulo": "PyAdventure - Tutorial",
		"texto": "Voce e um mago aprendiz na Grande\nBiblioteca de Sintaxe.\n\nAqui a magia funciona com comandos\ninspirados em Python.\n\nComece movendo seu personagem para\na direita:",
		"comando": "mover('direita')",
		"dica": "Digite: mover('direita')\nUse aspas simples dentro dos parenteses."
	},
	{
		"titulo": "Movimento",
		"texto": "mover() e uma funcao: uma instrucao\nque diz ao jogo o que fazer.\n\nO texto entre aspas e o argumento:\nele define a direcao.\n\nAgora mova para baixo:",
		"comando": "mover('baixo')",
		"dica": "Digite: mover('baixo')"
	},
	{
		"titulo": "Combate",
		"texto": "Ha um inimigo logo a sua direita.\nUse atacar() para atingi-lo.\n\nAtaque para a direita:",
		"comando": "atacar('direita')",
		"dica": "Digite: atacar('direita')\nO inimigo precisa de 3 ataques."
	},
	{
		"titulo": "Bom ataque",
		"texto": "O inimigo ainda esta vivo.\nAtaque mais uma vez:",
		"comando": "atacar('direita')",
		"dica": "Digite: atacar('direita')"
	},
	{
		"titulo": "Ultimo golpe",
		"texto": "Mais um ataque para derrota-lo:",
		"comando": "atacar('direita')",
		"dica": "Digite: atacar('direita')"
	},
	{
		"titulo": "Inimigo magico",
		"texto": "Inimigo derrotado.\n\nHa um inimigo roxo no canto inferior\ndireito da sala.\n\nEle tem um escudo magico que bloqueia\nataques normais.\n\nVa ate ele usando mover() e tente\nataca-lo.",
		"comando": null,
		"dica": ""
	},
	{
		"titulo": "Variavel magica",
		"texto": "O escudo bloqueou.\n\nPara vencer, voce precisa de uma\nvariavel: uma caixa que guarda um valor.\n\n  golpes = 5\n\nCrie a variavel:",
		"comando": "golpes = 5",
		"dica": "Digite: golpes = 5\nO sinal = guarda o valor na variavel."
	},
	{
		"titulo": "Use a variavel",
		"texto": "Variavel criada.\n\nAgora use o comando especial que usa a\nvariavel como magia:\n\n  atacar_com(golpes, 'direcao')\n\nO inimigo roxo esta a sua direita ou\nabaixo. Ajuste a direcao se precisar.\n\nAtaque com a variavel:",
		"comando": "atacar_com(golpes, 'direita')",
		"dica": "Digite: atacar_com(golpes, 'direita')\nPerceba: golpes fica sem aspas."
	},
	{
		"titulo": "Encontre a saida",
		"texto": "Inimigo derrotado com magia.\n\nVoce aprendeu:\n  mover('dir')      -> move\n  atacar('dir')     -> ataca\n  x = valor         -> variavel\n  atacar_com(x,dir) -> magia\n\nAgora va ate a saida verde.",
		"comando": null,
		"dica": ""
	},
]

func iniciar():
	ativo = true
	etapa_atual = 0
	tentativas = 0
	_mostrar_etapa(0)

func _mostrar_etapa(indice: int):
	if indice >= etapas.size():
		_concluir()
		return
	
	var etapa = etapas[indice]
	tutorial_box.visible = true
	titulo_label.text = etapa["titulo"]
	texto_label.text = etapa["texto"]
	dica_label.text = ""
	
	if etapa["comando"] == null:
		comando_label.text = ""
		comando_label.visible = false
	else:
		comando_label.text = "Digite o comando no terminal abaixo"
		comando_label.visible = true

var aguardando_escudo: bool = false

func verificar_comando(comando_digitado: String, resposta_jogo: String = "") -> bool:
	if not ativo:
		return false
	
	var etapa = etapas[etapa_atual]
	
	if etapa["comando"] == null:
		if "escudo" in resposta_jogo.to_lower():
			_avancar()
		return false
	
	var esperado = etapa["comando"].strip_edges()
	var digitado = comando_digitado.strip_edges()
	
	if digitado == esperado:
		tentativas = 0
		_avancar()
		return true
	else:
		tentativas += 1
		if tentativas >= 1:
			dica_label.text = etapa["dica"]
		return false

func _avancar():
	etapa_atual += 1
	tentativas = 0
	
	if etapa_atual >= etapas.size():
		_concluir()
	else:
		_mostrar_etapa(etapa_atual)

func _concluir():
	ativo = false
	tutorial_box.visible = false
	emit_signal("tutorial_concluido")

func esta_ativo() -> bool:
	return ativo

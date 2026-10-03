extends Node

var jogo: Node
var dica_proximidade: Label
var painel: PanelContainer
var editor: CodeEdit
var explicacao: Label
var feedback: Label
var titulo: Label
var pagina_texto: Label
var anterior: Button
var proximo: Button
var pagina = 0
var etapa = 0
var rascunhos = ["selos = \nabrir_bau(selos)", "if tem_chave == True:\n    \nelse:\n    "]
var dicas = [0, 0]

func configurar(cena: Node):
	jogo = cena
	dica_proximidade = Label.new()
	dica_proximidade.position = Vector2(12, 64)
	dica_proximidade.size = Vector2(380, 64)
	dica_proximidade.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica_proximidade.add_theme_font_size_override("font_size", 17)
	dica_proximidade.add_theme_color_override("font_shadow_color", Color.BLACK)
	dica_proximidade.add_theme_constant_override("shadow_offset_x", 2)
	dica_proximidade.add_theme_constant_override("shadow_offset_y", 2)
	dica_proximidade.z_index = 30
	dica_proximidade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jogo.ui_root.add_child(dica_proximidade)
	painel = PanelContainer.new()
	painel.z_index = 60
	jogo.ui_root.add_child(painel)
	painel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	painel.offset_left = 24
	painel.offset_right = -24
	painel.offset_top = 60
	painel.offset_bottom = -20
	painel.add_theme_stylebox_override("panel", jogo._estilo_livro(Color("172126"), Color("69b9ac"), 8))
	var scroll = ScrollContainer.new()
	painel.add_child(scroll)
	var coluna = VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 12)
	scroll.add_child(coluna)
	var topo = HBoxContainer.new()
	coluna.add_child(topo)
	titulo = _label(topo)
	titulo.add_theme_font_size_override("font_size", 20)
	var fechar = Button.new()
	fechar.text = "Voltar ao mapa"
	fechar.pressed.connect(_fechar)
	topo.add_child(fechar)
	explicacao = _label(coluna)
	explicacao.custom_minimum_size.y = 150
	var navegacao = HBoxContainer.new()
	coluna.add_child(navegacao)
	anterior = Button.new()
	anterior.text = "<"
	anterior.tooltip_text = "Explicacao anterior"
	anterior.pressed.connect(func(): _mudar_pagina(-1))
	navegacao.add_child(anterior)
	pagina_texto = _label(navegacao)
	proximo = Button.new()
	proximo.text = ">"
	proximo.tooltip_text = "Proxima explicacao"
	proximo.pressed.connect(func(): _mudar_pagina(1))
	navegacao.add_child(proximo)
	editor = CodeEdit.new()
	editor.custom_minimum_size = Vector2(0, 150)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.gutters_draw_line_numbers = true
	editor.indent_size = 4
	editor.indent_use_spaces = true
	editor.syntax_highlighter = jogo.criar_realce_python()
	editor.text_changed.connect(func(): jogo.ia.cancelar())
	editor.add_theme_font_size_override("font_size", 18)
	coluna.add_child(editor)
	var acoes = HBoxContainer.new()
	coluna.add_child(acoes)
	var executar = Button.new()
	executar.text = "Executar codigo"
	executar.pressed.connect(_executar)
	acoes.add_child(executar)
	var dica = Button.new()
	dica.text = "Ver dica"
	dica.pressed.connect(_dica)
	acoes.add_child(dica)
	feedback = _label(coluna)
	feedback.add_theme_color_override("font_color", Color("f5d887"))
	painel.hide()

func _label(coluna: Control) -> Label:
	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	coluna.add_child(label)
	return label

func _process(_delta):
	if jogo == null:
		return
	var disponivel = jogo.sala_atual == 1 and jogo.player.vivo
	if not disponivel:
		painel.hide()
	dica_proximidade.text = ""
	if disponivel and not painel.visible:
		if _perto(jogo.mapa.PORTA_POS) and not jogo.mapa.porta_aberta:
			dica_proximidade.text = "Para abrir a porta, digite\ndesafio(porta)"
		elif _perto(jogo.mapa.BAU_POS) and not jogo.mapa.bau_aberto:
			dica_proximidade.text = "Para abrir o bau, digite\ndesafio(bau)"
	dica_proximidade.size.x = minf(380, maxf(1, jogo.get_viewport_rect().size.x - 24))

func reiniciar():
	rascunhos = ["selos = \nabrir_bau(selos)", "if tem_chave == True:\n    \nelse:\n    "]
	dicas = [0, 0]
	painel.hide()

func abrir(alvo: String) -> String:
	if painel.visible:
		return "O desafio ja esta aberto."
	if jogo.sala_atual != 1 or not jogo.player.vivo:
		return "Os desafios do bau e da porta ficam na Fase 1."
	if alvo not in ["bau", "porta"]:
		return "Use desafio(bau) ou desafio(porta) ao lado do objeto."
	var pos: Vector2i = jogo.mapa.BAU_POS if alvo == "bau" else jogo.mapa.PORTA_POS
	if not _perto(pos):
		return "Aproxime-se: fique em uma casa ao lado " + ("do bau" if alvo == "bau" else "da porta") + " e digite desafio(" + alvo + ")."
	if not jogo.player.pending_escolha.is_empty():
		return "Escolha sua runa antes de iniciar o desafio."
	etapa = 0 if alvo == "bau" else 1
	pagina = 0
	_atualizar()
	painel.show()
	editor.grab_focus()
	return "Desafio aberto. Leia um passo por vez e teste seu codigo."

func comando(texto: String) -> String:
	var regex = RegEx.new()
	regex.compile("^desafio\\(\\s*(bau|porta)\\s*\\)$")
	var resultado = regex.search(texto)
	if resultado == null:
		return "Use desafio(porta) ou desafio(bau), ao lado do objeto."
	return abrir(resultado.get_string(1))

func _atualizar():
	editor.text = rascunhos[etapa]
	feedback.text = "Voce pode tentar quantas vezes precisar. Estas tentativas nao gastam turnos nem mana."
	_atualizar_pagina()

func _paginas() -> Array:
	if etapa == 0:
		return [
			["1. Uma variavel guarda um valor", "Pense em uma caixinha com nome: voce guarda um valor nela para usar depois.\n\nmoedas = 2\n\nAqui, moedas e o nome da variavel. O sinal = guarda o numero 2 nela."],
			["2. Usar o valor guardado", "O bau tem 3 selos dourados. Guarde esse numero em uma variavel chamada selos.\n\nabrir_bau(selos)\n\nEsse comando usa o numero guardado em selos para destrancar o bau."],
			["3. Sua vez: encontre a chave", "Complete selos = com o numero de selos do bau.\n\nO codigo roda de cima para baixo:\n1. Guarda o numero.\n2. Usa esse numero para abrir o bau.\n\nExecute para pegar a chave. Se precisar, use Ver dica."]
		]
	var estado = "True: voce ja tem a chave." if jogo.mapa.bau_aberto else "False: voce ainda precisa buscar a chave no bau."
	return [
		["1. A porta precisa tomar uma decisao", "SE voce tem a chave, a porta pode abrir.\nSENAO, precisa buscar a chave.\n\nO jogo guarda essa informacao em tem_chave:\nTrue significa verdadeiro (tem). False significa falso (nao tem).\n\nAgora tem_chave vale " + estado],
		["2. if: o que fazer quando tem a chave", "if tem_chave == True:\n    abrir_porta()\n\nLeia: SE tem_chave e igual a True, abra a porta.\n\n== compara dois valores. E diferente de =, que guarda um valor.\nOs dois-pontos : anunciam a acao na linha de baixo."],
		["3. else: o que fazer quando nao tem", "else:\n    print('Preciso da chave')\n\nLeia: SENAO, mostre a mensagem Preciso da chave.\nprint(...) mostra o texto entre aspas.\n\nSo um caminho e executado: a acao do if OU a acao do else."],
		["4. Sua vez: complete as duas acoes", "Abaixo do if, escreva abrir_porta().\nAbaixo do else, escreva print('Preciso da chave').\n\nDeixe 4 espacos antes de cada acao: esse recuo mostra a qual parte ela pertence.\n\nExecute para testar sua decisao. Sem a chave, busque o bau e volte: seu codigo fica salvo."]
	]

func _mudar_pagina(direcao: int):
	pagina = clampi(pagina + direcao, 0, _paginas().size() - 1)
	_atualizar_pagina()

func _atualizar_pagina():
	var paginas = _paginas()
	titulo.text = ("Bau | " if etapa == 0 else "Porta | ") + paginas[pagina][0]
	explicacao.text = paginas[pagina][1]
	pagina_texto.text = "Passo %d de %d" % [pagina + 1, paginas.size()]
	anterior.disabled = pagina == 0
	proximo.disabled = pagina == paginas.size() - 1

func _fechar():
	jogo.ia.cancelar()
	rascunhos[etapa] = editor.text
	painel.hide()
	jogo.input_line.grab_focus()

func _dica():
	jogo.ia.cancelar()
	dicas[etapa] += 1
	if etapa == 0:
		feedback.text = "O numero de selos e 3. Coloque esse numero depois do sinal =. A segunda linha usa o valor guardado."
		if dicas[etapa] > 1:
			feedback.text = "Exemplo completo:\nselos = 3\nabrir_bau(selos)\nselos guarda 3; abrir_bau recebe esse valor e libera a chave. Digite no editor e execute."
	else:
		feedback.text = "Abaixo do if, escreva    abrir_porta(). Abaixo do else, escreva    print('Preciso da chave'). So uma dessas acoes roda."
		if dicas[etapa] > 1:
			feedback.text = "Exemplo completo:\nif tem_chave == True:\n    abrir_porta()\nelse:\n    print('Preciso da chave')\nCom a chave: abre. Sem a chave: mostra a mensagem. Digite no editor e execute."

func _executar():
	jogo.ia.cancelar()
	rascunhos[etapa] = editor.text
	feedback.text = executar_codigo(editor.text, etapa)
	jogo._adicionar_saida("[desafio] " + feedback.text)
	var codigo = editor.text
	var resposta = feedback.text
	var contexto = "Desafio do bau: guardar 3 em uma variavel." if etapa == 0 else "Desafio da porta: if/else. tem_chave = " + str(jogo.mapa.bau_aberto)
	jogo.ia.solicitar(codigo, resposta, contexto, func(dica: String, gerada: bool):
		if not painel.visible or editor.text != codigo:
			return
		var rotulo = "IA" if gerada else "Dica"
		feedback.text = resposta + "\n\n" + rotulo + ": " + dica
		jogo._adicionar_saida("[" + rotulo + "] " + dica)
	)

func executar_codigo(codigo: String, desafio: int) -> String:
	if jogo.sala_atual != 1 or not jogo.player.vivo:
		return "Este desafio esta disponivel na Fase 1."
	var linhas: Array[String] = []
	for linha in codigo.replace("\r", "").split("\n"):
		if not linha.strip_edges().is_empty() and not linha.strip_edges().begins_with("#"):
			linhas.append(linha.replace("\t", "    "))
	if desafio == 0:
		return _executar_bau(linhas)
	return _executar_porta(linhas)

func _perto(pos: Vector2i) -> bool:
	var distancia: Vector2i = jogo.player.grid_pos - pos
	return absi(distancia.x) + absi(distancia.y) == 1

func _executar_bau(linhas: Array[String]) -> String:
	if jogo.mapa.bau_aberto:
		return "Bau ja aberto! Voce guardou um valor e usou esse valor em um comando. A chave esta com voce. Agora procure a porta azul."
	if linhas.size() != 2:
		return "Use duas linhas: na primeira guarde o numero de selos em uma variavel; na segunda use abrir_bau(nome_da_variavel)."
	var atribuicao = RegEx.new()
	atribuicao.compile("^([a-zA-Z_][a-zA-Z0-9_]*)\\s*=\\s*(0|[1-9][0-9]*)$")
	var valor = atribuicao.search(linhas[0].strip_edges())
	if valor == null:
		return "Uma variavel precisa de nome, = e valor. Exemplo: moedas = 2. Aqui, conte os selos do bau e guarde esse numero."
	var nome = valor.get_string(1)
	if nome in "False None True and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield tem_chave print abrir_bau abrir_porta".split(" "):
		return "Escolha um nome para seu numero, como selos ou quantidade. Esse nome e reservado."
	var chamada = RegEx.new()
	chamada.compile("^abrir_bau\\(\\s*" + nome + "\\s*\\)$")
	if chamada.search(linhas[1].strip_edges()) == null:
		return "Use a mesma variavel da primeira linha: abrir_bau(" + nome + "). Assim o comando recebe o valor que voce guardou."
	if valor.get_string(2).to_int() != 3:
		return "Seu codigo tem a estrutura certa! Mas o bau tem 3 selos. Guarde 3 em " + nome + " e tente novamente."
	if not _perto(jogo.mapa.BAU_POS):
		return "Codigo correto! Fique ao lado do bau dourado, no abrigo ao sul da floresta. Seu codigo ficara salvo."
	jogo.interpretador.variaveis[nome] = 3
	jogo.mapa.bau_aberto = true
	jogo.mapa.queue_redraw()
	return "Bau aberto! " + nome + " guardou 3, e abrir_bau usou esse valor. Voce recebeu a chave! Volte ao mapa, aproxime-se da porta e digite desafio(porta)."

func _executar_porta(linhas: Array[String]) -> String:
	if jogo.mapa.porta_aberta:
		return "Porta ja aberta! O if escolheu a acao porque voce tinha a chave. O boss espera dentro da arena."
	if linhas.size() != 4 or not linhas[0].begins_with("if ") or linhas[2] != "else:":
		return "Monte 4 linhas: if condicao:, acao recuada, else:, outra acao recuada. Use Ver dica para ver um exemplo."
	if not linhas[0].ends_with(":"):
		return "Falta : no fim do if. Os dois-pontos anunciam a acao que vem abaixo."
	for indice in [1, 3]:
		if not linhas[indice].begins_with("    ") or linhas[indice].begins_with("     "):
			return "Recue cada acao com 4 espacos. Esse recuo mostra quais linhas pertencem ao if e ao else."
	var condicao = linhas[0].substr(3).trim_suffix(":").strip_edges()
	var padrao = RegEx.new()
	padrao.compile("^(tem_chave|not\\s+tem_chave|tem_chave\\s*(==|!=)\\s*(True|False))$")
	if padrao.search(condicao) == null:
		return "Compare a chave usando tem_chave == True. True e False comecam com maiuscula. Para comparar use ==, nao =."
	var acao_if = linhas[1].strip_edges()
	var acao_else = linhas[3].strip_edges()
	var mensagem = RegEx.new()
	mensagem.compile("^print\\(\\s*(['\"])(.*?)\\1\\s*\\)$")
	# Validate both outcomes before changing the world, including an inverted condition.
	var teste = preload("res://interpretador.gd").new()
	teste.variaveis["tem_chave"] = true
	var com_chave = teste._avaliar_condicao(condicao)
	teste.free()
	var abrir = acao_if if com_chave else acao_else
	var avisar = acao_else if com_chave else acao_if
	if abrir != "abrir_porta()" or mensagem.search(avisar) == null:
		return "Com a chave, a acao deve ser abrir_porta(). Sem a chave, use print('Preciso da chave'). Confira em qual ramo voce escreveu cada acao."
	if not jogo.mapa.bau_aberto:
		return "tem_chave vale False. Executou o ramo sem chave: " + mensagem.search(avisar).get_string(2) + "\nSeu if/else esta correto! Abra o bau para obter a chave e depois execute de novo perto da porta."
	if not _perto(jogo.mapa.PORTA_POS):
		return "Codigo correto e chave obtida! Fique ao lado da porta azul na passagem para a arena e execute novamente."
	jogo.mapa.porta_aberta = true
	jogo.mapa.queue_redraw()
	return "Porta aberta! tem_chave vale True, entao abrir_porta() foi executado. A mensagem do outro ramo nao rodou: if/else escolhe apenas um caminho. Prepare-se para o boss!"

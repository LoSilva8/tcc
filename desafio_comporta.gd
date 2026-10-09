extends Node

const COMPORTA_TEMPERATURAS = ["fria", "ideal", "quente"]
const SALA_COMPORTA = 5

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
var rascunho = "if temperatura_cristal == 'fria':\n    \nelif temperatura_cristal == 'quente':\n    \nelse:\n    "
var dicas_usadas = 0
var temperatura_cristal: String = "fria"

func configurar(cena: Node):
	jogo = cena
	_sortear_temperatura()
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
	painel.add_theme_stylebox_override("panel", jogo._estilo_livro(Color("1c1730"), Color("9b6bd6"), 8))
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
	editor.custom_minimum_size = Vector2(0, 205)
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
	feedback.add_theme_color_override("font_color", Color("d6b8f5"))
	painel.hide()

func _label(coluna: Control) -> Label:
	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	coluna.add_child(label)
	return label

func _sortear_temperatura():
	temperatura_cristal = COMPORTA_TEMPERATURAS[randi() % COMPORTA_TEMPERATURAS.size()]

func _process(_delta):
	if jogo == null:
		return
	var disponivel = jogo.sala_atual == SALA_COMPORTA and jogo.player.vivo
	if not disponivel:
		painel.hide()
	dica_proximidade.text = ""
	if disponivel and not painel.visible and not jogo.mapa.comporta_aberta:
		if _perto(jogo.mapa.COMPORTA_POS):
			dica_proximidade.text = "Para estabilizar a comporta, digite\ndesafio(comporta)"
	dica_proximidade.size.x = minf(380, maxf(1, jogo.get_viewport_rect().size.x - 24))

func reiniciar():
	rascunho = "if temperatura_cristal == 'fria':\n    \nelif temperatura_cristal == 'quente':\n    \nelse:\n    "
	dicas_usadas = 0
	_sortear_temperatura()
	painel.hide()

func abrir(alvo: String) -> String:
	if painel.visible:
		return "O desafio ja esta aberto."
	if jogo.sala_atual != SALA_COMPORTA or not jogo.player.vivo:
		return "O desafio da comporta fica nas Cavernas Condicionais."
	if alvo != "comporta":
		return "Use desafio(comporta) ao lado da comporta de cristal."
	if not _perto(jogo.mapa.COMPORTA_POS):
		return "Aproxime-se: fique em uma casa ao lado da comporta e digite desafio(comporta)."
	if not jogo.player.pending_escolha.is_empty():
		return "Escolha sua runa antes de iniciar o desafio."
	pagina = 0
	_atualizar()
	painel.show()
	editor.grab_focus()
	return "Desafio aberto. Leia um passo por vez e teste seu codigo."

func comando(texto: String) -> String:
	var regex = RegEx.new()
	regex.compile("^desafio\\(\\s*(comporta)\\s*\\)$")
	var resultado = regex.search(texto)
	if resultado == null:
		return "Use desafio(comporta), ao lado da comporta."
	return abrir(resultado.get_string(1))

func _atualizar():
	editor.text = rascunho
	feedback.text = "O cristal muda de temperatura a cada tentativa. Voce pode testar quantas vezes precisar; isso nao gasta turnos nem mana."
	_atualizar_pagina()

func _paginas() -> Array:
	return [
		["1. O cristal tem tres estados", "A comporta le a temperatura de um cristal magico, guardada em temperatura_cristal.\n\nEla pode valer 'fria', 'ideal' ou 'quente'.\n\nAgora ela vale: '" + temperatura_cristal + "'"],
		["2. if / elif: mais de dois caminhos", "if temperatura_cristal == 'fria':\n    print('Preciso de mais calor')\nelif temperatura_cristal == 'quente':\n    print('Preciso de menos calor')\n\nelif e um 'senao, se': ele testa uma segunda condicao quando a primeira e falsa."],
		["3. else: o que sobra", "else:\n    abrir_comporta()\n\nSe nenhuma das condicoes acima for verdadeira, o else roda.\nComo so existem tres temperaturas, 'nao e fria e nao e quente' so pode significar 'ideal'."],
		["4. Sua vez: construa a cadeia completa", "Complete as tres acoes:\nif temperatura_cristal == 'fria': avise que precisa de mais calor\nelif temperatura_cristal == 'quente': avise que precisa de menos calor\nelse: abra a comporta\n\nComo a temperatura muda a cada tentativa, sua cadeia precisa cobrir os tres casos de uma vez, nao so o de agora. Execute para testar."]
	]

func _mudar_pagina(direcao: int):
	pagina = clampi(pagina + direcao, 0, _paginas().size() - 1)
	_atualizar_pagina()

func _atualizar_pagina():
	var paginas = _paginas()
	titulo.text = "Comporta | " + paginas[pagina][0]
	explicacao.text = paginas[pagina][1]
	pagina_texto.text = "Passo %d de %d" % [pagina + 1, paginas.size()]
	anterior.disabled = pagina == 0
	proximo.disabled = pagina == paginas.size() - 1

func _fechar():
	jogo.ia.cancelar()
	rascunho = editor.text
	painel.hide()
	jogo.input_line.grab_focus()

func _dica():
	jogo.ia.cancelar()
	dicas_usadas += 1
	feedback.text = "Cubra os tres casos: fria avisa que precisa de mais calor, quente avisa que precisa de menos calor, e qualquer outro caso (o else) abre a comporta."
	if dicas_usadas > 1:
		feedback.text = "Exemplo completo:\nif temperatura_cristal == 'fria':\n    print('Preciso de mais calor')\nelif temperatura_cristal == 'quente':\n    print('Preciso de menos calor')\nelse:\n    abrir_comporta()"

func _executar():
	jogo.ia.cancelar()
	rascunho = editor.text
	var resolvido_antes = jogo.mapa.comporta_aberta
	feedback.text = executar_codigo(editor.text)
	if not resolvido_antes:
		jogo.metricas.desafio("comporta", jogo.mapa.comporta_aberta, editor.text)
	jogo._adicionar_saida("[desafio] " + feedback.text)
	if not jogo.mapa.comporta_aberta:
		# O cristal oscila: a cadeia precisa funcionar para qualquer estado.
		_sortear_temperatura()
		_atualizar_pagina()
	var codigo = editor.text
	var resposta = feedback.text
	var contexto = "Desafio da comporta: if/elif/else cobrindo tres temperaturas. Atual: " + temperatura_cristal
	jogo.ia.solicitar(codigo, resposta, contexto, func(dica: String, gerada: bool):
		if not painel.visible or editor.text != codigo:
			return
		var rotulo = "IA" if gerada else "Dica"
		feedback.text = resposta + "\n\n" + rotulo + ": " + dica
		jogo._adicionar_saida("[" + rotulo + "] " + dica)
	)

func executar_codigo(codigo: String) -> String:
	if jogo.sala_atual != SALA_COMPORTA or not jogo.player.vivo:
		return "Este desafio esta disponivel nas Cavernas Condicionais."
	if jogo.mapa.comporta_aberta:
		return "Comporta ja estabilizada! Sua cadeia if/elif/else cobre os tres estados do cristal."

	var linhas: Array[String] = []
	for linha in codigo.replace("\r", "").split("\n"):
		if not linha.strip_edges().is_empty() and not linha.strip_edges().begins_with("#"):
			linhas.append(linha.replace("\t", "    "))

	if linhas.size() != 6:
		return "Monte 6 linhas: if condicao:, acao recuada, elif condicao:, acao recuada, else:, acao recuada."
	if not linhas[0].begins_with("if ") or not linhas[0].ends_with(":"):
		return "A primeira linha precisa comecar com if e terminar com ':'."
	if not linhas[2].begins_with("elif ") or not linhas[2].ends_with(":"):
		return "A terceira linha precisa comecar com elif e terminar com ':'."
	if linhas[4] != "else:":
		return "A quinta linha precisa ser exatamente else:."
	for indice in [1, 3, 5]:
		if not linhas[indice].begins_with("    ") or linhas[indice].begins_with("     "):
			return "Recue cada acao com 4 espacos, para mostrar a qual ramo ela pertence."

	var condicao1 = linhas[0].substr(3).trim_suffix(":").strip_edges()
	var condicao2 = linhas[2].substr(5).trim_suffix(":").strip_edges()
	var acao1 = linhas[1].strip_edges()
	var acao2 = linhas[3].strip_edges()
	var acao3 = linhas[5].strip_edges()

	var teste = preload("res://interpretador.gd").new()
	var esperado = {
		"fria": "print('Preciso de mais calor')",
		"quente": "print('Preciso de menos calor')",
		"ideal": "abrir_comporta()"
	}
	for valor in esperado.keys():
		teste.variaveis["temperatura_cristal"] = valor
		var ramo = acao1 if teste._avaliar_condicao(condicao1) else (acao2 if teste._avaliar_condicao(condicao2) else acao3)
		if _normalizar_acao(ramo) != esperado[valor]:
			teste.free()
			return "Com temperatura_cristal = '" + valor + "', sua cadeia executa '" + ramo + "' em vez de '" + esperado[valor] + "'.\nRevise as condicoes de cada ramo."
	teste.free()

	if not _perto(jogo.mapa.COMPORTA_POS):
		return "Cadeia correta para os tres estados! Fique ao lado da comporta de cristal e execute de novo."

	jogo.mapa.comporta_aberta = true
	jogo.mapa.queue_redraw()
	return "Comporta estabilizada! Sua cadeia if/elif/else responde certo para 'fria', 'quente' e 'ideal'. O caminho para o Oraculo esta aberto."

# Aceita aspas simples ou duplas e espacos dentro dos parenteses:
# print("Preciso de mais calor") == print( 'Preciso de mais calor' )
func _normalizar_acao(acao: String) -> String:
	var texto = acao.strip_edges().replace("\"", "'")
	var regex = RegEx.new()
	regex.compile("^(\\w+)\\(\\s*(.*?)\\s*\\)$")
	var r = regex.search(texto)
	if r == null:
		return texto
	return r.get_string(1) + "(" + r.get_string(2) + ")"

func _perto(pos: Vector2i) -> bool:
	var distancia: Vector2i = jogo.player.grid_pos - pos
	return absi(distancia.x) + absi(distancia.y) == 1

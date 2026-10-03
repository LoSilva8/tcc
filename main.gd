extends Node2D

@onready var input_line = $UI/PanelContainer/VBoxContainer/InputRow/InputLine
@onready var recentes = $UI/PanelContainer/VBoxContainer/InputRow/Recentes
@onready var executar_button = $UI/PanelContainer/VBoxContainer/InputRow/Executar
@onready var output_label = $UI/PanelContainer/VBoxContainer/ScrollContainer/OutputLabel
@onready var scroll = $UI/PanelContainer/VBoxContainer/ScrollContainer
@onready var hp_bar = $UI/PanelContainer/VBoxContainer/HPContainer/HPBar
@onready var hp_texto = $UI/PanelContainer/VBoxContainer/HPContainer/HPTexto
@onready var player = $Player
@onready var mapa = $Mapa
@onready var interpretador = $Interpretador
@onready var gerenciador_inimigos = $GerenciadorInimigos
@onready var tutorial = $Tutorial
@onready var debug_console = $DebugConsole
@onready var ui_root = $UI

const SALA_TUTORIAL = 0
const SALA_FLORESTA = 1
const SALA_CAVERNA = 5
const SALA_CAVERNA_CHEFE = 8
const LIMITE_HISTORICO = 5

var historico: Array = []
var historico_index: int = -1
var rascunho_terminal = ""
var sala_atual: int = 0
var fase_1_concluida: bool = false
var fase_2_concluida: bool = false
var trocando_sala: bool = false

var xp_bar: ProgressBar
var xp_texto: Label
var nivel_texto: Label
var mana_bar: ProgressBar
var mana_texto: Label
var resource_hud: PanelContainer
var levelup_panel: PanelContainer
var levelup_texto: Label
var livro_button: Button
var livro_panel: PanelContainer
var livro_texto: Label
var desafios: Node
var desafios_caverna: Node
var ia: Node

func _ready():
	ia = preload("res://feedback_ia.gd").new()
	add_child(ia)
	player.mapa = mapa
	player.gerenciador_inimigos = gerenciador_inimigos
	gerenciador_inimigos.mapa = mapa
	gerenciador_inimigos.player = player
	interpretador.player = player
	player.interpretador = interpretador
	
	player.jogador_morreu.connect(_on_jogador_morreu)
	player.hp_alterado.connect(_on_hp_alterado)
	player.mana_alterada.connect(_on_mana_alterada)
	player.chegou_na_saida.connect(_on_chegou_na_saida)
	player.xp_alterado.connect(_on_xp_alterado)
	player.nivel_up.connect(_on_nivel_up)
	tutorial.tutorial_concluido.connect(_on_tutorial_concluido)
	gerenciador_inimigos.chefe_derrotado.connect(_on_chefe_derrotado)
	
	input_line.connect("text_submitted", _on_comando_enviado)
	input_line.gui_input.connect(_on_terminal_input)
	executar_button.pressed.connect(func(): _on_comando_enviado(input_line.text))
	recentes.about_to_popup.connect(_atualizar_recentes)
	recentes.get_popup().id_pressed.connect(_selecionar_recente)
	
	_construir_hud_recursos_ui()
	_construir_levelup_ui()
	_construir_livro_magias_ui()
	desafios = preload("res://desafio_bau_porta.gd").new()
	add_child(desafios)
	desafios.configurar(self)
	desafios_caverna = preload("res://desafio_comporta.gd").new()
	add_child(desafios_caverna)
	desafios_caverna.configurar(self)
	get_viewport().size_changed.connect(_reposicionar_hud_recursos)
	
	_iniciar_sala(0)
	
	tutorial.iniciar()
	_atualizar_livro_magias()
	_adicionar_saida("[tutorial] Tutorial iniciado. Siga as instrucoes na tela.")
	_adicionar_saida("------------------------------")
	
	debug_console.configurar(self)

func _construir_hud_recursos_ui():
	var vbox = $UI/PanelContainer/VBoxContainer
	var hp_antigo = vbox.get_node_or_null("HPContainer")
	if hp_antigo:
		hp_antigo.visible = false
	
	resource_hud = PanelContainer.new()
	resource_hud.name = "ResourceHud"
	resource_hud.z_index = 26
	resource_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resource_hud.add_theme_stylebox_override("panel", _estilo_hud(Color(0.055, 0.075, 0.064, 0.92), Color(0.6, 0.82, 0.6, 0.5), 8))
	ui_root.add_child(resource_hud)
	
	var linha = HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resource_hud.add_child(linha)
	
	var hp_item = _criar_recurso_hud("HP", str(player.hp) + "/" + str(player.hp_max), Color(0.95, 0.25, 0.32), player.hp_max, player.hp)
	hp_bar = hp_item["bar"]
	hp_texto = hp_item["texto"]
	linha.add_child(hp_item["root"])
	
	var mana_item = _criar_recurso_hud("MP", str(player.mana) + "/" + str(player.mana_max), Color(0.2, 0.52, 1.0), player.mana_max, player.mana)
	mana_bar = mana_item["bar"]
	mana_texto = mana_item["texto"]
	linha.add_child(mana_item["root"])
	
	var xp_item = _criar_recurso_hud("Nv " + str(player.nivel), "XP " + str(player.xp) + "/" + str(player.xp_prox), Color(0.36, 0.76, 0.95), player.xp_prox, player.xp)
	nivel_texto = xp_item["rotulo"]
	xp_bar = xp_item["bar"]
	xp_texto = xp_item["texto"]
	linha.add_child(xp_item["root"])
	
	_reposicionar_hud_recursos()

func _criar_recurso_hud(rotulo: String, texto: String, cor: Color, maximo: float, valor: float) -> Dictionary:
	var root = VBoxContainer.new()
	root.custom_minimum_size = Vector2(92, 28)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 2)
	
	var linha_texto = HBoxContainer.new()
	linha_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha_texto.add_theme_constant_override("separation", 5)
	root.add_child(linha_texto)
	
	var rotulo_label = Label.new()
	rotulo_label.text = rotulo
	rotulo_label.custom_minimum_size = Vector2(30, 0)
	rotulo_label.add_theme_color_override("font_color", cor)
	rotulo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	rotulo_label.add_theme_constant_override("shadow_offset_x", 1)
	rotulo_label.add_theme_constant_override("shadow_offset_y", 1)
	rotulo_label.add_theme_font_size_override("font_size", 13)
	linha_texto.add_child(rotulo_label)
	
	var texto_label = Label.new()
	texto_label.text = texto
	texto_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	texto_label.add_theme_color_override("font_color", Color(0.9, 0.96, 0.94))
	texto_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	texto_label.add_theme_constant_override("shadow_offset_x", 1)
	texto_label.add_theme_constant_override("shadow_offset_y", 1)
	texto_label.add_theme_font_size_override("font_size", 13)
	linha_texto.add_child(texto_label)
	
	var barra = ProgressBar.new()
	barra.min_value = 0
	barra.max_value = maximo
	barra.value = valor
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(92, 8)
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_theme_stylebox_override("background", _estilo_barra_hud(Color(0.02, 0.025, 0.03, 0.95), Color(0.18, 0.22, 0.24, 0.65), 4))
	barra.add_theme_stylebox_override("fill", _estilo_barra_hud(cor, Color(cor.r, cor.g, cor.b, 0.65), 4))
	root.add_child(barra)
	
	return {
		"root": root,
		"rotulo": rotulo_label,
		"texto": texto_label,
		"bar": barra
	}

func _reposicionar_hud_recursos():
	if resource_hud == null:
		return
	
	resource_hud.anchor_left = 1.0
	resource_hud.anchor_right = 1.0
	resource_hud.anchor_top = 0.0
	resource_hud.anchor_bottom = 0.0
	resource_hud.offset_left = -478
	resource_hud.offset_right = -132
	resource_hud.offset_top = 12
	resource_hud.offset_bottom = 52

func _construir_levelup_ui():
	levelup_panel = PanelContainer.new()
	levelup_panel.name = "LevelUpPanel"
	levelup_panel.anchor_left = 0.5
	levelup_panel.anchor_right = 0.5
	levelup_panel.anchor_top = 0.5
	levelup_panel.anchor_bottom = 0.5
	levelup_panel.offset_left = -220
	levelup_panel.offset_right = 220
	levelup_panel.offset_top = -140
	levelup_panel.offset_bottom = 140
	levelup_panel.visible = false
	ui_root.add_child(levelup_panel)
	
	var vbox = VBoxContainer.new()
	levelup_panel.add_child(vbox)
	
	var titulo = Label.new()
	titulo.text = "VOCE SUBIU DE NIVEL!"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	titulo.add_theme_constant_override("shadow_offset_x", 1)
	titulo.add_theme_constant_override("shadow_offset_y", 1)
	titulo.add_theme_font_size_override("font_size", 20)
	vbox.add_child(titulo)
	
	levelup_texto = Label.new()
	levelup_texto.autowrap_mode = TextServer.AUTOWRAP_WORD
	levelup_texto.add_theme_color_override("font_color", Color(0.92, 0.96, 0.86))
	levelup_texto.add_theme_font_size_override("font_size", 15)
	vbox.add_child(levelup_texto)

func _construir_livro_magias_ui():
	livro_button = Button.new()
	livro_button.name = "LivroButton"
	livro_button.text = "Livro"
	livro_button.tooltip_text = "Abrir livro de magias"
	livro_button.anchor_left = 1.0
	livro_button.anchor_right = 1.0
	livro_button.anchor_top = 0.0
	livro_button.anchor_bottom = 0.0
	livro_button.offset_left = -118
	livro_button.offset_right = -14
	livro_button.offset_top = 12
	livro_button.offset_bottom = 48
	livro_button.z_index = 30
	livro_button.add_theme_stylebox_override("normal", _estilo_livro(Color(0.11, 0.16, 0.13, 0.96), Color(0.48, 0.84, 0.47, 0.72), 8))
	livro_button.add_theme_stylebox_override("hover", _estilo_livro(Color(0.15, 0.23, 0.17, 0.98), Color(0.68, 0.95, 0.56, 0.9), 8))
	livro_button.add_theme_stylebox_override("pressed", _estilo_livro(Color(0.08, 0.13, 0.1, 1.0), Color(0.34, 0.74, 0.42, 0.95), 8))
	livro_button.add_theme_color_override("font_color", Color(0.9, 1.0, 0.84))
	livro_button.add_theme_font_size_override("font_size", 15)
	livro_button.pressed.connect(_alternar_livro_magias)
	ui_root.add_child(livro_button)
	
	livro_panel = PanelContainer.new()
	livro_panel.name = "LivroPanel"
	livro_panel.visible = false
	livro_panel.anchor_left = 1.0
	livro_panel.anchor_right = 1.0
	livro_panel.anchor_top = 0.0
	livro_panel.anchor_bottom = 0.0
	livro_panel.offset_left = -374
	livro_panel.offset_right = -14
	livro_panel.offset_top = 56
	livro_panel.offset_bottom = 358
	livro_panel.z_index = 31
	livro_panel.add_theme_stylebox_override("panel", _estilo_livro(Color(0.07, 0.09, 0.075, 0.98), Color(0.55, 0.78, 0.43, 0.8), 8))
	livro_panel.add_theme_constant_override("margin_left", 14)
	livro_panel.add_theme_constant_override("margin_right", 14)
	livro_panel.add_theme_constant_override("margin_top", 12)
	livro_panel.add_theme_constant_override("margin_bottom", 12)
	ui_root.add_child(livro_panel)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	livro_panel.add_child(vbox)
	
	var topo = HBoxContainer.new()
	topo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(topo)
	
	var titulo = Label.new()
	titulo.text = "Livro de Magias"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.add_theme_color_override("font_color", Color(0.88, 1.0, 0.74))
	titulo.add_theme_font_size_override("font_size", 18)
	topo.add_child(titulo)
	
	var fechar = Button.new()
	fechar.text = "X"
	fechar.tooltip_text = "Fechar"
	fechar.custom_minimum_size = Vector2(34, 30)
	fechar.add_theme_stylebox_override("normal", _estilo_livro(Color(0.14, 0.12, 0.1, 0.94), Color(0.62, 0.46, 0.3, 0.65), 6))
	fechar.add_theme_stylebox_override("hover", _estilo_livro(Color(0.22, 0.15, 0.1, 0.98), Color(0.95, 0.68, 0.36, 0.9), 6))
	fechar.pressed.connect(_fechar_livro_magias)
	topo.add_child(fechar)
	
	var separador = HSeparator.new()
	vbox.add_child(separador)
	
	var scroll_livro = ScrollContainer.new()
	scroll_livro.custom_minimum_size = Vector2(0, 224)
	scroll_livro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_livro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll_livro)
	
	livro_texto = Label.new()
	livro_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	livro_texto.autowrap_mode = TextServer.AUTOWRAP_WORD
	livro_texto.add_theme_color_override("font_color", Color(0.82, 0.92, 0.78))
	livro_texto.add_theme_font_size_override("font_size", 14)
	scroll_livro.add_child(livro_texto)
	
	_atualizar_livro_magias()

func _alternar_livro_magias():
	livro_panel.visible = not livro_panel.visible
	_atualizar_livro_magias()
	input_line.grab_focus()

func _fechar_livro_magias():
	livro_panel.visible = false
	input_line.grab_focus()

func _atualizar_livro_magias():
	if livro_texto == null:
		return
	
	livro_texto.text = _texto_livro_magias()

func _texto_livro_magias() -> String:
	var linhas: Array = []
	linhas.append("Comandos liberados ate agora")
	linhas.append("")
	
	_adicionar_comando_livro(linhas, "mover('direita')", "Move 1 casa. Direcoes: direita, esquerda, cima, baixo.", true)
	_adicionar_comando_livro(linhas, "atacar('direita')", "Ataca o inimigo na casa ao lado.", _comando_aprendido_na_etapa(2))
	_adicionar_comando_livro(linhas, "poder = 3", "Cria uma variavel chamada poder e guarda um numero nela.", _comando_aprendido_na_etapa(6))
	_adicionar_comando_livro(linhas, "fireball(poder, 'direita')", "Lanca magia em linha reta. Custa 2 MP + valor de poder.", _comando_aprendido_na_etapa(7))
	
	if player and not player.pending_escolha.is_empty():
		_adicionar_comando_livro(linhas, "escolher(1)", "Escolhe uma runa quando voce sobe de nivel.", true)
	
	if sala_atual == SALA_FLORESTA:
		linhas.append("Fase 1")
		linhas.append("  Ao lado do objeto, digite desafio(bau) ou desafio(porta).")
		linhas.append("  selos = 3 guarda um numero; abrir_bau(selos) usa esse numero.")
		linhas.append("  if tem_chave == True: escolhe a acao com chave; else: trata a falta dela.")
		linhas.append("  abrir_porta() e print('Preciso da chave') sao as acoes do desafio.")
		linhas.append("  O Guardiao da Saida so recebe dano se voce estiver na arena marcada.")
		linhas.append("")
	
	if _em_caverna():
		linhas.append("Fase 2")
		linhas.append("  if cond: acao   roda a acao so se cond for verdadeira.")
		linhas.append("  elif cond: acao   testa outra condicao quando a anterior e falsa.")
		linhas.append("  else: acao   roda quando nenhuma condicao anterior foi verdadeira.")
		linhas.append("  Em uma linha: if a: x elif b: y else: z")
		linhas.append("  and / or combinam condicoes: if hp < 5 and mana > 2: ...")
		linhas.append("  fogo = 3  e depois  fireball(fogo, 'direita')  usa o elemento fogo.")
		if sala_atual == SALA_CAVERNA:
			linhas.append("  Ao lado da comporta, digite desafio(comporta).")
		if sala_atual == SALA_CAVERNA_CHEFE:
			linhas.append("  sinal_oraculo guarda o elemento que o Oraculo aceita agora.")
		linhas.append("")
	
	linhas.append("")
	linhas.append("Sistema")
	linhas.append("  reiniciar()")
	linhas.append("  Recomeca a run desde o tutorial.")
	linhas.append("")
	linhas.append("Novos comandos aparecem aqui quando forem ensinados.")
	return "\n".join(linhas)

func _adicionar_comando_livro(linhas: Array, comando: String, descricao: String, liberado: bool):
	if not liberado:
		return
	
	linhas.append("  " + comando)
	linhas.append("  " + descricao)
	linhas.append("")

func _comando_aprendido_na_etapa(etapa_minima: int) -> bool:
	if tutorial == null:
		return false
	if not tutorial.esta_ativo():
		return true
	
	return tutorial.etapa_atual >= etapa_minima

func _estilo_livro(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _estilo_hud(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _estilo_barra_hud(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _on_xp_alterado(xp_atual, xp_prox, nivel):
	if xp_bar:
		xp_bar.max_value = xp_prox
		xp_bar.value = xp_atual
	if xp_texto:
		xp_texto.text = "XP " + str(xp_atual) + "/" + str(xp_prox)
	if nivel_texto:
		nivel_texto.text = "Nv " + str(nivel)

func _on_nivel_up(opcoes: Array):
	var texto = "Escolha uma runa digitando escolher(numero) no terminal:\n\n"
	for i in range(opcoes.size()):
		var op = opcoes[i]
		texto += str(i + 1) + ") " + op["nome"] + "\n   " + op["desc"] + "\n\n"
	levelup_texto.text = texto
	levelup_panel.visible = true
	_atualizar_livro_magias()
	_adicionar_saida("[nivel] Voce subiu de nivel! Escolha uma runa: escolher(1), escolher(2) ou escolher(3)")
	_adicionar_saida("------------------------------")

func _atualizar_levelup_visibilidade():
	if levelup_panel and levelup_panel.visible and player.pending_escolha.is_empty():
		levelup_panel.visible = false
	_atualizar_livro_magias()

func _iniciar_sala(indice: int):
	ia.cancelar()
	trocando_sala = false
	sala_atual = indice
	mapa.carregar_sala(indice)
	if desafios:
		desafios.reiniciar()
	if desafios_caverna:
		desafios_caverna.reiniciar()
	player.grid_pos = Vector2i(1, 1)
	player._sincronizar_posicao()
	
	if indice == SALA_FLORESTA:
		fase_1_concluida = false
		player.curar_total()
	
	if indice == SALA_CAVERNA:
		fase_2_concluida = false
		player.curar_total()
	
	if indice == SALA_CAVERNA_CHEFE:
		player.curar_total()
	
	for filho in gerenciador_inimigos.get_children():
		filho.queue_free()
	gerenciador_inimigos.inimigos.clear()
	
	await get_tree().process_frame
	_spawnar_inimigos_sala()
	
	if indice == 4:
		_adicionar_saida("[chefe] O Guardiao de Runas bloqueia a saida do bioma!")
		_adicionar_saida("Cada parte exige uma variavel com nome especifico (veja acima dele).")
		_adicionar_saida("Use: nome = valor  e depois  fireball(nome, 'direcao')")
		_adicionar_saida("------------------------------")
	
	if indice == SALA_CAVERNA:
		_anunciar_fase_2()
	elif indice > SALA_CAVERNA and indice < SALA_CAVERNA_CHEFE:
		_adicionar_saida("[fase 2] Galeria " + str(indice - SALA_CAVERNA) + " das Cavernas")
		_adicionar_saida("Mais Ecos elementais. Derrote todos para liberar a saida.")
		_adicionar_saida("------------------------------")
	elif indice == SALA_CAVERNA_CHEFE:
		_anunciar_chefe_caverna()
	
	_sincronizar_sinal_oraculo()

func _spawnar_inimigos_sala():
	if sala_atual == SALA_TUTORIAL:
		gerenciador_inimigos.spawnar_inimigo(Vector2i(3, 2))
		gerenciador_inimigos.spawnar_inimigo_escudo(Vector2i(5, 3), 1)
		return
	
	if sala_atual == SALA_FLORESTA:
		gerenciador_inimigos.spawnar_inimigo(Vector2i(6, 1))
		gerenciador_inimigos.spawnar_inimigo(Vector2i(7, 3))
		gerenciador_inimigos.spawnar_inimigo(Vector2i(4, 6))
		gerenciador_inimigos.spawnar_inimigo_escudo(Vector2i(6, 5), 2)
		gerenciador_inimigos.spawnar_inimigo_escudo(Vector2i(1, 6), 2)
		gerenciador_inimigos.spawnar_boss_saida(Vector2i(10, 7), mapa.area_boss_saida_inicio(), mapa.area_boss_saida_tamanho())
		return
	
	if sala_atual == 4:
		gerenciador_inimigos.spawnar_chefe(Vector2i(4, 3))
		return
	
	if sala_atual == SALA_CAVERNA:
		# Primeiro contato: elementos fixos e HP baixo (1 fireball com poder = 3)
		gerenciador_inimigos.spawnar_inimigo_elemental(Vector2i(3, 2), 3, "fogo")
		gerenciador_inimigos.spawnar_inimigo_elemental(Vector2i(4, 6), 3, "gelo")
		return
	
	if sala_atual == 6:
		gerenciador_inimigos.spawnar_inimigo_elemental(Vector2i(7, 2), 4)
		gerenciador_inimigos.spawnar_inimigo_elemental(Vector2i(3, 4), 4)
		gerenciador_inimigos.spawnar_inimigo_escudo(Vector2i(5, 5), 2)
		return
	
	if sala_atual == 7:
		gerenciador_inimigos.spawnar_inimigo_elemental(Vector2i(6, 1), 4)
		gerenciador_inimigos.spawnar_inimigo_elemental(Vector2i(3, 5), 4)
		gerenciador_inimigos.spawnar_inimigo_escudo(Vector2i(7, 4), 2)
		return
	
	if sala_atual == SALA_CAVERNA_CHEFE:
		gerenciador_inimigos.spawnar_chefe_caverna(Vector2i(4, 3))
		return
	
	var quantidade = min(sala_atual, 4)
	var tentativas = 0
	var spawnados = 0
	
	while spawnados < quantidade and tentativas < 50:
		tentativas += 1
		var x = randi_range(1, 7)
		var y = randi_range(1, 5)
		var pos = Vector2i(x, y)
		
		if not mapa.eh_parede(pos) and pos != mapa.saida_pos and pos != Vector2i(1, 1):
			gerenciador_inimigos.spawnar_inimigo(pos)
			spawnados += 1

func _on_tutorial_concluido():
	player.xp_habilitado = true
	_atualizar_livro_magias()
	_adicionar_saida("[ok] Tutorial concluido. A Fase 1 comeca na proxima sala.")
	_adicionar_saida("------------------------------")

func _on_chefe_derrotado():
	if sala_atual == SALA_CAVERNA_CHEFE:
		interpretador.variaveis.erase("sinal_oraculo")
		_adicionar_saida("[chefe] O Oraculo Bifurcado foi silenciado! A saida esta livre.")
	else:
		_adicionar_saida("[chefe] O Guardiao de Runas foi destruido! A saida esta livre.")
	_adicionar_saida("------------------------------")

func _on_chegou_na_saida():
	if trocando_sala:
		return
	if tutorial.esta_ativo():
		_adicionar_saida("[tutorial] Saida encontrada. Preparando a Fase 1...")
		_adicionar_saida("------------------------------")
		await get_tree().create_timer(0.8).timeout
		await _iniciar_sala(SALA_FLORESTA)
		_anunciar_fase_1()
		return
	
	if sala_atual == SALA_FLORESTA:
		if gerenciador_inimigos.boss_saida_vivo():
			_adicionar_saida("[boss] O Guardiao da Saida ainda protege a passagem.")
			_adicionar_saida("Entre na area marcada e derrote o boss antes de sair.")
			_adicionar_saida("------------------------------")
			return
		
		if gerenciador_inimigos.tem_inimigos_vivos():
			_adicionar_saida("[fase 1] A saida esta bloqueada pelas criaturas da floresta.")
			_adicionar_saida("Derrote os inimigos antes de sair.")
			_adicionar_saida("------------------------------")
			return
		
		_concluir_fase_1()
		return
	
	if sala_atual == 4 and gerenciador_inimigos.chefe_vivo():
		_adicionar_saida("[chefe] O Guardiao de Runas ainda protege a saida!")
		_adicionar_saida("Derrote-o primeiro.")
		_adicionar_saida("------------------------------")
		return
	
	if sala_atual == SALA_CAVERNA_CHEFE:
		if gerenciador_inimigos.chefe_caverna_vivo():
			_adicionar_saida("[chefe] O Oraculo Bifurcado ainda ecoa pela sala!")
			_adicionar_saida("Derrote-o primeiro.")
			_adicionar_saida("------------------------------")
			return
		_concluir_fase_2()
		return
	
	if _em_caverna() and gerenciador_inimigos.tem_inimigos_vivos():
		_adicionar_saida("[fase 2] Os Ecos ainda ecoam pela caverna.")
		_adicionar_saida("Derrote-os antes de avancar.")
		_adicionar_saida("------------------------------")
		return
	
	_adicionar_saida("[sala] Sala " + str(sala_atual + 1) + " concluida!")
	_adicionar_saida("Carregando proxima sala...")
	_adicionar_saida("------------------------------")
	trocando_sala = true
	await get_tree().create_timer(0.8).timeout
	_iniciar_sala(sala_atual + 1)
	_adicionar_saida("[mapa] Sala " + str(sala_atual + 1))
	_adicionar_saida("------------------------------")

func _anunciar_fase_1():
	_adicionar_saida("[fase 1] Clareira da Floresta")
	_adicionar_saida("Procure o bau dourado no abrigo ao sul. A chave abre a porta azul que leva ao boss.")
	_adicionar_saida("Ao lado de cada objeto, uma dica mostra o comando: desafio(bau) ou desafio(porta).")
	_adicionar_saida("Aprenda a guardar um numero e a decidir com if/else. Ha exemplos e dicas, sem perder turnos nas tentativas.")
	_adicionar_saida("Objetivo: derrote os inimigos, venca o Guardiao da Saida e chegue a saida verde.")
	_adicionar_saida("Cada comando valido e um turno. Depois dele, os inimigos tambem agem.")
	_adicionar_saida("O boss so pode ser atacado dentro da area marcada perto da saida.")
	_adicionar_saida("Fireball custa 2 MP + o valor da variavel usada como poder.")
	_adicionar_saida("Use mover('direcao'), atacar('direcao') e fireball(poder, 'direcao').")
	_adicionar_saida("------------------------------")

func _concluir_fase_1():
	if fase_1_concluida:
		return
	
	fase_1_concluida = true
	_adicionar_saida("[fase 1] Clareira da Floresta concluida!")
	_adicionar_saida("Voce venceu a primeira fase usando comandos Python.")
	_adicionar_saida("Uma fenda de cristal se abre no chao... descendo para as Cavernas Condicionais.")
	_adicionar_saida("------------------------------")
	trocando_sala = true
	await get_tree().create_timer(1.2).timeout
	if sala_atual == SALA_FLORESTA and player.vivo:
		await _iniciar_sala(SALA_CAVERNA)
	else:
		trocando_sala = false

func _anunciar_fase_2():
	_adicionar_saida("[fase 2] Encruzilhada das Cavernas")
	_adicionar_saida("Uma comporta de cristal roxa bloqueia o unico caminho para a saida.")
	_adicionar_saida("Fique ao lado dela e digite desafio(comporta): ela exige if / elif / else.")
	_adicionar_saida("Ecos elementais so caem com fireball do elemento escrito embaixo deles.")
	_adicionar_saida("Crie uma variavel com o nome do elemento: fogo = 3  e depois  fireball(fogo, 'direcao').")
	_adicionar_saida("Ataques comuns atravessam os Ecos.")
	_adicionar_saida("------------------------------")

func _anunciar_chefe_caverna():
	_adicionar_saida("[chefe] O Oraculo Bifurcado desperta no nucleo da caverna!")
	_adicionar_saida("Ele esta preso ao cristal e nao se move, mas fere quem chega perto.")
	_adicionar_saida("A cada ataque o sinal dele muda. O sinal atual fica guardado em sinal_oraculo.")
	_adicionar_saida("Tenha fogo, gelo e arcano definidos (ex.: fogo = 3) e use fireball com o elemento do sinal.")
	_adicionar_saida("Na ultima fase o sinal fica oculto: so uma linha if / elif / else o derrota.")
	_adicionar_saida("------------------------------")

func _concluir_fase_2():
	if fase_2_concluida:
		return
	
	fase_2_concluida = true
	_adicionar_saida("[fase 2] Cavernas Condicionais concluidas!")
	_adicionar_saida("Sua cadeia if / elif / else respondeu a todos os sinais do Oraculo.")
	_adicionar_saida("Fim da versao jogavel desta etapa.")
	_adicionar_saida("------------------------------")

func _on_terminal_input(event):
	if event is InputEventKey and event.pressed:
		if event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			input_line.accept_event()
			return
		if event.keycode == KEY_UP:
			if historico.size() > 0:
				if historico_index >= historico.size():
					rascunho_terminal = input_line.text
				historico_index = max(historico_index - 1, 0)
				input_line.text = historico[historico_index]
				input_line.caret_column = input_line.text.length()
				input_line.select_all()
			input_line.accept_event()
		elif event.keycode == KEY_DOWN:
			if historico_index < historico.size() - 1:
				historico_index += 1
				input_line.text = historico[historico_index]
				input_line.caret_column = input_line.text.length()
			else:
				historico_index = historico.size()
				input_line.text = rascunho_terminal
			input_line.caret_column = input_line.text.length()
			input_line.select_all()
			input_line.accept_event()

func _atualizar_recentes():
	var popup = recentes.get_popup()
	popup.clear()
	for i in range(historico.size() - 1, -1, -1):
		var comando = str(historico[i])
		popup.add_item(comando if comando.length() <= 48 else comando.left(45) + "...", i)
		popup.set_item_tooltip(popup.item_count - 1, comando)
	if popup.item_count == 0:
		popup.add_item("Nenhum comando enviado")
		popup.set_item_disabled(0, true)

func _selecionar_recente(indice: int):
	if indice < 0 or indice >= historico.size():
		return
	input_line.text = historico[indice]
	historico_index = historico.size()
	rascunho_terminal = input_line.text
	input_line.grab_focus()
	input_line.select_all()

func _registrar_comando(texto: String):
	historico.erase(texto)
	historico.append(texto)
	if historico.size() > LIMITE_HISTORICO:
		historico.pop_front()
	historico_index = historico.size()
	rascunho_terminal = ""

func _preparar_proximo_comando():
	input_line.clear()
	historico_index = historico.size()
	rascunho_terminal = ""
	input_line.grab_focus()

func _on_comando_enviado(texto: String):
	if desafios and desafios.painel.visible:
		return
	if desafios_caverna and desafios_caverna.painel.visible:
		return
	texto = texto.strip_edges()
	if texto == "":
		return
	ia.cancelar()
	
	if texto == "reiniciar()":
		_reiniciar_run()
		return
	_registrar_comando(texto)
	if texto.begins_with("desafio"):
		_adicionar_saida(">>> " + texto)
		var gerenciador_desafio = desafios_caverna if sala_atual == SALA_CAVERNA else desafios
		_adicionar_saida(gerenciador_desafio.comando(texto))
		input_line.clear()
		if not gerenciador_desafio.painel.visible:
			input_line.grab_focus()
		return
	
	if tutorial.esta_ativo():
		_adicionar_saida(">>> " + texto)
		var resposta = interpretador.executar(texto)
		if resposta != "":
			_adicionar_saida(resposta)
		
		tutorial.verificar_comando(texto, resposta)
		_pedir_feedback_erro(texto, resposta)
		_atualizar_livro_magias()
		if _deve_contar_rodada(resposta):
			_recuperar_mana_fim_rodada()
		
		_adicionar_saida("------------------------------")
		_preparar_proximo_comando()
		return
	
	_adicionar_saida(">>> " + texto)
	var escolha_pendente_antes = not player.pending_escolha.is_empty()
	var resposta = interpretador.executar(texto)
	if resposta != "":
		_adicionar_saida(resposta)
	_atualizar_levelup_visibilidade()
	_processar_turno_pos_jogador(resposta, escolha_pendente_antes)
	_sincronizar_sinal_oraculo()
	_pedir_feedback_erro(texto, resposta)
	_adicionar_saida("------------------------------")
	_preparar_proximo_comando()

func _pedir_feedback_erro(codigo: String, resposta: String):
	if not player.vivo or not ia.eh_erro(resposta):
		return
	var contexto = "Fase %d; mana %d/%d." % [sala_atual, player.mana, player.mana_max]
	if tutorial.esta_ativo():
		contexto += " Tutorial: " + str(tutorial.etapas[tutorial.etapa_atual]["titulo"])
	ia.solicitar(codigo, resposta, contexto, func(dica: String, gerada: bool):
		var rotulo = "IA" if gerada else "Dica"
		_adicionar_saida("[" + rotulo + "] " + dica)
		if tutorial.esta_ativo():
			tutorial.dica_label.text = rotulo + ": " + dica
			tutorial.dica_label.visible = true
	)

func _processar_turno_pos_jogador(resposta_jogador: String, escolha_pendente_antes: bool = false):
	if not _deve_contar_rodada(resposta_jogador, escolha_pendente_antes):
		return
	
	if _deve_processar_turno_inimigos():
		var resposta_inimigos = gerenciador_inimigos.processar_turno_inimigos()
		if resposta_inimigos != "":
			_adicionar_saida(resposta_inimigos)
	
	_atualizar_levelup_visibilidade()
	
	_recuperar_mana_fim_rodada()
	
	if sala_atual == SALA_FLORESTA and not fase_1_concluida:
		if player.grid_pos == mapa.saida_pos and not gerenciador_inimigos.tem_inimigos_vivos():
			_concluir_fase_1()
	
	if sala_atual == SALA_CAVERNA_CHEFE and not fase_2_concluida:
		if player.grid_pos == mapa.saida_pos and not gerenciador_inimigos.chefe_caverna_vivo():
			_concluir_fase_2()

func _recuperar_mana_fim_rodada():
	var resposta_mana = player.recuperar_mana_rodada()
	if resposta_mana != "":
		_adicionar_saida(resposta_mana)

func _deve_processar_turno_inimigos() -> bool:
	if not player.vivo or not player.pending_escolha.is_empty():
		return false
	if trocando_sala:
		return false
	if sala_atual == SALA_FLORESTA:
		return not fase_1_concluida
	if _em_caverna():
		return not fase_2_concluida
	return false

func _em_caverna() -> bool:
	return sala_atual >= SALA_CAVERNA and sala_atual <= SALA_CAVERNA_CHEFE

# Rodadas (recuperacao de mana) valem enquanto a fase atual nao terminou.
# Antes, qualquer sala depois da floresta ficava sem rodadas.
func _rodadas_ativas() -> bool:
	if _em_caverna():
		return not fase_2_concluida
	return not fase_1_concluida

func _sincronizar_sinal_oraculo():
	var sinal = gerenciador_inimigos.sinal_chefe_caverna()
	if sinal == "":
		interpretador.variaveis.erase("sinal_oraculo")
	else:
		interpretador.variaveis["sinal_oraculo"] = sinal

func _deve_contar_rodada(resposta_jogador: String, escolha_pendente_antes: bool = false) -> bool:
	if not _rodadas_ativas():
		return false
	if not player.vivo:
		return false
	if escolha_pendente_antes:
		return false
	
	var resposta = resposta_jogador.to_lower()
	if resposta == "":
		return false
	if resposta.begins_with("erro"):
		return false
	if resposta.begins_with("bloqueado"):
		return false
	if "comando nao reconhecido" in resposta:
		return false
	if "direcao invalida" in resposta:
		return false
	if "nao foi definida" in resposta:
		return false
	if "precisa de uma variavel numerica" in resposta:
		return false
	if "mana insuficiente" in resposta:
		return false
	if "foi substituido por fireball" in resposta:
		return false
	if "ha uma parede" in resposta:
		return false
	if "falsa" in resposta and "nenhuma" in resposta:
		return false
	if "nao ha escolhas pendentes" in resposta:
		return false
	if "escolha invalida" in resposta:
		return false
	if "escolha uma runa" in resposta or "voce escolheu" in resposta:
		return false
	
	return true

func _on_jogador_morreu():
	ia.cancelar()
	_adicionar_saida("[run] Run encerrada. Voce chegou ate a sala " + str(sala_atual + 1) + ".")
	_adicionar_saida("Digite reiniciar() para tentar novamente.")
	_adicionar_saida("------------------------------")

func _on_hp_alterado(hp_atual: int, hp_max: int):
	hp_bar.max_value = hp_max
	hp_bar.value = hp_atual
	hp_texto.text = str(hp_atual) + "/" + str(hp_max)

func _on_mana_alterada(mana_atual: int, mana_maximo: int):
	if mana_bar:
		mana_bar.max_value = mana_maximo
		mana_bar.value = mana_atual
	if mana_texto:
		mana_texto.text = str(mana_atual) + "/" + str(mana_maximo)

func _reiniciar_run():
	historico.clear()
	historico_index = 0
	rascunho_terminal = ""
	fase_1_concluida = false
	fase_2_concluida = false
	trocando_sala = false
	player.resetar()
	interpretador.variaveis.clear()
	output_label.text = ""
	await get_tree().process_frame
	_iniciar_sala(0)
	tutorial.iniciar()
	_atualizar_livro_magias()
	levelup_panel.visible = false
	_adicionar_saida("[run] Nova run iniciada.")
	_adicionar_saida("------------------------------")
	input_line.clear()
	input_line.grab_focus()

func _adicionar_saida(linha: String):
	if linha == "------------------------------":
		return
	var barra = scroll.get_v_scroll_bar()
	var acompanhar = barra.value >= barra.max_value - barra.page - 2 or linha.begins_with(">>> ")
	output_label.text += linha + "\n"
	await get_tree().process_frame
	if acompanhar:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

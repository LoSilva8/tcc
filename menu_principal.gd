extends CanvasLayer

# Menu principal (RF001). Comeca um jogo novo ou continua o progresso salvo a
# partir de qualquer bioma ja liberado (RF015, RF019, US03).

const Design = preload("res://design.gd")

var main_ref: Node
var continuar_box: VBoxContainer
var continuar_label: Label
var biomas_buttons: Array = []
var novo_jogo_button: Button
var participante_edit: LineEdit
var aviso_label: Label
var confirmando_novo_jogo = false

func configurar(main: Node):
	main_ref = main
	layer = 50  # acima da UI do jogo, abaixo do console de debug
	_construir_ui()

func _construir_ui():
	var fundo = ColorRect.new()
	fundo.name = "MenuFundo"
	fundo.color = Color(0.03, 0.04, 0.05, 0.94)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	var centro = CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)

	var painel = PanelContainer.new()
	painel.custom_minimum_size = Vector2(460, 0)
	var estilo_painel = _estilo(Design.PANEL, Design.STROKE)
	estilo_painel.content_margin_left = 28
	estilo_painel.content_margin_right = 28
	estilo_painel.content_margin_top = 24
	estilo_painel.content_margin_bottom = 24
	painel.add_theme_stylebox_override("panel", estilo_painel)
	centro.add_child(painel)

	var coluna = VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	painel.add_child(coluna)

	var titulo = Label.new()
	titulo.text = "PyAdventure"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 40)
	titulo.add_theme_color_override("font_color", Design.ACCENT)
	coluna.add_child(titulo)

	var subtitulo = Label.new()
	subtitulo.text = "Na Grande Biblioteca de Sintaxe, programar e conjurar. Escreva Python para guiar o mago."
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitulo.add_theme_color_override("font_color", Design.MUTED)
	coluna.add_child(subtitulo)

	coluna.add_child(HSeparator.new())

	# Validacao (secao 4.4 do TCC): o avaliador digita so um codigo, nunca o nome.
	var linha_participante = HBoxContainer.new()
	linha_participante.add_theme_constant_override("separation", 8)
	coluna.add_child(linha_participante)
	var rotulo_participante = Label.new()
	rotulo_participante.text = "Participante:"
	rotulo_participante.add_theme_color_override("font_color", Design.MUTED)
	linha_participante.add_child(rotulo_participante)
	participante_edit = LineEdit.new()
	participante_edit.placeholder_text = "codigo, ex.: P01 (opcional)"
	participante_edit.max_length = 20
	participante_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha_participante.add_child(participante_edit)

	continuar_box = VBoxContainer.new()
	continuar_box.add_theme_constant_override("separation", 6)
	coluna.add_child(continuar_box)

	continuar_label = Label.new()
	continuar_label.text = "Continuar a partir de:"
	continuar_label.add_theme_color_override("font_color", Design.TEXT)
	continuar_box.add_child(continuar_label)

	for i in range(main_ref.BIOMAS.size()):
		var botao = _botao("")
		botao.pressed.connect(func(): main_ref.continuar(i))
		continuar_box.add_child(botao)
		biomas_buttons.append(botao)

	continuar_box.add_child(HSeparator.new())

	novo_jogo_button = _botao("Novo jogo")
	novo_jogo_button.pressed.connect(_on_novo_jogo)
	coluna.add_child(novo_jogo_button)

	aviso_label = Label.new()
	aviso_label.visible = false
	aviso_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso_label.add_theme_color_override("font_color", Design.WARNING)
	coluna.add_child(aviso_label)

	var sair = _botao("Sair")
	sair.pressed.connect(func(): get_tree().quit())
	coluna.add_child(sair)

	var pasta = Button.new()
	pasta.text = "Abrir pasta das metricas"
	pasta.flat = true
	pasta.add_theme_color_override("font_color", Design.MUTED)
	pasta.pressed.connect(_abrir_pasta_metricas)
	coluna.add_child(pasta)

func codigo_participante() -> String:
	return participante_edit.text.strip_edges()

func _abrir_pasta_metricas():
	var pasta = main_ref.metricas.pasta
	DirAccess.make_dir_recursive_absolute(pasta)
	OS.shell_open(ProjectSettings.globalize_path(pasta))

func abrir():
	atualizar()
	visible = true
	main_ref.input_line.release_focus()
	for botao in biomas_buttons + [novo_jogo_button]:
		if botao.is_visible_in_tree() and not botao.disabled:
			botao.grab_focus()
			break

func fechar():
	visible = false

func atualizar():
	var progresso = main_ref.progresso
	confirmando_novo_jogo = false
	novo_jogo_button.text = "Novo jogo"
	aviso_label.visible = false
	continuar_box.visible = progresso.tem_progresso()
	continuar_label.text = "Voce concluiu PyAdventure! Pratique a partir de:" if progresso.jogo_concluido else "Continuar a partir de:"
	for i in range(biomas_buttons.size()):
		var nome = main_ref.BIOMAS[i]["nome"]
		var liberado = i <= progresso.bioma_liberado
		biomas_buttons[i].disabled = not liberado
		biomas_buttons[i].text = nome if liberado else nome + "  (conclua o bioma anterior)"

# Com progresso salvo, o primeiro clique so avisa: o segundo apaga e recomeca.
func _on_novo_jogo():
	if main_ref.progresso.tem_progresso() and not confirmando_novo_jogo:
		confirmando_novo_jogo = true
		novo_jogo_button.text = "Confirmar novo jogo"
		aviso_label.text = "Isso apaga o progresso salvo: biomas e conceitos liberados voltam ao inicio."
		aviso_label.visible = true
		return
	main_ref.novo_jogo()

func _botao(texto: String) -> Button:
	var botao = Button.new()
	botao.text = texto
	botao.custom_minimum_size = Vector2(0, 40)
	botao.add_theme_font_size_override("font_size", 16)
	botao.add_theme_color_override("font_color", Design.TEXT)
	botao.add_theme_color_override("font_disabled_color", Design.MUTED)
	botao.add_theme_stylebox_override("normal", _estilo(Design.PANEL_ALT, Color(Design.STROKE, 0.35)))
	botao.add_theme_stylebox_override("hover", _estilo(Color(0.15, 0.2, 0.22), Design.ACCENT))
	botao.add_theme_stylebox_override("pressed", _estilo(Color(0.07, 0.12, 0.12), Design.ACCENT))
	botao.add_theme_stylebox_override("focus", _estilo(Color(0, 0, 0, 0), Design.ACCENT))
	botao.add_theme_stylebox_override("disabled", _estilo(Color(0.08, 0.09, 0.1, 0.9), Color(Design.MUTED, 0.25)))
	return botao

func _estilo(bg: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

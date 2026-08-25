extends CanvasLayer

var main_ref: Node = null
var painel: PanelContainer
var input: LineEdit
var log_label: Label
var visivel: bool = false

func _ready():
	layer = 100  # sempre por cima de tudo
	_construir_ui()
	painel.visible = false

func configurar(main: Node):
	main_ref = main

func _construir_ui():
	painel = PanelContainer.new()
	painel.anchor_left = 0.0
	painel.anchor_right = 1.0
	painel.anchor_top = 0.0
	painel.offset_bottom = 160
	add_child(painel)
	
	var vbox = VBoxContainer.new()
	painel.add_child(vbox)
	
	var titulo = Label.new()
	titulo.text = "[DEBUG CONSOLE] F1 para fechar | Comandos: spawn, sala, tutorial_skip, hp, ajuda"
	titulo.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	vbox.add_child(titulo)
	
	log_label = Label.new()
	log_label.text = "Console de debug pronto. Digite 'ajuda' para ver comandos."
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(log_label)
	
	input = LineEdit.new()
	input.placeholder_text = "comando de debug..."
	input.text_submitted.connect(_on_comando)
	vbox.add_child(input)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		visivel = not visivel
		painel.visible = visivel
		if visivel:
			input.grab_focus()
		get_viewport().set_input_as_handled()

func _on_comando(texto: String):
	texto = texto.strip_edges()
	if texto == "":
		return
	
	var resposta = _executar(texto)
	log_label.text = "> " + texto + "\n" + resposta
	input.clear()
	input.grab_focus()

func _executar(comando: String) -> String:
	var partes = comando.split(" ")
	var cmd = partes[0]
	
	match cmd:
		"ajuda":
			return "Comandos:\n" + \
				"  sala <n>          - vai direto para a sala n (0-4)\n" + \
				"  spawn <tipo> <x> <y> - spawna inimigo (normal/escudo/chefe)\n" + \
				"  tutorial_skip      - pula o tutorial\n" + \
				"  hp <n>             - define HP do jogador\n" + \
				"  matar_tudo         - remove todos os inimigos da sala\n" + \
				"  var <nome> <valor> - cria variavel no interpretador\n" + \
				"  pos <x> <y>        - teleporta o jogador"
		
		"sala":
			if partes.size() < 2:
				return "Uso: sala <numero>"
			var n = int(partes[1])
			main_ref._iniciar_sala(n)
			return "Indo para sala " + str(n)
		
		"spawn":
			if partes.size() < 4:
				return "Uso: spawn <normal|escudo|chefe> <x> <y>"
			var tipo = partes[1]
			var x = int(partes[2])
			var y = int(partes[3])
			var pos = Vector2i(x, y)
			
			match tipo:
				"normal":
					main_ref.gerenciador_inimigos.spawnar_inimigo(pos)
					return "Inimigo normal spawnado em " + str(pos)
				"escudo":
					main_ref.gerenciador_inimigos.spawnar_inimigo_escudo(pos)
					return "Inimigo com escudo spawnado em " + str(pos)
				"chefe":
					main_ref.gerenciador_inimigos.spawnar_chefe(pos)
					return "Chefe spawnado em " + str(pos)
				_:
					return "Tipo invalido. Use: normal, escudo ou chefe"
		
		"tutorial_skip":
			main_ref.tutorial.ativo = false
			main_ref.tutorial.tutorial_box.visible = false
			return "Tutorial pulado."
		
		"hp":
			if partes.size() < 2:
				return "Uso: hp <numero>"
			var n = int(partes[1])
			main_ref.player.hp = n
			main_ref.player.emit_signal("hp_alterado", n, main_ref.player.hp_max)
			return "HP definido para " + str(n)
		
		"matar_tudo":
			for filho in main_ref.gerenciador_inimigos.get_children():
				filho.queue_free()
			main_ref.gerenciador_inimigos.inimigos.clear()
			return "Todos os inimigos removidos."
		
		"var":
			if partes.size() < 3:
				return "Uso: var <nome> <valor>"
			var nome = partes[1]
			var valor_str = partes[2]
			var valor = valor_str.to_int() if valor_str.is_valid_int() else valor_str
			main_ref.interpretador.variaveis[nome] = valor
			return "Variavel '" + nome + "' definida como " + str(valor)
		
		"pos":
			if partes.size() < 3:
				return "Uso: pos <x> <y>"
			var x = int(partes[1])
			var y = int(partes[2])
			main_ref.player.grid_pos = Vector2i(x, y)
			main_ref.player._sincronizar_posicao()
			return "Jogador teleportado para (" + str(x) + ", " + str(y) + ")"
		
		_:
			return "Comando desconhecido. Digite 'ajuda' para ver a lista."

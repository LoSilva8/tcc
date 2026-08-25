extends Node2D

@onready var input_line = $UI/PanelContainer/VBoxContainer/InputLine
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

var historico: Array = []
var historico_index: int = -1
var sala_atual: int = 0

func _ready():
	debug_console.configurar(self)
	player.mapa = mapa
	player.gerenciador_inimigos = gerenciador_inimigos
	gerenciador_inimigos.mapa = mapa
	interpretador.player = player
	player.interpretador = interpretador
	gerenciador_inimigos.chefe_derrotado.connect(_on_chefe_derrotado)
	
	player.jogador_morreu.connect(_on_jogador_morreu)
	player.hp_alterado.connect(_on_hp_alterado)
	player.chegou_na_saida.connect(_on_chegou_na_saida)
	tutorial.tutorial_concluido.connect(_on_tutorial_concluido)
	
	input_line.connect("text_submitted", _on_comando_enviado)
	
	_iniciar_sala(0)
	
	tutorial.iniciar()
	_adicionar_saida("[tutorial] Tutorial iniciado. Siga as instrucoes na tela.")
	_adicionar_saida("------------------------------")

func _iniciar_sala(indice: int):
	sala_atual = indice
	mapa.carregar_sala(indice)
	player.grid_pos = Vector2i(1, 1)
	player._sincronizar_posicao()
	
	for filho in gerenciador_inimigos.get_children():
		filho.queue_free()
	gerenciador_inimigos.inimigos.clear()
	
	await get_tree().process_frame
	_spawnar_inimigos_sala()
	
	if indice == 4:
		_adicionar_saida("[chefe] O Guardiao de Runas bloqueia a saida do bioma!")
		_adicionar_saida("Cada parte exige uma variavel com nome especifico (veja acima dele).")
		_adicionar_saida("Use: nome = valor  e depois  atacar_com(nome, 'direcao')")
		_adicionar_saida("------------------------------")

func _spawnar_inimigos_sala():
	if sala_atual == 0:
		gerenciador_inimigos.spawnar_inimigo(Vector2i(3, 2))
		gerenciador_inimigos.spawnar_inimigo_escudo(Vector2i(5, 3))
		return
	
	if sala_atual == 4:
		gerenciador_inimigos.spawnar_chefe(Vector2i(4, 3))
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
	_adicionar_saida("[ok] Tutorial concluido. Boa sorte na sua jornada!")
	_adicionar_saida("------------------------------")

func _on_chegou_na_saida():
	if sala_atual == 4 and gerenciador_inimigos.chefe_vivo():
		_adicionar_saida("[chefe] O Guardiao de Runas ainda protege a saida!")
		_adicionar_saida("Derrote-o primeiro.")
		_adicionar_saida("------------------------------")
		return
	
	_adicionar_saida("[sala] Sala " + str(sala_atual + 1) + " concluida!")
	_adicionar_saida("Carregando proxima sala...")
	_adicionar_saida("------------------------------")
	await get_tree().create_timer(0.8).timeout
	_iniciar_sala(sala_atual + 1)
	_adicionar_saida("[mapa] Sala " + str(sala_atual + 1))
	_adicionar_saida("------------------------------")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP:
			if historico.size() > 0:
				historico_index = max(historico_index - 1, 0)
				input_line.text = historico[historico_index]
				input_line.caret_column = input_line.text.length()
		elif event.keycode == KEY_DOWN:
			if historico_index < historico.size() - 1:
				historico_index += 1
				input_line.text = historico[historico_index]
				input_line.caret_column = input_line.text.length()
			else:
				historico_index = historico.size()
				input_line.text = ""

func _on_comando_enviado(texto: String):
	texto = texto.strip_edges()
	if texto == "":
		return
	
	if texto == "reiniciar()":
		_reiniciar_run()
		return
	
	if tutorial.esta_ativo():
		# Adiciona ao histórico mesmo durante o tutorial
		historico.append(texto)
		historico_index = historico.size()
		
		_adicionar_saida(">>> " + texto)
		var resposta = interpretador.executar(texto)
		if resposta != "":
			_adicionar_saida(resposta)
		
		tutorial.verificar_comando(texto, resposta)
		
		_adicionar_saida("─────────────────────────")
		input_line.clear()
		input_line.grab_focus()
		return
	
	historico.append(texto)
	historico_index = historico.size()
	_adicionar_saida(">>> " + texto)
	var resposta = interpretador.executar(texto)
	if resposta != "":
		_adicionar_saida(resposta)
	_adicionar_saida("------------------------------")
	input_line.clear()
	input_line.grab_focus()

func _on_jogador_morreu():
	_adicionar_saida("[run] Run encerrada. Voce chegou ate a sala " + str(sala_atual + 1) + ".")
	_adicionar_saida("Digite reiniciar() para tentar novamente.")
	_adicionar_saida("------------------------------")

func _on_hp_alterado(hp_atual: int, hp_max: int):
	hp_bar.value = hp_atual
	hp_texto.text = str(hp_atual) + "/" + str(hp_max)

func _reiniciar_run():
	player.resetar()
	output_label.text = ""
	await get_tree().process_frame
	_iniciar_sala(0)
	tutorial.iniciar()
	_adicionar_saida("[run] Nova run iniciada.")
	_adicionar_saida("------------------------------")
	input_line.clear()
	input_line.grab_focus()

func _adicionar_saida(linha: String):
	output_label.text += linha + "\n"
	await get_tree().process_frame
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
	
func _on_chefe_derrotado():
	_adicionar_saida("[chefe] O Guardiao de Runas foi destruido! A saida esta livre.")
	_adicionar_saida("------------------------------")

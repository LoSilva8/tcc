extends SceneTree

var falhas = 0
var jogo: Node

func _initialize():
	call_deferred("_testar")

func verificar(condicao: bool, descricao: String):
	if not condicao:
		falhas += 1
		push_error(descricao)

func _testar():
	jogo = load("res://main.tscn").instantiate()
	root.add_child(jogo)
	jogo.ia.habilitado = false
	await process_frame
	await process_frame
	jogo.interpretador.atraso_entre_acoes = 0.0

	await _testar_restricoes_do_tutorial()
	jogo.debug_console._executar("tutorial_skip")
	await create_timer(0.3).timeout
	await _testar_cada_acao_e_um_turno()
	await _testar_instrucoes_sem_turno()
	await _testar_while_com_sensor()
	await _testar_protecoes_de_laco()
	await _testar_pausa_por_runa()
	await _testar_reiniciar_sala()
	await _testar_grimorio_ui()
	await _testar_execucao_animada_e_cancelamento()

	print("Grimorio: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

func _limpar_inimigos():
	for filho in jogo.gerenciador_inimigos.get_children():
		filho.queue_free()
	jogo.gerenciador_inimigos.inimigos.clear()

func _testar_restricoes_do_tutorial():
	var pos = jogo.player.grid_pos
	await jogo._on_comando_enviado("reiniciar_sala()")
	verificar("depois do tutorial" in jogo.output_label.text and jogo.player.grid_pos == pos, "reiniciar_sala() nao pode bagunçar o tutorial.")

# O pedido da equipe: laco nao e mais "gratis". Antes, for i in range(3): atacar
# matava a Sentinela em 1 turno sem levar dano.
func _testar_cada_acao_e_um_turno():
	await jogo._iniciar_sala(1)
	var p = jogo.player
	p.grid_pos = Vector2i(5, 1)
	var hp_antes = p.hp
	await jogo._executar_programa("for i in range(3):\n    atacar('direita')")
	verificar(not jogo.gerenciador_inimigos.tem_inimigo(Vector2i(6, 1)), "3 ataques no laco derrotam a Sentinela.")
	verificar(p.hp <= hp_antes - 2, "A Sentinela revida entre as voltas do laco (cada acao = 1 turno).")
	_limpar_inimigos()
	p.grid_pos = Vector2i(1, 1)
	p.mana = 0
	await jogo._executar_programa("for i in range(3):\n    mover('direita')")
	verificar(p.grid_pos == Vector2i(4, 1), "Laco de movimento anda 3 casas.")
	verificar(p.mana == 3, "Cada acao do laco recupera 1 de mana (3 turnos).")

func _testar_instrucoes_sem_turno():
	await jogo._iniciar_sala(1)
	var gi = jogo.gerenciador_inimigos
	var posicoes_antes = gi.inimigos.keys()
	var mana_antes = jogo.player.mana
	await jogo._executar_programa("a = 1\nb = a + 1\nlista = [a, b]\nprint(lista)")
	verificar(gi.inimigos.keys() == posicoes_antes, "Contas e variaveis nao gastam turno: inimigos parados.")
	verificar(jogo.player.mana == mana_antes, "Sem acao, sem rodada.")
	verificar("[1, 2]" in jogo.output_label.text, "print aparece no terminal.")

func _testar_while_com_sensor():
	await jogo._iniciar_sala(5)
	_limpar_inimigos()
	jogo.player.grid_pos = Vector2i(1, 4)
	await jogo._executar_programa("while caminho_livre('direita'):\n    mover('direita')")
	verificar(jogo.player.grid_pos == Vector2i(6, 4), "while caminho_livre para exatamente antes da comporta fechada.")
	var r = await jogo.interpretador.executar("print(caminho_livre('direita'), caminho_livre('esquerda'), inimigos_restantes())")
	verificar(r == "False True 0", "Sensores leem o mapa de verdade.")

func _testar_protecoes_de_laco():
	jogo.player.grid_pos = Vector2i(1, 4)
	await jogo._executar_programa("while True:\n    mover('esquerda')")
	verificar("falhou 3 vezes seguidas" in jogo.output_label.text, "Andar contra a parede em laco para sozinho.")
	verificar(not jogo.executando_programa and not jogo.interpretador.executando, "Jogo destravado depois da protecao.")
	var mana_antes = jogo.player.mana
	await jogo._executar_programa("while True:\n    mover('direita')\n    mover('esquerda')")
	verificar("Laco infinito?" in jogo.output_label.text, "Laco infinito com acoes validas para no limite de acoes.")
	verificar(jogo.player.vivo, "Protecao nao derruba o jogo.")

func _testar_pausa_por_runa():
	await jogo._iniciar_sala(5)
	var p = jogo.player
	jogo.interpretador.variaveis["fogo"] = 3
	jogo.interpretador.variaveis["gelo"] = 3
	p.grid_pos = Vector2i(1, 2)
	p.mana = p.mana_max
	await jogo._executar_programa("for i in range(3):\n    fireball(fogo, 'direita')\n    mover('baixo')")
	verificar(not p.pending_escolha.is_empty(), "Derrotar o Eco no laco sobe de nivel.")
	verificar("Programa pausado" in jogo.output_label.text, "Laco pausa ao pedir runa, em vez de seguir no escuro.")
	verificar(p.grid_pos == Vector2i(1, 2), "Nenhuma acao roda depois da pausa.")
	await jogo._on_comando_enviado("escolher(1)")
	verificar(p.pending_escolha.is_empty(), "escolher() continua funcionando.")

func _testar_reiniciar_sala():
	await jogo._iniciar_sala(5)
	var p = jogo.player
	jogo.mapa.comporta_aberta = true
	_limpar_inimigos()
	p.grid_pos = Vector2i(9, 3)
	p.hp = 4
	p.mana = 1
	await jogo._on_comando_enviado("reiniciar_sala()")
	verificar(p.grid_pos == Vector2i(1, 1), "reiniciar_sala volta ao inicio da sala.")
	verificar(not jogo.mapa.comporta_aberta, "reiniciar_sala restaura os objetos.")
	verificar(jogo.gerenciador_inimigos.quantidade_inimigos_vivos() == 2, "reiniciar_sala restaura os inimigos.")
	verificar(p.hp == 4 and p.mana == 1, "reiniciar_sala nao cura (nao vira trapaca).")

func _testar_grimorio_ui():
	var editor = jogo.grimorio_editor
	verificar(editor.syntax_highlighter != null, "Grimorio tem realce de sintaxe (US06).")
	verificar(jogo.desafios.editor.syntax_highlighter != null and jogo.desafios_caverna.editor.syntax_highlighter != null, "Editores de desafio tambem tem realce.")
	await jogo._on_comando_enviado("for i in range(2):")
	verificar(jogo.grimorio_panel.visible, "Linha terminada em : abre o grimorio.")
	verificar(editor.text == "for i in range(2):\n    ", "Grimorio recebe a linha com o recuo pronto.")
	verificar(jogo.input_line.text.is_empty(), "Terminal fica limpo.")
	editor.text = "for i in range(2):\n    print('volta', i)"
	var evento = InputEventKey.new()
	evento.keycode = KEY_ENTER
	evento.ctrl_pressed = true
	evento.pressed = true
	jogo._on_grimorio_input(evento)
	await process_frame
	verificar("volta 1" in jogo.output_label.text, "Ctrl+Enter executa o grimorio.")
	verificar("... " + "    print('volta', i)" in jogo.output_label.text, "Eco mostra o programa com ... nas linhas seguintes.")
	var esc = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	jogo._on_grimorio_input(esc)
	verificar(not jogo.grimorio_panel.visible, "Esc fecha o grimorio.")

func _testar_execucao_animada_e_cancelamento():
	await jogo._iniciar_sala(5)
	_limpar_inimigos()
	var p = jogo.player
	p.grid_pos = Vector2i(1, 4)
	jogo.interpretador.atraso_entre_acoes = 0.3
	jogo._executar_programa("for i in range(4):\n    mover('direita')")
	verificar(jogo.executando_programa, "Programa com varias acoes fica rodando entre os turnos.")
	verificar(p.grid_pos == Vector2i(2, 4), "Primeira acao acontece na hora.")
	await jogo._on_comando_enviado("mover('cima')")
	verificar("Aguarde o programa terminar" in jogo.output_label.text and p.grid_pos == Vector2i(2, 4), "Terminal nao aceita outro comando no meio do programa.")
	await create_timer(0.4).timeout
	verificar(p.grid_pos == Vector2i(3, 4), "Segunda acao vem depois da pausa de animacao.")
	var esc = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	jogo._on_terminal_input(esc)
	await create_timer(0.5).timeout
	verificar(not jogo.executando_programa, "Esc interrompe o programa.")
	verificar(p.grid_pos == Vector2i(3, 4), "Nenhuma acao depois do Esc.")
	verificar("Execucao interrompida" in jogo.output_label.text, "Jogador ve que o programa foi parado.")
	jogo.interpretador.atraso_entre_acoes = 0.0

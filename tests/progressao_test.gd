extends SceneTree

# Progressao por bioma: grimorio a partir das Cavernas, lacos a partir do Labirinto.

var falhas = 0
var jogo: Node

func _initialize():
	call_deferred("_testar")

func verificar(condicao: bool, descricao: String):
	if not condicao:
		falhas += 1
		push_error(descricao)

func _saida_de(acao: Callable) -> String:
	var antes = jogo.output_label.text.length()
	await acao.call()
	return jogo.output_label.text.substr(antes)

func _testar():
	jogo = load("res://main.tscn").instantiate()
	root.add_child(jogo)
	jogo.ia.habilitado = false
	jogo.interpretador.atraso_entre_acoes = 0.0
	await process_frame
	await process_frame
	jogo.menu.fechar()  # como se o aluno tivesse saido do menu principal
	verificar(jogo.grimorio_button.disabled, "Grimorio comeca bloqueado (tutorial).")
	jogo.debug_console._executar("tutorial_skip")
	await create_timer(0.3).timeout
	await _testar_floresta()
	await _testar_caverna()
	await _testar_oraculo_sem_lacos()
	await _testar_labirinto()
	await _testar_reinicio_preserva()
	print("Progressao: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

func _testar_floresta():
	var p = jogo.player
	verificar(jogo.grimorio_button.disabled and "Cavernas" in jogo.grimorio_button.tooltip_text, "Na Floresta o botao { } fica desabilitado e explica quando libera.")
	var evento = InputEventKey.new()
	evento.keycode = KEY_G
	evento.ctrl_pressed = true
	evento.pressed = true
	var saida = await _saida_de(func(): jogo._input(evento))
	verificar(not jogo.grimorio_panel.visible and "sera liberado nas Cavernas" in saida, "Ctrl+G na Floresta avisa em vez de abrir.")
	jogo.input_line.text = "if poder > 2:"
	saida = await _saida_de(func(): await jogo._on_comando_enviado("if poder > 2:"))
	verificar(not jogo.grimorio_panel.visible and "mesma linha" in saida, "Linha terminada em : explica como escrever em uma linha.")
	verificar(jogo.input_line.text == "if poder > 2:", "O texto continua no terminal para o aluno corrigir.")
	jogo.input_line.clear()
	for f in jogo.gerenciador_inimigos.get_children():
		f.queue_free()
	jogo.gerenciador_inimigos.inimigos.clear()
	p.grid_pos = Vector2i(1, 1)
	for linha in ["for i in range(3): mover('direita')", "while caminho_livre('direita'): mover('direita')"]:
		saida = await _saida_de(func(): await jogo._on_comando_enviado(linha))
		verificar("Ainda nao: lacos" in saida and "Labirinto dos Lacos" in saida, "Laco de uma linha avisa que so libera no Labirinto: " + linha)
		verificar(p.grid_pos == Vector2i(1, 1), "Laco bloqueado nao executa nada: " + linha)
		verificar(not jogo.ia.eh_erro(saida.split("\n")[-2] if saida.split("\n").size() > 1 else saida), "Bloqueio nao e tratado como erro do aluno (sem feedback de IA).")
	saida = await _saida_de(func(): await jogo._on_comando_enviado("if 3 > 2: mover('direita')"))
	verificar(p.grid_pos == Vector2i(2, 1), "if de uma linha continua liberado na Floresta (o desafio da porta ja ensina if/else).")
	saida = await _saida_de(func(): await jogo._on_comando_enviado("def magia(): pass"))
	verificar("Ainda nao: 'def'" in saida and "Torre das Funcoes" in saida, "def segue o mesmo padrao de bloqueio.")
	verificar("Bloqueado: liberado nas Cavernas" in jogo._texto_livro_magias(), "Livro mostra o grimorio como bloqueado.")

func _testar_caverna():
	var saida = await _saida_de(func(): await jogo._iniciar_sala(jogo.SALA_CAVERNA))
	verificar("Voce recebeu o Grimorio" in saida, "Entrar nas Cavernas libera o grimorio com aviso.")
	verificar(not jogo.grimorio_button.disabled, "Botao { } habilitado nas Cavernas.")
	jogo._alternar_grimorio()
	verificar(jogo.grimorio_panel.visible, "Grimorio abre nas Cavernas.")
	jogo._fechar_grimorio()
	saida = await _saida_de(func(): await jogo._executar_programa("x = 1\nfor i in range(2):\n    x += 1"))
	verificar("Ainda nao: lacos" in saida and "(linha 2)" in saida, "Nas Cavernas o grimorio ainda nao aceita lacos (e aponta a linha).")
	saida = await _saida_de(func(): await jogo._executar_programa("x = 7\nif x < 5:\n    print('baixo')\nelif x < 10:\n    print('medio')\nelse:\n    print('alto')"))
	verificar("medio" in saida, "if / elif / else de varias linhas funciona nas Cavernas.")
	var livro = jogo._texto_livro_magias()
	verificar("for e while serao liberados no Labirinto" in livro, "Livro explica que lacos vem depois.")

# Sem lacos, o Oraculo continua vencivel: o aluno roda a cadeia if/elif/else
# uma vez por turno (Ctrl+Enter de novo). Isso motiva os lacos do Labirinto.
func _testar_oraculo_sem_lacos():
	await jogo._iniciar_sala(jogo.SALA_CAVERNA_CHEFE)
	var p = jogo.player
	var o = jogo.gerenciador_inimigos.inimigos[Vector2i(4, 3)]
	await jogo._on_comando_enviado("mover('baixo')")
	await jogo._on_comando_enviado("mover('baixo')")
	for e in ["fogo", "gelo", "arcano"]:
		await jogo._on_comando_enviado(e + " = 3")
	var cadeia = "if minha_mana() < 5:\n    if caminho_livre('esquerda'):\n        mover('esquerda')\n    else:\n        mover('direita')\nelif sinal_oraculo == 'fogo':\n    fireball(fogo, 'direita')\nelif sinal_oraculo == 'gelo':\n    fireball(gelo, 'direita')\nelse:\n    fireball(arcano, 'direita')"
	var execucoes = 0
	var hp0 = p.hp
	while o.vivo and execucoes < 60:
		if not p.pending_escolha.is_empty():
			await jogo._on_comando_enviado("escolher(1)")
		execucoes += 1
		await jogo._executar_programa(cadeia)
	print("  Oraculo sem lacos: derrotado=%s com %d execucoes da cadeia, HP %d->%d" % [not o.vivo, execucoes, hp0, p.hp])
	verificar(not o.vivo, "O Oraculo pode ser vencido sem lacos, rodando a cadeia if/elif/else a cada turno.")
	verificar(p.grid_pos.y == 3 and p.vivo, "A cadeia mantem o mago seguro na fileira do meio.")

func _testar_labirinto():
	var saida = await _saida_de(func(): await jogo._iniciar_sala(jogo.SALA_LABIRINTO))
	verificar("for e while liberados" in saida, "Entrar no Labirinto libera os lacos com aviso.")
	saida = await _saida_de(func(): await jogo._executar_programa("total = 0\nfor i in range(4):\n    total += i\nprint(total)"))
	verificar("6" in saida and not ("Ainda nao" in saida), "Lacos funcionam no Labirinto.")

func _testar_reinicio_preserva():
	await jogo._on_comando_enviado("reiniciar()")
	verificar(jogo.menu.visible, "reiniciar() encerra a run e volta ao menu principal.")
	jogo.menu.fechar()
	await jogo._iniciar_run(0)
	verificar(jogo.sala_atual == jogo.SALA_FLORESTA and not jogo.tutorial.esta_ativo(), "Nova run pode comecar na Floresta sem refazer o tutorial (US01).")
	verificar(jogo.grimorio_desbloqueado and jogo.lacos_desbloqueados and not jogo.grimorio_button.disabled, "Conceitos desbloqueados persistem entre runs (RF019).")

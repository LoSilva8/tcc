extends SceneTree

# Funcoes do jogador dentro do jogo: acoes em funcoes gastam turnos, fireball
# acha parametros locais e o laco de fora continua valendo para as mecanicas.

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
	jogo.menu.fechar()
	jogo.debug_console._executar("tutorial_skip")
	await create_timer(0.3).timeout
	for f in jogo.gerenciador_inimigos.get_children():
		f.queue_free()
	jogo.gerenciador_inimigos.inimigos.clear()
	jogo.player.grid_pos = Vector2i(1, 1)
	jogo.lacos_desbloqueados = true
	jogo.funcoes_desbloqueadas = true
	await _testar_acoes_em_funcoes()
	await _testar_fireball_com_parametro()
	await _testar_laco_de_fora()
	await _testar_nova_run_limpa()
	print("Funcoes: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

func _testar_acoes_em_funcoes():
	var p = jogo.player
	await jogo._executar_programa("def andar(direcao, vezes):\n    for i in range(vezes):\n        mover(direcao)\nandar('direita', 3)")
	verificar(p.grid_pos == Vector2i(4, 1), "Funcao com laco move o mago: andar('direita', 3).")
	var saida = await _saida_de(func(): await jogo._executar_programa("def desce_e_conta(n):\n    for i in range(n):\n        mover('baixo')\n    return n\npassos = desce_e_conta(1)\nprint('desci', passos)"))
	verificar(p.grid_pos == Vector2i(4, 2) and "desci 1" in saida, "Funcao com acao pode devolver valor usado numa atribuicao.")
	verificar(jogo.interpretador.variaveis.has("passos") and not jogo.interpretador.variaveis.has("n"), "So a variavel de fora fica guardada, o parametro nao.")

func _testar_fireball_com_parametro():
	jogo.gerenciador_inimigos.spawnar_inimigo(Vector2i(6, 2))
	jogo.player.curar_total()
	var saida = await _saida_de(func(): await jogo._executar_programa("def golpe(poder, direcao):\n    fireball(poder, direcao)\ngolpe(3, 'direita')"))
	verificar("Custo: 5 MP" in saida and not ("nao foi definida" in saida), "fireball dentro da funcao usa o parametro local como poder: " + saida)

func _testar_laco_de_fora():
	var dentro: Array = []
	var registrar = func(_linha): dentro.append(jogo.interpretador.dentro_de_while())
	jogo.interpretador.linha_executando.connect(registrar)
	await jogo._executar_programa("def passo():\n    mover('esquerda')\nn = 0\nwhile n < 1:\n    passo()\n    n += 1")
	jogo.interpretador.linha_executando.disconnect(registrar)
	verificar(dentro.has(true) and jogo.player.grid_pos == Vector2i(3, 2), "Acao numa funcao chamada dentro do while conta como dentro do while (Ouroboros).")

func _testar_nova_run_limpa():
	await jogo._iniciar_run(0)
	verificar(jogo.interpretador.funcoes.is_empty(), "Nova run apaga as funcoes, como as variaveis.")
	jogo.funcoes_desbloqueadas = false
	var saida = await _saida_de(func(): await jogo._on_comando_enviado("def f(): pass"))
	verificar("Ainda nao: 'def'" in saida, "Sem a Torre, def continua bloqueado no jogo.")

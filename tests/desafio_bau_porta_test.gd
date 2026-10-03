extends SceneTree

var falhas = 0

func _initialize():
	call_deferred("_testar")

func verificar(condicao: bool, descricao: String):
	if not condicao:
		falhas += 1
		push_error(descricao)

func _testar():
	var jogo = load("res://main.tscn").instantiate()
	root.add_child(jogo)
	jogo.ia.habilitado = false
	await process_frame
	await process_frame
	await jogo._iniciar_sala(1)
	var guarda = jogo.gerenciador_inimigos.inimigos.get(Vector2i(1, 6))
	verificar(guarda != null and guarda.get_script() == load("res://inimigo_escudo.gd"), "Escudo deve nascer na primeira coluna livre a esquerda, penultima linha interna.")
	verificar(jogo.mapa.posicao_valida(Vector2i(1, 6)), "Novo inimigo deve nascer em uma casa livre do mapa.")
	verificar(_alcanca_arena(jogo.mapa, Vector2i(1, 6)), "Corredor esquerdo deve continuar acessivel.")
	for coluna in range(1, 8):
		for linha in [1, 2]:
			verificar(jogo.mapa.posicao_valida(Vector2i(coluna, linha)), "Corredor superior deve ter duas casas de largura.")
	for coluna in [2, 3, 4]:
		verificar(jogo.mapa.eh_parede(Vector2i(coluna, 3)), "Trecho de parede deve descer para a terceira linha interna.")
	verificar(jogo.gerenciador_inimigos.quantidade_inimigos_vivos() == 6, "Floresta deve conter 6 inimigos incluindo o boss.")
	var desafio = jogo.desafios
	desafio.comando("desafio(porta)")
	verificar(not desafio.painel.visible, "Porta nao deve abrir desafio a distancia.")
	desafio.comando("desafio(bau)")
	verificar(not desafio.painel.visible, "Bau nao deve abrir desafio a distancia.")
	jogo.player.grid_pos = Vector2i(7, 4)
	desafio.comando("desafio(porta)")
	verificar(not desafio.painel.visible, "Diagonal nao conta como ao lado.")
	jogo.player.grid_pos = Vector2i(7, 5)
	desafio._process(0)
	verificar(desafio.dica_proximidade.text.contains("desafio(porta)"), "Dica deve aparecer ao lado da porta.")
	var hp_antes = jogo.player.hp
	var mana_antes = jogo.player.mana
	jogo._on_comando_enviado("desafio(porta)")
	verificar(desafio.painel.visible and desafio.etapa == 1, "Comando no terminal deve abrir apenas o desafio proximo.")
	verificar(jogo.player.hp == hp_antes and jogo.player.mana == mana_antes, "Abrir desafio nao deve gastar turno nem recuperar mana.")
	desafio.editor.text = "meu rascunho"
	desafio._mudar_pagina(1)
	verificar(desafio.editor.text == "meu rascunho", "Trocar explicacao deve preservar codigo.")
	desafio._fechar()
	desafio.comando("desafio(porta)")
	verificar(desafio.editor.text == "meu rascunho", "Reabrir deve preservar rascunho.")
	desafio._fechar()
	jogo.player.grid_pos = Vector2i(1, 1)
	desafio._process(0)
	verificar(desafio.dica_proximidade.text.is_empty(), "Dica deve desaparecer longe dos objetos.")
	verificar(_alcanca_arena(jogo.mapa, Vector2i(3, 6)), "Abrigo do bau deve ter acesso desde o inicio.")
	var codigo = "if tem_chave == True:\n    abrir_porta()\nelse:\n    print('Preciso da chave')"
	verificar(jogo.mapa.eh_parede(jogo.mapa.PORTA_POS), "Porta deve bloquear movimento e projeteis.")
	verificar(not _alcanca_arena(jogo.mapa), "Arena nao pode ter entrada alternativa.")
	verificar(desafio.executar_codigo(codigo, 1).contains("False"), "Sem chave deve executar o ramo falso.")
	jogo.interpretador.variaveis["tem_chave"] = true
	desafio.executar_codigo(codigo, 1)
	verificar(not jogo.mapa.porta_aberta, "Variavel digitada nao pode falsificar inventario.")
	desafio.executar_codigo("selos = 3\nabrir_bau(selos)", 0)
	verificar(not jogo.mapa.bau_aberto, "Bau nao pode abrir a distancia.")
	jogo.player.grid_pos = Vector2i(3, 6)
	desafio.comando("desafio(bau)")
	verificar(desafio.painel.visible and desafio.etapa == 0, "Bau deve abrir seu proprio desafio por proximidade.")
	desafio._fechar()
	desafio.executar_codigo("selos = 2\nabrir_bau(selos)", 0)
	verificar(not jogo.mapa.bau_aberto, "Numero errado nao pode abrir bau.")
	desafio.executar_codigo("selos = 3\nabrir_bau(3)", 0)
	verificar(not jogo.mapa.bau_aberto, "Desafio deve ensinar uso da variavel.")
	desafio.executar_codigo("quantidade = 3\nabrir_bau(quantidade)", 0)
	verificar(jogo.mapa.bau_aberto, "Nome alternativo de variavel deve funcionar.")
	verificar(jogo.interpretador.variaveis.get("quantidade") == 3, "Valor deve ficar disponivel no interpretador.")
	desafio.executar_codigo(codigo, 1)
	verificar(not jogo.mapa.porta_aberta, "Porta exige proximidade.")
	jogo.player.grid_pos = Vector2i(7, 5)
	for invalido in ["abrir_porta()", "if tem_chave == True:\n    abrir_porta()", codigo.replace("    print", "print"), codigo.replace("== True", "= True"), codigo.replace("print('Preciso da chave')", "mover('direita')")]:
		desafio.executar_codigo(invalido, 1)
		verificar(not jogo.mapa.porta_aberta, "Codigo invalido nao deve alterar a porta: " + invalido)
	desafio.executar_codigo(codigo, 1)
	verificar(jogo.mapa.porta_aberta, "If/else correto deve abrir porta.")
	verificar(_alcanca_arena(jogo.mapa), "Porta aberta deve conectar a arena.")
	jogo.mapa.porta_aberta = false
	desafio.executar_codigo("if not tem_chave:\n    print('Buscar chave')\nelse:\n    abrir_porta()", 1)
	verificar(jogo.mapa.porta_aberta, "Condicao invertida valida deve funcionar.")
	var boss = jogo.gerenciador_inimigos.inimigos[Vector2i(10, 7)]
	verificar(boss.hp == 6, "Boss deve manter 6 HP.")
	verificar(not boss.pode_ser_atacado_por(Vector2i(7, 5)), "Ataque externo deve continuar bloqueado.")
	verificar(boss.pode_ocupar(Vector2i(12, 3)), "Boss deve ocupar a area ampliada.")
	jogo.mapa.carregar_sala(1)
	verificar(not jogo.mapa.bau_aberto and not jogo.mapa.porta_aberta, "Reinicio deve restaurar desafios.")
	if "--visual" in OS.get_cmdline_user_args():
		desafio.rascunhos[1] = "if tem_chave == True:\n    \nelse:\n    "
		desafio.abrir("porta")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://desafio-preview.png")
	print("Desafios: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

func _alcanca_arena(mapa: Node, alvo: Vector2i = Vector2i(9, 5)) -> bool:
	var fila = [Vector2i(1, 1)]
	var vistos = {}
	while not fila.is_empty():
		var pos: Vector2i = fila.pop_front()
		if pos == alvo:
			return true
		for direcao in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var proxima: Vector2i = pos + direcao
			if not vistos.has(proxima) and mapa.posicao_valida(proxima):
				vistos[proxima] = true
				fila.append(proxima)
	return false

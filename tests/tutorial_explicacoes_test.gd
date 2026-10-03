extends SceneTree

var falhas = 0

func _initialize():
	call_deferred("_testar")

func verificar(condicao: bool, descricao: String):
	if not condicao:
		falhas += 1
		push_error(descricao)

func _testar():
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1152, 648)
	var jogo = load("res://main.tscn").instantiate()
	root.add_child(jogo)
	jogo.ia.habilitado = false
	await process_frame
	await process_frame
	var tutorial = jogo.tutorial
	var pos_inicial = jogo.player.grid_pos
	jogo.input_line.text = "meu comando ainda nao enviado"
	tutorial._mudar_pagina(1)
	verificar(tutorial.etapa_atual == 0, "Folhear explicacoes nao pode concluir uma etapa.")
	verificar(jogo.player.grid_pos == pos_inicial, "Folhear explicacoes nao pode mover o mago.")
	verificar(jogo.input_line.text == "meu comando ainda nao enviado", "Folhear deve preservar o texto do terminal.")
	tutorial._mudar_pagina(-1)
	tutorial._mudar_pagina(-1)
	verificar(tutorial.pagina_atual == 0 and tutorial.pagina_anterior.disabled, "Navegacao deve respeitar inicio.")
	for etapa in range(tutorial.etapas.size()):
		tutorial._ir_para_etapa(etapa)
		for pagina in range(tutorial.etapas[etapa]["paginas"].size()):
			tutorial.pagina_atual = pagina
			tutorial._atualizar_pagina()
			await process_frame
			await process_frame
			verificar(not "{var_fireball}" in tutorial.texto_label.text, "Exemplo deve mostrar o nome da variavel.")
			verificar(tutorial.comando_label.visible, "Objetivo deve continuar visivel em todas as paginas.")
			var painel: Rect2 = tutorial.tutorial_box.get_global_rect()
			var terminal: Rect2 = jogo.get_node("UI/PanelContainer").get_global_rect()
			verificar(painel.end.y < terminal.position.y, "Explicacao nao pode cobrir o terminal.")
			verificar(painel.encloses(tutorial.texto_label.get_global_rect()), "Explicacao deve caber no painel.")
		tutorial._mudar_pagina(1)
		verificar(tutorial.pagina_proxima.disabled, "Navegacao deve respeitar ultima pagina.")
	tutorial.iniciar()
	for comando in ["mover('direita')", "mover('baixo')", "atacar('direita')", "atacar('direita')", "atacar('direita')", "mover('baixo')", "mover('direita')", "mover('direita')", "atacar('direita')"]:
		jogo._on_comando_enviado(comando)
	verificar(tutorial.etapa_atual == 6, "Sequencia jogada deve chegar a etapa de variaveis sem exigir leitura.")
	if "--visual" in OS.get_cmdline_user_args():
		tutorial._mudar_pagina(1)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://tutorial-explicacoes-preview.png")
	jogo._on_comando_enviado("energia = 3")
	verificar(tutorial.etapa_atual == 7, "Variavel alternativa deve continuar sendo aceita.")
	verificar(tutorial.texto_label.text.contains("fireball(energia,"), "Explicacao deve usar a variavel criada.")
	verificar(tutorial.comando_label.text.contains("fireball(energia,"), "Comando sugerido deve usar a variavel criada.")
	jogo._on_comando_enviado("fireball(energia, 'direita')")
	verificar(tutorial.etapa_atual == 8, "Fireball deve continuar avancando o tutorial.")
	verificar(tutorial.pagina_atual == 0, "Nova etapa deve abrir na primeira explicacao.")
	print("Tutorial: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

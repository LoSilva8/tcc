extends SceneTree

var falhas = 0

func _initialize():
	call_deferred("_testar")

func verificar(condicao: bool, descricao: String):
	if not condicao:
		falhas += 1
		push_error(descricao)

func tecla(codigo: Key, eco: bool = false):
	var evento = InputEventKey.new()
	evento.keycode = codigo
	evento.pressed = true
	evento.echo = eco
	Input.parse_input_event(evento)
	evento = InputEventKey.new()
	evento.keycode = codigo
	Input.parse_input_event(evento)

func _testar():
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1152, 648)
	var jogo = load("res://main.tscn").instantiate()
	root.add_child(jogo)
	jogo.ia.habilitado = false
	await process_frame
	await process_frame
	var campo = jogo.input_line
	campo.grab_focus()
	campo.text = "mover('direita')"
	tecla(KEY_ENTER)
	await process_frame
	verificar(jogo.player.grid_pos == Vector2i(2, 1), "Enter deve executar uma unica acao.")
	verificar(campo.text.is_empty(), "Campo deve ficar vazio depois de executar.")
	tecla(KEY_ENTER, true)
	await process_frame
	verificar(jogo.player.grid_pos == Vector2i(2, 1), "Segurar Enter nao pode disparar varios turnos.")
	tecla(KEY_ENTER)
	await process_frame
	verificar(jogo.player.grid_pos == Vector2i(2, 1), "Enter vazio nao deve repetir a ultima acao.")
	verificar(jogo.historico.size() == 1, "Enter vazio nao deve adicionar historico.")
	var letra = InputEventKey.new()
	letra.keycode = KEY_P
	letra.unicode = 112
	letra.pressed = true
	Input.parse_input_event(letra)
	await process_frame
	verificar(campo.text == "p", "Digitar deve iniciar um novo comando.")
	campo.text = "poder = "
	tecla(KEY_UP)
	await process_frame
	verificar(campo.text == "mover('direita')", "Cima deve recuperar o ultimo comando.")
	tecla(KEY_DOWN)
	await process_frame
	verificar(campo.text == "poder = ", "Baixo deve restaurar o rascunho incompleto.")
	jogo._atualizar_recentes()
	verificar(jogo.recentes.get_popup().item_count == 1, "Menu deve remover duplicatas.")
	var pos = jogo.player.grid_pos
	jogo._selecionar_recente(0)
	verificar(jogo.player.grid_pos == pos, "Selecionar historico nao pode executar comando.")
	verificar(campo.get_selected_text() == "mover('direita')", "Selecao recente deve ficar pronta para editar.")
	campo.text = "poder = 3"
	jogo.executar_button.pressed.emit()
	verificar(jogo.interpretador.variaveis.get("poder") == 3, "Botao deve usar o mesmo interpretador.")
	verificar(campo.text.is_empty(), "Botao executar tambem deve limpar o campo.")
	for comando in ["a = 1", "b = 2", "c = 3", "d = 4", "e = 5", "f = 6", "c = 3"]:
		jogo._on_comando_enviado(comando)
	verificar(jogo.historico == ["b = 2", "d = 4", "e = 5", "f = 6", "c = 3"], "Historico deve manter 5 unicos e atualizar recencia ao repetir.")
	jogo._atualizar_recentes()
	var popup = jogo.recentes.get_popup()
	verificar(popup.item_count == 5, "Menu deve mostrar somente 5 comandos.")
	verificar(popup.get_item_text(0) == "c = 3", "Mais recente deve aparecer primeiro.")
	for i in range(7):
		tecla(KEY_UP)
		await process_frame
	verificar(campo.text == "b = 2", "Setas devem usar o mesmo historico limitado, sem duplicatas.")
	for i in range(7):
		tecla(KEY_DOWN)
		await process_frame
	verificar(campo.text.is_empty(), "Ao sair do historico deve voltar ao campo vazio.")
	for largura in [1152, 800]:
		root.size = Vector2i(largura, 648)
		await process_frame
		await process_frame
		var painel: Rect2 = jogo.get_node("UI/PanelContainer").get_global_rect()
		verificar(painel.size.y <= 154, "Terminal nao pode crescer sobre o mapa.")
		verificar(painel.encloses(campo.get_global_rect()), "Campo deve caber no terminal.")
		verificar(not campo.get_global_rect().intersects(jogo.recentes.get_global_rect()), "Controles nao podem se sobrepor.")
		verificar(campo.size.y >= 40, "Campo deve ter altura confortavel.")
		verificar(jogo.scroll.size.y >= 88, "Historico deve preservar area util.")
	root.size = Vector2i(1152, 648)
	for i in range(20):
		jogo._adicionar_saida("Registro " + str(i))
	await process_frame
	await process_frame
	jogo.scroll.scroll_vertical = 0
	jogo._adicionar_saida("Nova resposta durante leitura")
	await process_frame
	await process_frame
	verificar(jogo.scroll.scroll_vertical == 0, "Ler historico nao deve ser interrompido por novas respostas.")
	jogo._adicionar_saida(">>> poder = 3")
	jogo._adicionar_saida("poder = 3")
	await process_frame
	await process_frame
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://terminal-preview.png")
	print("Terminal: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

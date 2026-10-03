extends SceneTree

var falhas = 0

func _initialize():
	call_deferred("_testar")

func verificar(condicao: bool, mensagem: String):
	if not condicao:
		falhas += 1
		push_error(mensagem)

func _testar():
	var ia = load("res://feedback_ia.gd").new()
	root.add_child(ia)
	var erro = "Erro: direita nao e uma string nem uma variavel definida. Use aspas."
	verificar(ia.eh_erro(erro), "Erro de aspas deve receber ajuda.")
	verificar(ia.eh_erro("Recue cada acao com 4 espacos."), "Indentacao no desafio deve receber ajuda.")
	verificar(not ia.eh_erro("Moveu para direita."), "Acao correta nao deve chamar IA.")
	verificar(not ia.eh_erro("Bau aberto! Voce recebeu a chave!"), "Sucesso no desafio nao deve chamar IA.")
	verificar(not ia.eh_erro("Inimigo derrotado!"), "Derrotar inimigo nao e um erro.")
	var payload = ia._payload("mover(direita)", erro, "Tutorial")
	verificar(payload.model == "openai/gpt-oss-20b" and payload.reasoning_effort == "low", "Modelo rapido deve usar raciocinio minimo suportado.")
	var valida = JSON.stringify({"choices": [{"finish_reason": "stop", "message": {"content": "Use aspas para indicar texto: mover('direita')."}}]}).to_utf8_buffer()
	verificar(not ia._extrair_texto(valida).is_empty(), "Resposta curta valida deve ser lida.")
	for corpo in ["null", "{}", "{\"choices\":[null]}", "{\"choices\":[{\"finish_reason\":\"stop\",\"message\":null}]}", JSON.stringify({"choices": [{"finish_reason": "length", "message": {"content": "Resposta cortada"}}]}), JSON.stringify({"choices": [{"finish_reason": "stop", "message": {"content": "palavra ".repeat(60)}}]})]:
		verificar(ia._extrair_texto(corpo.to_utf8_buffer()).is_empty(), "Resposta invalida ou longa deve usar dica local.")
	var recebido = {}
	ia.habilitado = false
	ia.solicitar("mover(direita)", erro, "Tutorial", func(texto, gerada): recebido.assign({"texto": texto, "gerada": gerada}))
	verificar(not recebido.is_empty() and recebido.gerada == false, "Sem rede deve fornecer dica local identificada.")
	var id = ia.versao
	ia.cancelar()
	recebido.clear()
	ia._concluiu(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), valida, id, "teste", erro, func(texto, gerada): recebido.assign({"texto": texto, "gerada": gerada}))
	verificar(recebido.is_empty(), "Resposta atrasada deve ser descartada apos cancelar.")
	ia._concluiu(HTTPRequest.RESULT_SUCCESS, 429, PackedStringArray(), PackedByteArray(), ia.versao, "teste", erro, func(texto, gerada): recebido.assign({"texto": texto, "gerada": gerada}))
	verificar(recebido.gerada == false and ia.pausa_ate > Time.get_ticks_msec(), "Limite da API deve ativar pausa e dica local.")
	if "--live" in OS.get_cmdline_user_args():
		ia.habilitado = true
		ia.pausa_ate = 0
		recebido.clear()
		var inicio = Time.get_ticks_msec()
		ia.solicitar("mover(direita)", erro, "Tutorial", func(texto, gerada): recebido.assign({"texto": texto, "gerada": gerada}))
		while recebido.is_empty() and Time.get_ticks_msec() - inicio < 10000:
			await process_frame
		verificar(not recebido.is_empty() and recebido.get("gerada", false), "Teste real deve receber feedback da Groq.")
		print("Groq: ", ia.ultimo_status, "; tempo_ms=", Time.get_ticks_msec() - inicio)
		if recebido.get("gerada", false):
			print("Feedback: ", recebido.texto)
	var jogo = load("res://main.tscn").instantiate()
	root.add_child(jogo)
	jogo.ia.habilitado = false
	await process_frame
	await process_frame
	var pos = jogo.player.grid_pos
	jogo._on_comando_enviado("mover(direita)")
	verificar(jogo.output_label.text.contains("[Dica]"), "Erro no terminal deve integrar o feedback.")
	verificar(jogo.player.grid_pos == pos, "Feedback nao pode executar a correcao automaticamente.")
	verificar(jogo.tutorial.dica_label.text.contains("Aspas"), "Tutorial deve mostrar dica curta no painel.")
	jogo.tutorial._concluir()
	await jogo._iniciar_sala(1)
	jogo.player.grid_pos = Vector2i(7, 5)
	jogo.desafios.abrir("porta")
	jogo.desafios.editor.text = "if tem_chave == True\n    abrir_porta()\nelse:\n    print('Preciso da chave')"
	jogo.ia.habilitado = "--live" in OS.get_cmdline_user_args()
	jogo.desafios._executar()
	if "--live" in OS.get_cmdline_user_args():
		var inicio = Time.get_ticks_msec()
		while jogo.ia.ultimo_status == "consultando" and Time.get_ticks_msec() - inicio < 10000:
			await process_frame
		verificar(jogo.desafios.feedback.text.contains("IA:"), "Erro no desafio deve mostrar IA real.")
		print("Desafio Groq: ", jogo.ia.ultimo_status)
	else:
		verificar(jogo.desafios.feedback.text.contains("Dica:"), "Erro no desafio deve integrar a dica local.")
	verificar(not jogo.mapa.porta_aberta, "Feedback nao pode abrir a porta.")
	jogo.queue_free()
	print("Feedback IA: ", falhas, " falhas.")
	ia.queue_free()
	await process_frame
	quit(1 if falhas else 0)

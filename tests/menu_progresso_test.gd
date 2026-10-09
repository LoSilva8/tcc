extends SceneTree

# Menu principal (RF001) e progresso salvo em disco (RF019, RNF005, US01).
# Cada _abrir_jogo() simula fechar e abrir o jogo de novo.

const ARQUIVO = "user://progresso_teste.cfg"
const PASTA_METRICAS = "user://metricas_teste_menu"

var falhas = 0
var jogo: Node

func _initialize():
	call_deferred("_testar")

func verificar(condicao: bool, descricao: String):
	if not condicao:
		falhas += 1
		push_error(descricao)

func _testar():
	DirAccess.remove_absolute(ARQUIVO)
	await _testar_primeira_partida()
	await _testar_continuar()
	await _testar_novo_jogo_pede_confirmacao()
	_testar_arquivo_invalido()
	DirAccess.remove_absolute(ARQUIVO)
	for arquivo in DirAccess.get_files_at(PASTA_METRICAS):
		DirAccess.remove_absolute(PASTA_METRICAS.path_join(arquivo))
	DirAccess.remove_absolute(PASTA_METRICAS)
	print("Menu e progresso: ", falhas, " falhas.")
	quit(1 if falhas else 0)

func _testar_primeira_partida():
	await _abrir_jogo()
	var menu = jogo.menu
	verificar(menu.visible, "O jogo abre no menu principal (RF001).")
	verificar(not menu.continuar_box.visible, "Sem progresso salvo nao ha o que continuar.")
	jogo.debug_console._executar("tutorial_skip")
	await process_frame
	verificar(not FileAccess.file_exists(ARQUIVO), "Antes de escolher no menu nada e gravado.")
	menu.abrir()
	verificar(not menu.continuar_box.visible, "Jogar sem passar pelo menu nao altera o progresso mostrado.")

	await _apertar(menu.novo_jogo_button)
	verificar(not menu.visible and jogo.tutorial.esta_ativo() and jogo.sala_atual == jogo.SALA_TUTORIAL, "Novo jogo comeca uma run nova pelo tutorial.")
	verificar(FileAccess.file_exists(ARQUIVO), "Novo jogo cria o arquivo de progresso.")

	jogo.debug_console._executar("tutorial_skip")
	await process_frame
	verificar(_salvo().tutorial_concluido, "Concluir o tutorial fica salvo em disco.")
	await jogo._iniciar_sala(jogo.SALA_CAVERNA)
	var salvo = _salvo()
	verificar(salvo.bioma_liberado == 1 and salvo.grimorio_desbloqueado and not salvo.lacos_desbloqueados, "Chegar as Cavernas grava o bioma e o grimorio liberados.")

	jogo.player._receber_dano(jogo.player.hp, "Teste.")
	verificar("voltar ao menu" in jogo.output_label.text, "Derrota explica que reiniciar() volta ao menu (RF020).")
	await jogo._on_comando_enviado("reiniciar()")
	verificar(menu.visible and menu.continuar_box.visible, "reiniciar() volta ao menu, ja com a opcao de continuar.")
	await _fechar_jogo()

func _testar_continuar():
	await _abrir_jogo()
	var menu = jogo.menu
	verificar(menu.continuar_box.visible, "Com progresso salvo o menu oferece continuar.")
	verificar(not menu.biomas_buttons[0].disabled and not menu.biomas_buttons[1].disabled, "Floresta e Cavernas aparecem liberadas.")
	verificar(menu.biomas_buttons[2].disabled, "Labirinto fica bloqueado ate concluir as Cavernas (RF015).")

	await _apertar(menu.biomas_buttons[1])
	verificar(not menu.visible and jogo.sala_atual == jogo.SALA_CAVERNA, "Continuar leva ao inicio do bioma escolhido.")
	verificar(not jogo.tutorial.esta_ativo() and jogo.player.xp_habilitado, "Continuar pula o tutorial e ja libera XP (US01).")
	verificar(jogo.grimorio_desbloqueado and not jogo.grimorio_button.disabled, "O grimorio salvo volta liberado.")
	verificar(not ("Voce recebeu o Grimorio" in jogo.output_label.text), "Grimorio ja conhecido nao e anunciado de novo.")
	verificar(jogo.player.nivel == 1 and jogo.player.xp == 0, "XP e nivel zeram a cada run (RF033).")

	jogo.menu.abrir()
	await jogo.continuar(2)
	verificar(jogo.sala_atual == jogo.SALA_CAVERNA, "Continuar nao pula para um bioma bloqueado.")
	await _fechar_jogo()

func _testar_novo_jogo_pede_confirmacao():
	await _abrir_jogo()
	var menu = jogo.menu
	await _apertar(menu.novo_jogo_button)
	verificar(menu.visible and menu.aviso_label.visible and _salvo().tutorial_concluido, "Com progresso salvo, o primeiro clique em Novo jogo so avisa.")
	await _apertar(menu.novo_jogo_button)
	var salvo = _salvo()
	verificar(not menu.visible and jogo.tutorial.esta_ativo(), "Confirmar comeca pelo tutorial.")
	verificar(not salvo.tutorial_concluido and salvo.bioma_liberado == 0 and not salvo.grimorio_desbloqueado, "Novo jogo zera o progresso salvo.")
	verificar(jogo.grimorio_button.disabled, "Novo jogo bloqueia o grimorio de novo.")
	await _fechar_jogo()

func _testar_arquivo_invalido():
	_escrever_arquivo("isto nao e um arquivo de configuracao [[[")
	var p = _novo_progresso()
	p.carregar()
	verificar(not p.tem_progresso() and p.bioma_liberado == 0, "Arquivo corrompido vale como jogo novo.")
	_escrever_arquivo("[progresso]\ntutorial_concluido=\"sim\"\nbioma_liberado=-3\n")
	p = _novo_progresso()
	p.carregar()
	verificar(not p.tutorial_concluido and p.bioma_liberado == 0, "Valores com tipo errado voltam ao padrao.")

# ─── Utilitarios ────────────────────────────────────────────────────

func _abrir_jogo():
	jogo = load("res://main.tscn").instantiate()
	root.add_child(jogo)
	jogo.ia.habilitado = false
	jogo.interpretador.atraso_entre_acoes = 0.0
	# Arquivo separado: o teste nunca toca no progresso real do jogador.
	jogo.progresso.caminho = ARQUIVO
	jogo.metricas.pasta = PASTA_METRICAS
	jogo.progresso.carregar()
	jogo.menu.abrir()
	await process_frame
	await process_frame

func _fechar_jogo():
	jogo.queue_free()
	await process_frame

func _apertar(botao: Button):
	botao.emit_signal("pressed")
	for i in range(4):
		await process_frame

func _novo_progresso() -> RefCounted:
	var p = load("res://progresso.gd").new()
	p.caminho = ARQUIVO
	return p

func _salvo() -> RefCounted:
	var p = _novo_progresso()
	p.carregar()
	return p

func _escrever_arquivo(texto: String):
	var arquivo = FileAccess.open(ARQUIVO, FileAccess.WRITE)
	arquivo.store_string(texto)
	arquivo.close()

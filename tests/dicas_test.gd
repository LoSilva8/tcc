extends SceneTree

# Dicas progressivas (dica()): sempre disponiveis, em 3 degraus, de acordo com a
# sala e o que ja foi feito nela; a primeira falha de regra mostra o 1o degrau.

const PASTA = "user://metricas_teste_dicas"
const PROGRESSO = "user://progresso_dicas_teste.cfg"
const Dicas = preload("res://dicas.gd")

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

func _dica() -> String:
	return await _saida_de(func(): await jogo._on_comando_enviado("dica()"))

func _testar():
	_limpar()
	jogo = load("res://main.tscn").instantiate()
	root.add_child(jogo)
	jogo.ia.habilitado = false
	jogo.interpretador.atraso_entre_acoes = 0.0
	jogo.metricas.pasta = PASTA
	jogo.progresso.caminho = PROGRESSO
	await process_frame
	await process_frame
	jogo.menu.participante_edit.text = "D01"
	jogo.menu.novo_jogo_button.emit_signal("pressed")
	for i in range(4):
		await process_frame

	await _testar_tutorial()
	await _testar_degraus()
	await _testar_situacao_da_sala()
	await _testar_falha_de_regra()
	await _testar_travado()
	await _testar_metricas()
	await _testar_cobertura()
	_testar_exemplos_compilam()

	_limpar()
	print("Dicas: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

func _testar_tutorial():
	verificar("Digite: mover('direita')" in await _dica(), "No tutorial, dica() repete a orientacao da etapa atual.")
	verificar("dica()" in jogo._texto_livro_magias(), "Livro de Magias ensina dica().")
	verificar("sozinho no terminal" in await _saida_de(func(): await jogo._executar_programa("dica()")), "dica() dentro de um programa e explicado.")
	jogo.debug_console._executar("tutorial_skip")
	await create_timer(0.3).timeout
	jogo.lacos_desbloqueados = true
	jogo.funcoes_desbloqueadas = true
	jogo.grimorio_desbloqueado = true

# ─── Degraus: conceito, o que fazer, exemplo ───────────────────────

func _testar_degraus():
	await jogo._iniciar_sala(jogo.SALA_TORRE)
	var saida = await _dica()
	verificar("[dica 1/3] As Sentinelas so sentem golpes vindos de dentro de uma funcao" in saida and "dica() de novo" in saida, "1o degrau: o conceito. " + saida)
	saida = await _dica()
	verificar("[dica 2/3] Crie uma funcao que ataca duas vezes" in saida, "2o degrau: o que fazer.")
	saida = await _dica()
	verificar("[dica 3/3] Exemplo no grimorio:\ndef golpe_duplo():" in saida and not ("dica() de novo" in saida), "3o degrau: exemplo quase pronto, sem pedir mais.")
	verificar("[dica 3/3]" in await _dica(), "Depois do 3o degrau, a dica continua disponivel.")

# ─── O topico acompanha o que falta fazer na sala ──────────────────

func _testar_situacao_da_sala():
	await jogo._iniciar_sala(jogo.SALA_FLORESTA)
	verificar("bau dourado" in await _dica(), "Floresta, bau fechado: dica do bau.")
	jogo.mapa.bau_aberto = true
	verificar("[dica 1/3] Voce ja tem a chave" in await _dica(), "Bau aberto: a dica passa para a porta, a partir do 1o degrau.")
	jogo.mapa.porta_aberta = true
	verificar("Guardiao de Runas" in await _dica(), "Porta aberta: a dica passa para o Guardiao.")
	await jogo._iniciar_sala(jogo.SALA_CAVERNA)
	verificar("comporta" in await _dica(), "Cavernas: dica da comporta.")

# ─── Falha de regra mostra o 1o degrau sozinho, uma vez ────────────

func _testar_falha_de_regra():
	await jogo._iniciar_sala(jogo.SALA_ELOS)
	await jogo._on_comando_enviado("mover('direita')")
	var saida = await _saida_de(func(): await jogo._on_comando_enviado("atacar('direita')"))
	verificar("absorveu o golpe solto" in saida and "[dica 1/3] Golpes soltos nao partem um Elo" in saida, "Golpe solto no Elo: o 1o degrau aparece sozinho. " + saida)
	saida = await _saida_de(func(): await jogo._on_comando_enviado("atacar('direita')"))
	verificar(not ("[dica 1/3]" in saida), "A dica automatica nao se repete.")
	verificar("[dica 2/3]" in await _dica(), "Depois da automatica, dica() ja vai para o 2o degrau.")
	saida = await _saida_de(func(): await jogo._on_comando_enviado("mover('direita'"))
	verificar("Erro de sintaxe" in saida and not ("[dica 1/3]" in saida), "Erro de Python continua com o feedback de sempre, sem dica de sala automatica.")

# ─── Travado: a cada 3 programas com problema, lembra de dica() ────

func _testar_travado():
	await jogo._iniciar_sala(jogo.SALA_LABIRINTO)
	var lembretes = 0
	for i in range(3):
		var saida = await _saida_de(func(): await jogo._on_comando_enviado("while True mover('direita')"))
		if "Travou? Digite dica()" in saida:
			lembretes += 1
			verificar(i == 2, "Lembrete so na 3a tentativa com problema.")
	verificar(lembretes == 1, "Tres tentativas com problema geram um lembrete de dica().")

func _testar_metricas():
	var resumo = FileAccess.get_file_as_string(jogo.metricas.caminho_resumo())
	verificar("dicas_pedidas" in resumo.split("\n")[0], "Resumo tem a coluna dicas_pedidas.")
	var eventos = FileAccess.get_file_as_string(jogo.metricas.caminho_eventos())
	verificar(";dica_pedida;3;;;;sentinelas" in eventos, "Dica pedida registrada com o degrau e o topico.")
	verificar(";dica_automatica;1;;;;elos" in eventos, "Dica automatica registrada.")
	verificar(";Tutorial;dica_pedida;1;;;;tutorial" in eventos, "Dica no tutorial registrada.")

# ─── Toda sala tem dica, e todo topico tem 3 degraus ───────────────

func _testar_cobertura():
	for topico in Dicas.DICAS:
		var degraus = Dicas.DICAS[topico]
		verificar(degraus.size() == 3 and not degraus.has(""), "Topico " + topico + " tem 3 degraus.")
	for sala in [1, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]:
		await jogo._iniciar_sala(sala)
		var topico = jogo._topico_dica()
		verificar(Dicas.DICAS.has(topico) and topico != "geral", "Sala " + str(sala) + " tem dica propria: " + topico)

# Os exemplos do 3o degrau sao Python que o interpretador do jogo aceita.
func _testar_exemplos_compilam():
	var it = load("res://interpretador.gd").new()
	for topico in ["floresta_bau", "floresta_porta", "floresta_guardiao", "caverna_comporta", "oraculo", "nevoa", "elos", "ponte", "ouroboros", "gemeas", "selo", "arquimago"]:
		var exemplo: String = Dicas.DICAS[topico][2]
		var codigo = exemplo.substr(exemplo.find("\n") + 1)
		it._preparar_execucao()
		it._compilar(codigo)
		verificar(it._erro == "", "Exemplo de " + topico + " compila: " + it._erro)
	it.free()

func _limpar():
	if DirAccess.dir_exists_absolute(PASTA):
		for arquivo in DirAccess.get_files_at(PASTA):
			DirAccess.remove_absolute(PASTA.path_join(arquivo))
		DirAccess.remove_absolute(PASTA)
	DirAccess.remove_absolute(PROGRESSO)

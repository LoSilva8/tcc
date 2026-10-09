extends SceneTree

# Torre das Funcoes. Andar 1 (Salao das Sentinelas): Sentinelas so sentem golpes
# de dentro de uma funcao do jogador.

const ARQUIVO = "user://progresso_torre_teste.cfg"

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
	DirAccess.remove_absolute(ARQUIVO)
	jogo = load("res://main.tscn").instantiate()
	root.add_child(jogo)
	jogo.ia.habilitado = false
	jogo.interpretador.atraso_entre_acoes = 0.0
	await process_frame
	await process_frame
	jogo.menu.fechar()
	jogo.debug_console._executar("tutorial_skip")
	await create_timer(0.3).timeout
	# Progresso gravado num arquivo de teste, como numa partida iniciada pelo menu.
	jogo.progresso.caminho = ARQUIVO
	jogo.progresso.ativo = true

	await _testar_transicao_labirinto_torre()
	await _testar_sentinelas()
	await _testar_parametros()
	await _testar_selo()
	await _testar_arquimago()
	await _testar_continuar_na_torre()

	DirAccess.remove_absolute(ARQUIVO)
	print("Torre: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

func _esperar_sala(indice: int) -> bool:
	for i in range(30):
		if jogo.sala_atual == indice and not jogo.trocando_sala:
			await process_frame
			return true
		await create_timer(0.1).timeout
	return false

func _resolver_runa():
	if not jogo.player.pending_escolha.is_empty():
		await jogo._on_comando_enviado("escolher(1)")

# ─── Transicao ──────────────────────────────────────────────────────

func _testar_transicao_labirinto_torre():
	await jogo._iniciar_sala(jogo.SALA_LABIRINTO_CHEFE)
	for filho in jogo.gerenciador_inimigos.get_children():
		filho.queue_free()
	jogo.gerenciador_inimigos.inimigos.clear()
	jogo.player.hp = 3
	verificar(not jogo.funcoes_desbloqueadas, "def comeca bloqueado antes da Torre.")
	jogo._concluir_fase_3()
	verificar(await _esperar_sala(jogo.SALA_TORRE), "Vencer o Ouroboros leva a Torre (sala 13).")
	verificar(jogo.player.hp == jogo.player.hp_max, "Entrar na Torre cura o mago.")
	var texto = jogo.output_label.text
	verificar("def e return liberados" in texto and jogo.funcoes_desbloqueadas, "Entrar na Torre libera def/return com aviso.")
	verificar("Salao das Sentinelas" in texto and "def nome():" in texto, "Sala 13 apresenta o conceito de funcao (RF016).")
	verificar("Fase 4" in jogo._texto_livro_magias() and "def nome():" in jogo._texto_livro_magias(), "Livro mostra a secao da fase 4.")
	var salvo = load("res://progresso.gd").new()
	salvo.caminho = ARQUIVO
	salvo.carregar()
	verificar(salvo.funcoes_desbloqueadas and salvo.bioma_liberado == 3, "Torre e funcoes ficam salvas no progresso.")

# ─── Sala 13: Sentinelas so caem com golpes de dentro de funcao ─────

func _testar_sentinelas():
	var gi = jogo.gerenciador_inimigos
	var p = jogo.player
	verificar(gi.quantidade_inimigos_vivos() == 3, "Tres Sentinelas no salao.")
	var primeira = gi.inimigos.get(Vector2i(3, 2))
	verificar(primeira != null and primeira.get_script() == load("res://sentinela.gd"), "Sentinela na primeira passagem.")
	await _resolver_runa()
	await jogo._on_comando_enviado("mover('direita')")
	await jogo._on_comando_enviado("mover('direita')")
	verificar(p.grid_pos == Vector2i(3, 1), "Mago chega acima da primeira Sentinela.")
	var hp_antes = p.hp
	var saida = await _saida_de(func(): await jogo._on_comando_enviado("atacar('baixo')"))
	verificar("ignora o golpe solto" in saida and primeira.golpes_restantes == 2, "Golpe solto nao atinge a Sentinela.")
	await jogo._executar_programa("for i in range(2):\n    atacar('baixo')")
	verificar(primeira.golpes_restantes == 2, "Laco sem funcao tambem nao atinge.")
	verificar(p.hp == hp_antes, "Sentinelas sao passivas: nao atacam.")
	await jogo._executar_programa("def golpe_duplo():\n    atacar('baixo')\n    atacar('baixo')")
	verificar(primeira.golpes_restantes == 2, "Definir a funcao nao executa o bloco.")
	saida = await _saida_de(func(): await jogo._on_comando_enviado("golpe_duplo()"))
	verificar("rachou" in saida and "Sentinela desfeita" in saida and not primeira.vivo, "Chamar a funcao desfaz a Sentinela com 2 golpes.")
	verificar(gi.quantidade_inimigos_vivos() == 2, "Restam duas Sentinelas.")

	p.grid_pos = Vector2i(8, 3)
	saida = await _saida_de(func(): await jogo._on_comando_enviado("mover('direita')"))
	verificar("ainda selam a saida" in saida and not jogo.fase_4_concluida, "Saida selada enquanto houver Sentinela.")

	p.grid_pos = Vector2i(3, 1)
	await _resolver_runa()
	var ate_a_proxima = "for i in range(2):\n    mover('direita')\ngolpe_duplo()"
	await jogo._executar_programa(ate_a_proxima)
	verificar(gi.quantidade_inimigos_vivos() == 1, "A mesma funcao, chamada de novo, desfaz a segunda Sentinela.")
	# Subir de nivel pausa o programa: o aluno escolhe a runa e segue.
	await _resolver_runa()
	await jogo._executar_programa(ate_a_proxima)
	verificar(gi.quantidade_inimigos_vivos() == 0, "E a terceira.")
	await jogo._executar_programa("mover('baixo')\nmover('baixo')\nmover('direita')\nmover('direita')")
	verificar("Salao das Sentinelas concluido" in jogo.output_label.text, "Com as Sentinelas desfeitas, a saida conclui o andar 1.")
	verificar(await _esperar_sala(jogo.SALA_PARAMETROS), "O andar 1 leva ao andar 2 (sala 14).")

# ─── Sala 14: Sentinelas Gemeas so sentem funcoes com parametros ────

func _testar_parametros():
	var gi = jogo.gerenciador_inimigos
	var p = jogo.player
	var mapa = jogo.mapa
	verificar(p.grid_pos == Vector2i(5, 2), "Mago comeca no centro da Camara dos Parametros.")
	verificar(gi.quantidade_inimigos_vivos() == 4, "Quatro Sentinelas Gemeas.")
	var runas = mapa.sentinelas.values()
	verificar(runas.min() >= 1 and runas.max() <= 3 and runas.has(1) and runas.has(2) and runas.has(3), "Runas de 1 a 3, nunca todas iguais.")
	var texto = jogo.output_label.text
	verificar("Camara dos Parametros" in texto and "golpear(direcao, vezes)" in texto, "Sala 14 apresenta parametros (RF016).")
	verificar("Sentinelas Gemeas" in jogo._texto_livro_magias(), "Livro explica as Gemeas.")
	var sorteios = {}
	for i in range(12):
		await jogo._on_comando_enviado("reiniciar_sala()")
		sorteios[str(mapa.sentinelas)] = true
	verificar(sorteios.size() >= 2, "As runas mudam a cada visita (uma funcao fixa nao serve).")
	await _resolver_runa()

	var cima = gi.inimigos.get(Vector2i(5, 1))
	var antes = cima.golpes_restantes
	var saida = await _saida_de(func(): await jogo._executar_programa("def golpe_cima():\n    atacar('cima')\ngolpe_cima()"))
	verificar("ignora funcoes sem parametros" in saida and cima.golpes_restantes == antes, "Funcao sem parametros nao atinge a Sentinela Gemea.")

	await jogo._executar_programa("def golpear(direcao, vezes):\n    for i in range(vezes):\n        atacar(direcao)")
	var direcoes = {"cima": Vector2i(5, 1), "esquerda": Vector2i(4, 2), "direita": Vector2i(6, 2), "baixo": Vector2i(5, 3)}
	# Subir de nivel pausa o programa: como o aluno, escolhe a runa e chama de novo.
	for tentativa in range(4):
		for d in direcoes:
			await _resolver_runa()
			var sentinela = gi.inimigos.get(direcoes[d])
			if sentinela != null and sentinela.vivo:
				await jogo._on_comando_enviado("golpear('" + d + "', " + str(sentinela.golpes_restantes) + ")")
	verificar(gi.quantidade_inimigos_vivos() == 0, "Uma funcao com parametros desfaz todas as Gemeas.")
	await _resolver_runa()
	await jogo._executar_programa("for i in range(4):\n    mover('direita')")
	verificar("Camara dos Parametros concluida" in jogo.output_label.text, "A saida conclui o andar 2.")
	verificar(await _esperar_sala(jogo.SALA_SELO), "O andar 2 leva ao andar 3 (sala 15).")

# ─── Sala 15: o Selo do Retorno testa uma funcao com return ─────────

func _abrir_selo() -> String:
	return await _saida_de(func(): await jogo._on_comando_enviado("abrir_selo()"))

func _testar_selo():
	var p = jogo.player
	var mapa = jogo.mapa
	var texto = jogo.output_label.text
	verificar("Selo do Retorno" in texto and "return valor" in texto, "Sala 15 apresenta return (RF016).")
	verificar("return valor" in jogo._texto_livro_magias() and "abrir_selo()" in jogo._texto_livro_magias(), "Livro explica return e o Selo.")
	await _resolver_runa()
	p.grid_pos = Vector2i(5, 2)
	var saida = await _saida_de(func(): await jogo._on_comando_enviado("mover('direita')"))
	verificar("abrir_selo()" in saida and p.grid_pos == Vector2i(5, 2), "O Selo bloqueia o corredor e ensina o comando.")

	verificar("ainda nao existe" in await _abrir_selo(), "Sem a funcao, o Selo explica o que criar.")
	await jogo._executar_programa("def poder_da_runa():\n    return 3")
	verificar("exatamente 1 parametro" in await _abrir_selo(), "Funcao sem o parametro runa e recusada.")
	await jogo._executar_programa("def poder_da_runa(runa):\n    if runa == 'fogo':\n        print(3)\n    elif runa == 'gelo':\n        print(2)\n    else:\n        print(1)")
	saida = await _abrir_selo()
	verificar("devolveu None" in saida and "Faltou return?" in saida and not mapa.selo_aberto, "print no lugar de return: o Selo explica a diferenca.")
	await jogo._executar_programa("def poder_da_runa(runa):\n    return 3")
	saida = await _abrir_selo()
	verificar("mas o esperado era" in saida and not mapa.selo_aberto, "Valor errado mantem o Selo fechado: " + saida)
	await jogo._executar_programa("def poder_da_runa(runa):\n    return poderes[runa]")
	saida = await _abrir_selo()
	verificar("'poderes' nao foi definida" in saida and "parou antes de devolver" in saida, "Erro dentro da funcao aparece e o Selo segue fechado.")
	saida = await _saida_de(func(): await jogo._executar_programa("abrir_selo()"))
	verificar("sozinho no terminal" in saida, "abrir_selo() dentro de um programa e explicado.")
	verificar(p.grid_pos == Vector2i(5, 2) and jogo.player.hp == jogo.player.hp_max, "Tentativas no Selo nao custam vida nem movem o mago.")

	await jogo._executar_programa("def poder_da_runa(runa):\n    if runa == 'fogo':\n        return 3\n    elif runa == 'gelo':\n        return 2\n    return 1")
	saida = await _abrir_selo()
	verificar(saida.count("Certo!") == 4 and "se abriu" in saida and mapa.selo_aberto, "Funcao certa passa nos 4 testes e abre o Selo: " + saida)
	verificar("ja esta aberto" in await _abrir_selo(), "Selo aberto nao testa de novo.")
	await jogo._executar_programa("for i in range(3):\n    mover('direita')")
	verificar("Selo do Retorno concluido" in jogo.output_label.text, "Com o Selo aberto, a saida conclui o andar 3.")
	verificar(await _esperar_sala(jogo.SALA_ARQUIMAGO), "O andar 3 leva ao Arquimago (sala 16).")

# ─── Sala 16: Arquimago so cai com funcao + laco + if (Tabela 11) ───

const MIRA = "def golpe():\n    for d in ['cima', 'baixo', 'esquerda', 'direita']:\n        if inimigo_a_frente(d):\n            atacar(d)\n            return"

func _direcao_do(chefe: Node) -> String:
	match chefe.grid_pos - jogo.player.grid_pos:
		Vector2i(0, -1):
			return "cima"
		Vector2i(0, 1):
			return "baixo"
		Vector2i(-1, 0):
			return "esquerda"
	return "direita"

func _testar_arquimago():
	var p = jogo.player
	var gi = jogo.gerenciador_inimigos
	var mapa = jogo.mapa
	verificar(p.grid_pos == mapa.NUCLEO_CENTRO and p.hp == p.hp_max, "Mago comeca curado no centro do nucleo.")
	var chefe = gi.inimigos.values()[0] if gi.inimigos.size() == 1 else null
	verificar(chefe != null and chefe.get_script() == load("res://arquimago.gd") and chefe.grid_pos in mapa.PEDESTAIS, "Arquimago nasce num pedestal.")
	if chefe == null:
		return
	var texto = jogo.output_label.text
	verificar("Arquimago da Corrupcao desperta" in texto and "chamada dentro de um laco" in texto, "Anuncio explica a magia completa.")
	verificar("Arquimago: so cai" in jogo._texto_livro_magias(), "Livro explica o Arquimago.")
	await _resolver_runa()
	var vazio = mapa.NUCLEO_CENTRO + Vector2i(0, -1) if chefe.grid_pos != mapa.NUCLEO_CENTRO + Vector2i(0, -1) else mapa.NUCLEO_CENTRO + Vector2i(0, 1)
	var dir_vazio = "cima" if vazio.y < mapa.NUCLEO_CENTRO.y else "baixo"
	var saida = await _saida_de(func(): await jogo._on_comando_enviado("mover('" + dir_vazio + "')"))
	verificar("pedestais do nucleo" in saida and p.grid_pos == mapa.NUCLEO_CENTRO, "Mago nao sai do centro.")

	var antes = chefe.grid_pos
	saida = await _saida_de(func(): await jogo._on_comando_enviado("atacar('" + _direcao_do(chefe) + "')"))
	verificar("desfaz golpes soltos" in saida and chefe.selos == 6, "Golpe solto nao fere.")
	verificar(chefe.grid_pos != antes and chefe.grid_pos in mapa.PEDESTAIS and gi.inimigos.get(chefe.grid_pos) == chefe, "A cada turno ele salta para outro pedestal.")

	await jogo._executar_programa("def golpe_unico(d):\n    if inimigo_a_frente(d):\n        atacar(d)")
	saida = await _saida_de(func(): await jogo._on_comando_enviado("golpe_unico('" + _direcao_do(chefe) + "')"))
	verificar("dentro de um laco" in saida and chefe.selos == 6, "Funcao com if, mas sem laco, nao fere.")
	await jogo._executar_programa("def as_cegas(d):\n    atacar(d)")
	saida = await _saida_de(func(): await jogo._executar_programa("for i in range(1):\n    as_cegas('" + _direcao_do(chefe) + "')"))
	verificar("as cegas" in saida and chefe.selos == 6, "Funcao no laco, mas sem if, nao fere.")

	await jogo._executar_programa(MIRA)
	saida = await _saida_de(func(): await jogo._executar_programa("for i in range(2):\n    golpe()"))
	verificar("Selo de corrupcao partido" in saida and "se refizeram" in saida and chefe.selos == 6, "Laco que para antes dele: os selos se refazem.")

	p.hp = p.hp_max
	saida = await _saida_de(func(): await jogo._executar_programa("while inimigos_restantes() > 0:\n    golpe()"))
	verificar(not chefe.vivo and "ARQUIMAGO DA CORRUPCAO CAIU" in saida, "Funcao com if chamada num while derrota o Arquimago.")
	verificar("O Arquimago lanca corrupcao" in saida and p.vivo, "Ele lanca corrupcao, mas a luta e vencivel.")
	verificar(jogo.fase_4_concluida and "Parabens! Voce concluiu PyAdventure." in jogo.output_label.text, "Vencer o Arquimago conclui o jogo.")
	var salvo = load("res://progresso.gd").new()
	salvo.caminho = ARQUIVO
	salvo.carregar()
	verificar(salvo.jogo_concluido, "Jogo concluido fica salvo.")
	jogo.menu.atualizar()
	verificar("concluiu PyAdventure" in jogo.menu.continuar_label.text, "Menu reconhece o jogo concluido.")

# ─── Continuar direto na Torre ──────────────────────────────────────

func _testar_continuar_na_torre():
	jogo.funcoes_desbloqueadas = false
	jogo.menu.abrir()
	verificar(not jogo.menu.biomas_buttons[3].disabled, "Menu oferece continuar na Torre.")
	await jogo.continuar(3)
	verificar(jogo.sala_atual == jogo.SALA_TORRE and jogo.funcoes_desbloqueadas, "Continuar na Torre ja libera def.")
	verificar(jogo.gerenciador_inimigos.quantidade_inimigos_vivos() == 3, "Run nova na Torre traz as Sentinelas de volta.")
	verificar("Nao ha nenhum selo" in await _abrir_selo(), "abrir_selo() fora da sala do Selo avisa.")

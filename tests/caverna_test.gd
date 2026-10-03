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
	await _testar_pular_tutorial()
	_testar_interpretador()
	await _testar_transicao_floresta_caverna()
	_testar_comporta()
	_testar_ecos()
	_testar_rodadas_na_caverna()
	await _testar_progressao_das_galerias()
	await _testar_oraculo()
	await _testar_reinicio()

	print("Caverna: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

# ─── Pular tutorial = mesmo caminho do fim natural ──────────────────

func _testar_pular_tutorial():
	var resposta = jogo.debug_console._executar("tutorial_skip")
	await create_timer(0.3).timeout
	verificar(not jogo.tutorial.esta_ativo(), "tutorial_skip deve encerrar o tutorial.")
	verificar(jogo.player.xp_habilitado, "tutorial_skip deve liberar XP como o fim natural do tutorial.")
	verificar(jogo.sala_atual == jogo.SALA_FLORESTA, "tutorial_skip deve levar a Fase 1.")
	verificar("[fase 1] Clareira" in jogo.output_label.text, "tutorial_skip deve anunciar a Fase 1.")
	verificar("ja foi concluido" in jogo.debug_console._executar("tutorial_skip"), "Segundo tutorial_skip nao deve repetir a transicao.")

# ─── Interpretador: if / elif / else, and / or, strings ─────────────

func _testar_interpretador():
	var it = load("res://interpretador.gd").new()
	it.variaveis["fogo"] = 2
	it.variaveis["gelo"] = 2
	var linha = "if sinal == 'fogo': A elif sinal == 'gelo': B else: C"
	for caso in [["fogo", "A"], ["gelo", "B"], ["arcano", "C"]]:
		it.variaveis["sinal"] = caso[0]
		var ramo = it.escolher_ramo_condicional(linha)
		verificar(typeof(ramo) == TYPE_STRING and ramo == caso[1], "Cadeia deve escolher " + caso[1] + " quando sinal = " + caso[0])
	verificar(it.ultimo_encadeado, "Linha com elif/else deve marcar ultimo_encadeado.")
	it.variaveis["sinal"] = "gelo"
	var sem_ramo = it.escolher_ramo_condicional("if sinal == 'fogo': A")
	verificar(typeof(sem_ramo) == TYPE_STRING and sem_ramo == "", "if falso sem else nao deve escolher ramo.")
	verificar(not it.ultimo_encadeado, "if isolado nao conta como cadeia.")
	verificar(it._resolver_variaveis("sinal == 'fogo'") == "'gelo' == 'fogo'", "Nomes de variaveis dentro de strings nao podem ser substituidos.")
	it.variaveis["hp"] = 3
	it.variaveis["mana"] = 4
	verificar(it._avaliar_condicao("hp < 5 and mana > 2"), "and deve exigir as duas condicoes.")
	verificar(not it._avaliar_condicao("hp > 5 or mana > 10"), "or falso nos dois lados deve ser falso.")
	verificar(it._avaliar_condicao("hp > 5 or mana > 2"), "or deve aceitar um lado verdadeiro.")
	verificar(it.escolher_ramo_condicional("if hp < 5 mover('cima')") == null, "if sem dois-pontos deve ser erro de sintaxe.")
	var resposta = it.executar("if hp > 5: poder = 3")
	verificar("falsa" in resposta and "nenhuma" in resposta.to_lower(), "Mensagem de condicao falsa deve continuar reconhecivel pelo main.gd.")
	it.executar("if hp < 5: poder = 3")
	verificar(it.variaveis.get("poder") == 3, "Ramo pode conter uma atribuicao.")
	it.free()

# ─── Fim da floresta leva para a caverna ────────────────────────────

func _testar_transicao_floresta_caverna():
	await jogo._iniciar_sala(1)
	_limpar_inimigos()
	jogo._concluir_fase_1()
	verificar(jogo.trocando_sala, "Transicao deve travar a troca de sala enquanto espera.")
	await create_timer(1.8).timeout
	verificar(jogo.sala_atual == jogo.SALA_CAVERNA, "Concluir a floresta deve levar a Encruzilhada (sala 5).")
	verificar(not jogo.trocando_sala, "Trava deve ser liberada ao entrar na nova sala.")
	verificar(jogo.gerenciador_inimigos.quantidade_inimigos_vivos() == 2, "Encruzilhada deve ter 2 Ecos.")
	verificar("Fase 2" in jogo._texto_livro_magias(), "Livro deve mostrar os comandos da fase 2.")

# ─── Comporta: if / elif / else de 3 estados ────────────────────────

func _testar_comporta():
	var mapa = jogo.mapa
	var desafio = jogo.desafios_caverna
	verificar(mapa.eh_parede(mapa.COMPORTA_POS), "Comporta fechada deve bloquear passagem.")
	verificar(not _alcanca(mapa, mapa.saida_pos), "Saida nao pode ser alcancada com a comporta fechada.")
	jogo.player.grid_pos = Vector2i(1, 1)
	desafio.comando("desafio(comporta)")
	verificar(not desafio.painel.visible, "Comporta nao deve abrir desafio a distancia.")
	jogo.player.grid_pos = Vector2i(6, 4)
	verificar("desafio(comporta)" in jogo.interpretador.executar("mover('direita')"), "Esbarrar na comporta deve ensinar o comando.")
	desafio._process(0)
	verificar(desafio.dica_proximidade.text.contains("desafio(comporta)"), "Dica deve aparecer ao lado da comporta.")
	var hp_antes = jogo.player.hp
	var mana_antes = jogo.player.mana
	jogo._on_comando_enviado("desafio(comporta)")
	verificar(desafio.painel.visible, "Comando no terminal deve abrir o desafio da comporta.")
	verificar(jogo.player.hp == hp_antes and jogo.player.mana == mana_antes, "Abrir desafio nao deve gastar turno.")
	jogo._on_comando_enviado("mover('cima')")
	verificar(jogo.player.grid_pos == Vector2i(6, 4), "Terminal deve ficar travado com o painel aberto.")
	desafio._fechar()

	var correto = "if temperatura_cristal == 'fria':\n    print('Preciso de mais calor')\nelif temperatura_cristal == 'quente':\n    print('Preciso de menos calor')\nelse:\n    abrir_comporta()"
	var invalidos = [
		"abrir_comporta()",
		"if temperatura_cristal == 'fria':\n    print('Preciso de mais calor')\nelse:\n    abrir_comporta()",
		correto.replace("    abrir_comporta()", "abrir_comporta()"),
		correto.replace("elif", "if"),
		"if temperatura_cristal == 'fria':\n    print('Preciso de mais calor')\nelif temperatura_cristal == 'quente':\n    abrir_comporta()\nelse:\n    print('Preciso de menos calor')",
		"if temperatura_cristal == 'ideal':\n    abrir_comporta()\nelif temperatura_cristal == 'quente':\n    abrir_comporta()\nelse:\n    abrir_comporta()",
	]
	for codigo in invalidos:
		desafio.executar_codigo(codigo)
		verificar(not mapa.comporta_aberta, "Codigo invalido nao deve abrir a comporta: " + codigo)

	jogo.player.grid_pos = Vector2i(1, 1)
	desafio.executar_codigo(correto)
	verificar(not mapa.comporta_aberta, "Comporta exige proximidade.")
	jogo.player.grid_pos = Vector2i(6, 4)
	var aspas_duplas = correto.replace("'Preciso de mais calor'", "\"Preciso de mais calor\"").replace("'Preciso de menos calor'", "\"Preciso de menos calor\"")
	desafio.executar_codigo(aspas_duplas)
	verificar(mapa.comporta_aberta, "Cadeia correta (com aspas duplas) deve abrir a comporta.")
	verificar(_alcanca(mapa, mapa.saida_pos), "Comporta aberta deve liberar o caminho ate a saida.")
	jogo.player.grid_pos = Vector2i(1, 1)

# ─── Ecos elementais ────────────────────────────────────────────────

func _testar_ecos():
	var gi = jogo.gerenciador_inimigos
	var eco_fogo = gi.inimigos.get(Vector2i(3, 2))
	verificar(eco_fogo != null and eco_fogo.elemento_fraqueza == "fogo", "Primeiro Eco da Encruzilhada deve ser de fogo.")
	jogo.interpretador.variaveis["fogo"] = 3
	jogo.interpretador.variaveis["gelo"] = 3
	jogo.player.grid_pos = Vector2i(2, 2)
	var resposta = jogo.player.executar_comando("atacar('direita')")
	verificar("atravessam" in resposta and eco_fogo.hp == 3, "Ataque comum nao deve ferir um Eco.")
	jogo.player.mana = jogo.player.mana_max
	resposta = jogo.interpretador.executar("fireball(gelo, 'direita')")
	verificar("nao afeta" in resposta and eco_fogo.hp == 3, "Elemento errado nao deve ferir o Eco.")
	jogo.player.mana = jogo.player.mana_max
	resposta = jogo.interpretador.executar("fireball(fogo, 'direita')")
	verificar("dissipado" in resposta and not eco_fogo.vivo, "Elemento certo deve dissipar o Eco.")
	verificar(not gi.tem_inimigo(Vector2i(3, 2)), "Eco derrotado deve sair do mapa.")
	verificar(jogo.player.nivel == 2 and jogo.player.xp == 2, "Eco deve dar 7 XP (sobe para o Nv 2 com 2/8).")
	verificar(not jogo.player.pending_escolha.is_empty(), "Subir de nivel na caverna deve pedir uma runa.")
	var pos = jogo.player.grid_pos
	jogo._on_comando_enviado("mover('cima')")
	verificar(jogo.player.grid_pos == pos, "Com runa pendente, o jogo deve esperar a escolha.")
	jogo._on_comando_enviado("escolher(1)")
	verificar(jogo.player.pending_escolha.is_empty(), "escolher(1) deve liberar o jogo.")

# ─── Rodadas: mana volta e inimigos agem na caverna ─────────────────

func _testar_rodadas_na_caverna():
	var gi = jogo.gerenciador_inimigos
	verificar(gi.tem_inimigo(Vector2i(4, 6)), "Eco de gelo deve estar vivo antes da rodada.")
	jogo.player.grid_pos = Vector2i(1, 1)
	jogo.player.mana = 0
	jogo._on_comando_enviado("mover('baixo')")
	verificar(jogo.player.grid_pos == Vector2i(1, 2), "Movimento deve funcionar na caverna.")
	verificar(jogo.player.mana == 1, "Cada rodada na caverna deve recuperar 1 de mana.")
	verificar(not gi.inimigos.has(Vector2i(4, 6)), "Ecos devem perseguir o jogador na caverna.")

# ─── Galerias: saida bloqueada por Ecos, depois avanca ──────────────

func _testar_progressao_das_galerias():
	_limpar_inimigos()
	jogo.player.grid_pos = Vector2i(12, 6)
	jogo._on_comando_enviado("mover('baixo')")
	verificar(jogo.trocando_sala, "Pisar na saida livre deve iniciar a troca de sala.")
	jogo._on_chegou_na_saida()
	await create_timer(1.3).timeout
	verificar(jogo.sala_atual == 6, "Saida da Encruzilhada deve levar a galeria 6 (e so uma vez).")
	verificar(jogo.gerenciador_inimigos.quantidade_inimigos_vivos() == 3, "Galeria 6 deve nascer com 3 inimigos em casas livres.")
	jogo.player.grid_pos = Vector2i(4, 4)
	jogo._on_comando_enviado("mover('cima')")
	await create_timer(1.0).timeout
	verificar(jogo.sala_atual == 6, "Saida com Ecos vivos deve continuar bloqueada.")
	verificar("ainda ecoam" in jogo.output_label.text, "Jogador deve ser avisado dos Ecos restantes.")
	await jogo._iniciar_sala(7)
	verificar(jogo.gerenciador_inimigos.quantidade_inimigos_vivos() == 3, "Galeria 7 deve nascer com 3 inimigos em casas livres.")

# ─── Oraculo Bifurcado ──────────────────────────────────────────────

func _testar_oraculo():
	await jogo._iniciar_sala(jogo.SALA_CAVERNA_CHEFE)
	var gi = jogo.gerenciador_inimigos
	var oraculo = gi.inimigos.get(Vector2i(4, 3))
	verificar(oraculo != null and oraculo.get_script() == load("res://chefe_caverna.gd"), "Oraculo deve nascer no centro do nucleo.")
	if oraculo == null:
		return
	verificar(jogo.interpretador.variaveis.get("sinal_oraculo") == oraculo.sinal_atual, "sinal_oraculo deve refletir o sinal do chefe.")

	jogo.player.grid_pos = Vector2i(2, 1)
	jogo._on_comando_enviado("mover('direita')")
	verificar(not jogo.fase_2_concluida, "Saida deve ficar bloqueada com o Oraculo vivo.")

	jogo.player.grid_pos = Vector2i(1, 3)
	for elemento in ["fogo", "gelo", "arcano"]:
		_enviar(elemento + " = 3")
	verificar(gi.inimigos.get(Vector2i(4, 3)) == oraculo, "Oraculo nao deve sair do lugar.")

	var tentativas = 0
	while oraculo.vivo and oraculo.fase_atual() != "nucleo_arcano" and tentativas < 12:
		tentativas += 1
		jogo.player.mana = jogo.player.mana_max
		_enviar("fireball(" + oraculo.sinal_atual + ", 'direita')")
		verificar(jogo.interpretador.variaveis.get("sinal_oraculo") == oraculo.sinal_atual, "Sinal deve ser sincronizado apos cada ataque.")
	verificar(oraculo.fase_atual() == "nucleo_arcano", "Fases visiveis devem cair com o elemento do sinal.")

	var hp_nucleo = oraculo.hp_fases["nucleo_arcano"]
	if not jogo.player.pending_escolha.is_empty():
		jogo.player.escolher_upgrade(1)
	jogo.player.mana = jogo.player.mana_max
	var resposta = jogo.interpretador.executar("fireball(" + oraculo.sinal_atual + ", 'direita')")
	verificar("ignora respostas isoladas" in resposta and oraculo.hp_fases["nucleo_arcano"] == hp_nucleo, "Nucleo deve exigir uma cadeia if/elif/else.")
	verificar(oraculo.sinal_label.text == "???", "Nucleo deve esconder o sinal.")
	verificar(oraculo.visual.cor == oraculo.COR_OCULTA, "Cor do Nucleo nao pode revelar o sinal.")

	var cadeia = "if sinal_oraculo == 'fogo': fireball(fogo, 'direita') elif sinal_oraculo == 'gelo': fireball(gelo, 'direita') else: fireball(arcano, 'direita')"
	tentativas = 0
	while oraculo.vivo and tentativas < 8:
		tentativas += 1
		jogo.player.mana = jogo.player.mana_max
		_enviar(cadeia)
	verificar(not oraculo.vivo, "Cadeia if/elif/else lendo sinal_oraculo deve derrotar o Nucleo.")
	verificar(not jogo.interpretador.variaveis.has("sinal_oraculo"), "sinal_oraculo deve sumir com o chefe derrotado.")

	jogo.player.grid_pos = Vector2i(2, 1)
	_enviar("mover('direita')")  # o +20 XP do Oraculo costuma pedir uma runa antes
	verificar(jogo.fase_2_concluida, "Saida livre apos o Oraculo deve concluir a fase 2.")

# ─── Reinicio ───────────────────────────────────────────────────────

func _testar_reinicio():
	jogo._reiniciar_run()
	await process_frame
	await process_frame
	verificar(jogo.sala_atual == 0 and not jogo.fase_2_concluida and not jogo.trocando_sala, "reiniciar() deve zerar o estado da fase 2.")

# ─── Utilitarios ────────────────────────────────────────────────────

func _enviar(comando: String):
	if not jogo.player.pending_escolha.is_empty():
		jogo.player.escolher_upgrade(1)
	jogo._on_comando_enviado(comando)

func _limpar_inimigos():
	for filho in jogo.gerenciador_inimigos.get_children():
		filho.queue_free()
	jogo.gerenciador_inimigos.inimigos.clear()

func _alcanca(mapa: Node, alvo: Vector2i) -> bool:
	var fila = [Vector2i(1, 1)]
	var vistos = {}
	while not fila.is_empty():
		var pos: Vector2i = fila.pop_front()
		if pos == alvo:
			return true
		for direcao in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var proxima: Vector2i = pos + direcao
			if vistos.has(proxima):
				continue
			if mapa.posicao_valida(proxima) or proxima == alvo:
				vistos[proxima] = true
				fila.append(proxima)
	return false

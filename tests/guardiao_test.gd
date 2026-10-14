extends SceneTree

# Guardiao de Runas, chefe da Floresta (Tabela 11: variaveis e sintaxe basica;
# RA02: tipos de dados). Cada runa le as variaveis do mago: o numero (valor da
# variavel da fireball), a palavra (texto em feitico) e o Nucleo (as duas juntas).

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
	jogo.mapa.variar_salas = false
	jogo.ia.habilitado = false
	jogo.interpretador.atraso_entre_acoes = 0.0
	await process_frame
	await process_frame
	jogo.debug_console._executar("tutorial_skip")
	await create_timer(0.3).timeout
	await jogo._iniciar_sala(jogo.SALA_FLORESTA)

	var gi = jogo.gerenciador_inimigos
	var chefe = gi.inimigos.get(jogo.mapa.GUARDIAO_POS)
	verificar(chefe != null and chefe.get_script() == load("res://chefe_floresta.gd"), "Guardiao de Runas nasce na arena da Floresta.")
	if chefe == null:
		print("Guardiao: ", falhas, " falhas.")
		quit(1)
		return
	verificar(chefe.parte_atual() == "braco_pedra" and chefe.numero in chefe.NUMEROS and chefe.palavra in chefe.PALAVRAS, "Comeca pelo Braco de Pedra, com numero e palavra sorteados.")
	_so_o_guardiao()
	jogo.mapa.bau_aberto = true
	jogo.mapa.porta_aberta = true
	jogo.player.xp_habilitado = true

	await _testar_anuncio()
	await _testar_arena_e_golpes_comuns(chefe)
	await _testar_runa_do_numero(chefe)
	await _testar_saida_bloqueada()
	await _testar_runa_da_palavra(chefe)
	await _testar_nucleo(chefe)
	await _testar_raizes()
	await _testar_saida_livre()

	print("Guardiao: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

# ─── Utilitarios ────────────────────────────────────────────────────

# As criaturas da floresta perseguiriam o mago ate a arena: so o chefe fica.
func _so_o_guardiao():
	var gi = jogo.gerenciador_inimigos
	for pos in gi.inimigos.keys():
		if gi.inimigos[pos].get_script() != load("res://chefe_floresta.gd"):
			gi.inimigos[pos].queue_free()
			gi.inimigos.erase(pos)

func _saida_de(comandos: Array) -> String:
	var antes = jogo.output_label.text.length()
	for c in comandos:
		await jogo._on_comando_enviado(c)
	return jogo.output_label.text.substr(antes)

# Fireball de dentro da arena, a 2 casas do chefe, com mana e vida cheias.
func _fireball(comandos: Array = []) -> String:
	var p = jogo.player
	p.grid_pos = Vector2i(9, 5)
	p.mana = p.mana_max
	p.hp = p.hp_max
	return await _saida_de(comandos + ["fireball(poder, 'direita')"])

# ─── Anuncio na primeira vez que pisa na arena ──────────────────────

func _testar_anuncio():
	var p = jogo.player
	p.grid_pos = jogo.mapa.PORTA_POS
	var saida = await _saida_de(["mover('direita')"])
	verificar(p.grid_pos == Vector2i(9, 5), "Mago entra na arena pela porta.")
	verificar("O Guardiao de Runas desperta" in saida and "feitico = 'luz'" in saida, "Ao entrar na arena o Guardiao explica as runas.")
	saida = await _saida_de(["mover('cima')", "mover('baixo')"])
	verificar(not ("O Guardiao de Runas desperta" in saida), "O anuncio aparece uma vez so.")
	verificar("Guardiao de Runas" in jogo._texto_livro_magias() and "feitico = 'luz'" in jogo._texto_livro_magias(), "Livro explica as runas do Guardiao.")

# ─── Arena e golpes que nao servem ──────────────────────────────────

func _testar_arena_e_golpes_comuns(chefe: Node):
	var p = jogo.player
	p.grid_pos = Vector2i(10, 5)
	p.hp = p.hp_max
	var saida = await _saida_de(["atacar('direita')"])
	verificar("Ataques comuns nao afetam o Guardiao" in saida and chefe.golpes_restantes == 2, "atacar() nao fere: ele so le variaveis.")
	verificar("[dica 1/3] O Guardiao de Runas" in saida, "Primeira falha de regra mostra o 1o degrau da dica.")
	verificar("esmagou o chao ao seu lado" in saida and p.hp == p.hp_max - 2, "Ao lado dele, o mago e esmagado (2 de dano).")
	verificar(chefe.grid_pos == jogo.mapa.GUARDIAO_POS, "Preso as raizes: nao sai do lugar.")

	p.grid_pos = jogo.mapa.PORTA_POS
	p.mana = p.mana_max
	saida = await _saida_de(["poder = %d" % chefe.numero, "fireball(poder, 'direita')"])
	verificar("protegido pela arena" in saida and chefe.golpes_restantes == 2, "Fireball de fora da arena nao o fere.")

	saida = await _fireball(["poder = '%d'" % chefe.numero])
	verificar("guarda o texto '%d'" % chefe.numero in saida and chefe.golpes_restantes == 2, "'2' entre aspas e texto: a fireball explica o tipo.")

# ─── Braco de Pedra: o VALOR da variavel, que precisa mudar ─────────

func _testar_runa_do_numero(chefe: Node):
	var numero = chefe.numero
	var errado = 1 if numero != 1 else 2
	var saida = await _fireball(["poder = %d" % errado])
	verificar("pede o numero %d, mas poder vale %d" % [numero, errado] in saida and chefe.golpes_restantes == 2, "Valor errado: a runa diz o que pediu e quanto a variavel vale.")
	saida = await _fireball(["poder = %d" % numero])
	verificar("rachada" in saida and chefe.golpes_restantes == 1 and chefe.numero != numero, "Valor certo racha a runa, e ela passa a pedir outro numero.")
	saida = await _fireball()
	verificar("pede o numero %d" % chefe.numero in saida and chefe.golpes_restantes == 1, "Sem trocar o valor da variavel, o 2o golpe nao conta.")
	saida = await _fireball(["poder = %d" % chefe.numero])
	verificar("Braco de Pedra destruido" in saida and chefe.parte_atual() == "braco_cristal", "Trocar o valor (reatribuir) quebra o Braco de Pedra.")
	verificar("feitico = '" + chefe.palavra + "'" in saida, "O Braco de Cristal diz a palavra que pede.")

# ─── A saida continua fechada com o Guardiao de pe ──────────────────

func _testar_saida_bloqueada():
	var p = jogo.player
	p.grid_pos = Vector2i(12, 6)
	var saida = await _saida_de(["mover('baixo')"])
	verificar("O Guardiao de Runas ainda protege a passagem" in saida and not jogo.fase_1_concluida, "Saida bloqueada com o Guardiao vivo.")
	verificar(jogo._topico_dica() == "floresta_guardiao", "dica() fala do Guardiao enquanto ele estiver de pe.")

# ─── Braco de Cristal: um TEXTO na variavel feitico ─────────────────

func _testar_runa_da_palavra(chefe: Node):
	var saida = await _fireball()
	verificar("so baixa a guarda para a palavra '" + chefe.palavra + "'" in saida and chefe.golpes_restantes == 2, "Sem feitico, o Braco de Cristal pede a palavra.")
	saida = await _fireball(["feitico = 3"])
	verificar("pede um TEXTO, mas feitico guarda o numero 3" in saida, "Numero em feitico: a runa explica que precisa de texto.")
	saida = await _fireball(["feitico = True"])
	verificar("o valor logico True" in saida, "True em feitico tambem nao e texto.")
	saida = await _fireball(["feitico = 'pedra'"])
	verificar("pede a palavra '" + chefe.palavra + "', mas feitico guarda 'pedra'" in saida and chefe.golpes_restantes == 2, "Outra palavra nao serve.")
	var palavra = chefe.palavra
	saida = await _fireball(["feitico = '" + palavra.to_upper() + "'"])
	verificar("letra por letra" in saida and chefe.golpes_restantes == 2, "O texto precisa ser igual, letra por letra.")
	saida = await _fireball(["feitico = '" + palavra + "'"])
	verificar("rachada" in saida and chefe.golpes_restantes == 1 and chefe.palavra != palavra, "Palavra certa racha a runa, e ela passa a pedir outra.")
	saida = await _fireball(["feitico = '" + chefe.palavra + "'"])
	verificar("Braco de Cristal destruido" in saida and chefe.parte_atual() == "nucleo", "Trocar o texto quebra o Braco de Cristal.")

# ─── Nucleo: numero e palavra no mesmo golpe ────────────────────────

func _testar_nucleo(chefe: Node):
	var p = jogo.player
	var errado = 1 if chefe.numero != 1 else 2
	var outra = "pedra"
	var saida = await _fireball(["poder = %d" % chefe.numero, "feitico = '" + outra + "'"])
	verificar("O Nucleo pede a palavra" in saida and chefe.vivo, "Nucleo: numero certo e palavra errada nao bastam.")
	saida = await _fireball(["poder = %d" % errado, "feitico = '" + chefe.palavra + "'"])
	verificar("O Nucleo pede o numero" in saida and chefe.vivo, "Nucleo: palavra certa e numero errado nao bastam.")
	saida = await _fireball(["poder = %d" % chefe.numero, "feitico = '" + chefe.palavra + "'"])
	verificar("GUARDIAO DE RUNAS DERROTADO! (+8 XP)" in saida and not chefe.vivo, "Numero e palavra certos derrotam o Guardiao.")
	verificar("[chefe] O Guardiao de Runas foi destruido! A saida esta livre." in saida, "Mensagem de chefe derrotado.")
	verificar(not jogo.gerenciador_inimigos.chefe_vivo() and p.vivo, "Guardiao sai da sala e o mago sobrevive.")

# ─── Raizes: aviso, depois dano so dentro da arena ──────────────────

func _testar_raizes():
	var cena = load("res://chefe_floresta.tscn").instantiate()
	root.add_child(cena)
	cena.inicializar(jogo.mapa.GUARDIAO_POS, jogo.mapa.area_boss_saida_inicio(), jogo.mapa.area_boss_saida_tamanho())
	await process_frame
	var p = jogo.player
	p.hp = p.hp_max
	p.grid_pos = Vector2i(9, 5)
	cena.turnos = 1
	verificar("raizes da arena tremem" in cena.turno_especial(p) and p.hp == p.hp_max, "Um turno antes, as raizes avisam.")
	verificar("Raizes brotam" in cena.turno_especial(p) and p.hp == p.hp_max - 1, "No 3o turno as raizes ferem quem esta na arena.")
	p.hp = p.hp_max
	p.grid_pos = jogo.mapa.PORTA_POS
	cena.turnos = 2
	verificar(cena.turno_especial(p) == "" and p.hp == p.hp_max, "Fora da arena as raizes nao alcancam o mago.")
	cena.queue_free()

# ─── Sem o Guardiao, a saida conclui a Floresta ─────────────────────

func _testar_saida_livre():
	var p = jogo.player
	while not p.pending_escolha.is_empty():
		await jogo._on_comando_enviado("escolher(1)")
	p.grid_pos = Vector2i(12, 6)
	await _saida_de(["mover('baixo')"])
	verificar(jogo.fase_1_concluida, "Com o Guardiao derrotado, a saida conclui a Floresta.")

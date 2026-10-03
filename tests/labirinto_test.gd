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
	jogo.interpretador.atraso_entre_acoes = 0.0
	await process_frame
	await process_frame
	jogo.debug_console._executar("tutorial_skip")
	await create_timer(0.3).timeout

	await _testar_transicao_caverna_labirinto()
	await _testar_corredor_da_nevoa()
	await _testar_camara_dos_elos()
	await _testar_ponte_das_listas()
	await _testar_ouroboros()

	print("Labirinto: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

# ─── Utilitarios ────────────────────────────────────────────────────

func _resolver_runa():
	if not jogo.player.pending_escolha.is_empty():
		await jogo._on_comando_enviado("escolher(1)")

# Roda um programa do grimorio; se pausar por runa, escolhe e roda de novo
# (como o aluno faria).
func _rodar(programa: String, tentativas: int = 4) -> void:
	for i in range(tentativas):
		await _resolver_runa()
		var sala = jogo.sala_atual
		await jogo._executar_programa(programa)
		if jogo.player.pending_escolha.is_empty() or jogo.sala_atual != sala:
			return

func _esperar_sala(indice: int) -> bool:
	for i in range(30):
		if jogo.sala_atual == indice and not jogo.trocando_sala:
			await process_frame
			return true
		await create_timer(0.1).timeout
	return false

# ─── Transicao ──────────────────────────────────────────────────────

func _testar_transicao_caverna_labirinto():
	await jogo._iniciar_sala(jogo.SALA_CAVERNA_CHEFE)
	for filho in jogo.gerenciador_inimigos.get_children():
		filho.queue_free()
	jogo.gerenciador_inimigos.inimigos.clear()
	jogo.player.hp = 3
	jogo._concluir_fase_2()
	verificar(await _esperar_sala(jogo.SALA_LABIRINTO), "Vencer o Oraculo leva ao Labirinto (sala 9).")
	verificar(jogo.player.hp == jogo.player.hp_max, "Entrar no Labirinto cura o mago.")
	verificar("Corredor da Nevoa" in jogo.output_label.text and "while condicao" in jogo.output_label.text, "Sala 9 apresenta o conceito de while (RF016).")
	verificar("Fase 3" in jogo._texto_livro_magias(), "Livro mostra a secao da fase 3.")

# ─── Sala 9: while + sensor ─────────────────────────────────────────

func _testar_corredor_da_nevoa():
	var mapa = jogo.mapa
	verificar(mapa.neblina, "Corredor da sala 9 tem nevoa.")
	var trechos = {}
	for i in range(15):
		await jogo._on_comando_enviado("reiniciar_sala()")
		trechos[mapa.layout_atual[1].count(".")] = true
	verificar(trechos.size() >= 3, "O primeiro trecho do corredor muda de tamanho a cada visita (contar casas nao funciona).")
	await _rodar("for direcao in ['direita', 'baixo', 'direita']:\n    while caminho_livre(direcao):\n        mover(direcao)")
	verificar(await _esperar_sala(jogo.SALA_ELOS), "for de direcoes + while caminho_livre atravessa a nevoa e chega a sala 10.")

# ─── Sala 10: Elos so caem dentro de laco ───────────────────────────

func _testar_camara_dos_elos():
	var gi = jogo.gerenciador_inimigos
	var total = jogo.mapa.elos_pos.size()
	verificar(total >= 4 and gi.quantidade_inimigos_vivos() == total, "Corrente com 4 a 6 Elos.")
	await jogo._on_comando_enviado("mover('direita')")
	var hp_antes = jogo.player.hp
	await jogo._on_comando_enviado("atacar('direita')")
	verificar("absorveu o golpe solto" in jogo.output_label.text and gi.quantidade_inimigos_vivos() == total, "Golpe solto nao parte um Elo.")
	await jogo._executar_programa("atacar('direita')\natacar('direita')")
	verificar(gi.quantidade_inimigos_vivos() == total, "Varias linhas sem laco tambem nao partem Elos.")
	verificar(jogo.player.hp == hp_antes, "Elos sao passivos: nao atacam.")
	await _rodar("while inimigos_restantes() > 0:\n    if inimigo_a_frente('direita'):\n        atacar('direita')\n    else:\n        mover('direita')")
	verificar(gi.quantidade_inimigos_vivos() == 0, "while + if + sensores partem a corrente inteira.")
	verificar(jogo.player.nivel > 1 or jogo.player.xp > 0, "Elos dao XP.")
	await _rodar("while caminho_livre('direita'):\n    mover('direita')")
	verificar(await _esperar_sala(jogo.SALA_PONTE), "Com a corrente partida, a saida leva a sala 11.")

# ─── Sala 11: for sobre a lista passos ──────────────────────────────

func _testar_ponte_das_listas():
	var mapa = jogo.mapa
	var p = jogo.player
	verificar(p.grid_pos == mapa.inicio_pos and mapa.inicio_pos != Vector2i(1, 1), "Ponte comeca na plataforma do meio da borda esquerda.")
	verificar(jogo.interpretador.variaveis.get("passos") == mapa.passos_ponte, "A lista passos e entregue ao aluno.")
	verificar("passos = [" in jogo.output_label.text, "A lista aparece no anuncio da sala.")
	await jogo._on_comando_enviado("mover('esquerda')")
	verificar("so ha abismo" in jogo.output_label.text, "Abismo tem mensagem propria.")
	var primeiro = mapa.passos_ponte[0]
	await jogo._on_comando_enviado("mover('" + primeiro + "')")
	verificar("nao sustenta passos soltos" in jogo.output_label.text and p.grid_pos == mapa.inicio_pos, "Passo solto nao entra na ponte.")
	await jogo._executar_programa("for i in range(2):\n    mover(passos[i])")
	verificar("ela se desfez" in jogo.output_label.text and p.grid_pos == mapa.inicio_pos, "Laco que para no meio da ponte devolve o mago ao inicio.")
	await _rodar("for passo in passos:\n    mover(passo)")
	verificar(await _esperar_sala(jogo.SALA_LABIRINTO_CHEFE), "for passo in passos atravessa a ponte e chega ao chefe.")

# ─── Sala 12: Ouroboros so cai com while ────────────────────────────

func _testar_ouroboros():
	var p = jogo.player
	var gi = jogo.gerenciador_inimigos
	var serpente = gi.inimigos.get(Vector2i(4, 3))
	verificar(serpente != null and serpente.get_script() == load("res://ouroboros.gd"), "Ouroboros nasce no centro da arena.")
	if serpente == null:
		return
	await _resolver_runa()
	for passo in ["baixo", "baixo", "direita", "direita"]:
		await jogo._on_comando_enviado("mover('" + passo + "')")
	verificar(p.grid_pos == Vector2i(3, 3), "Mago chega ao lado da serpente.")
	verificar(gi.inimigos.get(Vector2i(4, 3)) == serpente, "Ouroboros nao sai do lugar.")
	await jogo._on_comando_enviado("poder = 3")
	p.mana = p.mana_max
	await jogo._on_comando_enviado("fireball(poder, 'direita')")
	verificar("refletem a magia" in jogo.output_label.text and serpente.segmentos == 8, "Magia reflete nas escamas.")
	var antes = jogo.output_label.text.length()
	await jogo._executar_programa("for i in range(3):\n    atacar('direita')")
	var saida_for = jogo.output_label.text.substr(antes)
	verificar("se fecha a cada golpe solto" in saida_for and not ("Segmento partido" in saida_for), "for nao fere: so while (condicao de parada).")
	antes = jogo.output_label.text.length()
	# 1 golpe so: mesmo com runas de dano (max. 5) a serpente (8) sobrevive.
	# Zera o contador para o turno do golpe nao coincidir com a renovacao da cauda.
	serpente.turnos = 0
	await jogo._executar_programa("n = 0\nwhile n < 1:\n    atacar('direita')\n    n += 1")
	var saida_while = jogo.output_label.text.substr(antes)
	verificar("Segmento partido" in saida_while, "Golpes dentro do while ferem o Ouroboros.")
	verificar("se fechou de novo" in saida_while and serpente.segmentos == 8, "while que para antes da serpente cair: ela se regenera.")
	p.grid_pos = Vector2i(7, 4)
	await jogo._on_comando_enviado("mover('baixo')")
	verificar("ainda fecha a passagem" in jogo.output_label.text and not jogo.fase_3_concluida, "Saida bloqueada com o Ouroboros vivo.")
	p.grid_pos = Vector2i(3, 3)
	p.hp = p.hp_max
	var antes_luta = jogo.output_label.text.length()
	await _rodar("while inimigo_a_frente('direita'):\n    atacar('direita')")
	var saida_luta = jogo.output_label.text.substr(antes_luta)
	verificar(not serpente.vivo, "while inimigo_a_frente(...) com atacar derrota o Ouroboros.")
	verificar("[ouroboros] A cauda se renova:" in saida_luta, "Durante a luta a cauda se renovou (condicao de parada dinamica).")
	verificar("[ouroboros] O Ouroboros mordeu." in saida_luta and p.vivo, "Ouroboros morde, mas a luta e vencivel.")
	verificar("Ouroboros se rompeu" in jogo.output_label.text, "Mensagem de chefe derrotado.")
	await _resolver_runa()
	p.grid_pos = Vector2i(7, 4)
	await jogo._on_comando_enviado("mover('baixo')")
	verificar(jogo.fase_3_concluida, "Saida livre conclui a fase 3.")

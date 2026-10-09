extends SceneTree

# Eficiencia do codigo (US04): ao concluir cada sala, ate 3 estrelas (concluir,
# sem erros de Python, sem acoes desperdicadas) e o total no fim da run.

const PASTA = "user://metricas_teste_eficiencia"
const PROGRESSO = "user://progresso_eficiencia_teste.cfg"

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

func _esperar_sala(indice: int) -> bool:
	for i in range(30):
		if jogo.sala_atual == indice and not jogo.trocando_sala:
			await process_frame
			return true
		await create_timer(0.1).timeout
	return false

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
	# Continua direto na Torre, como um aluno que ja liberou tudo.
	var p = jogo.progresso
	p.tutorial_concluido = true
	p.bioma_liberado = 3
	p.grimorio_desbloqueado = true
	p.lacos_desbloqueados = true
	p.funcoes_desbloqueadas = true
	jogo.menu.participante_edit.text = "E01"
	await jogo.continuar(3)
	jogo.player.xp_habilitado = false  # sem subir de nivel: nenhum programa e pausado

	await _testar_sala_com_erros()
	await _testar_sala_limpa()
	await _testar_total_da_run()

	_limpar()
	print("Eficiencia: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

# ─── Sala 13: um erro de sintaxe e uma acao desperdicada: 1 estrela ─

func _testar_sala_com_erros():
	await jogo._on_comando_enviado("mover('direita'")
	await jogo._on_comando_enviado("mover('cima')")
	await jogo._on_comando_enviado("for i in range(2): x = i")
	await jogo._executar_programa("def golpe_duplo():\n    atacar('baixo')\n    atacar('baixo')")
	await jogo._executar_programa("for s in range(3):\n    mover('direita')\n    mover('direita')\n    golpe_duplo()\nmover('baixo')\nmover('baixo')\nmover('direita')\nmover('direita')")
	verificar(await _esperar_sala(jogo.SALA_PARAMETROS), "O plano resolve o andar 1 e leva ao andar 2.")
	var texto = jogo.output_label.text
	verificar("[eficiencia] Sala concluida: [*--] 1 de 3 estrelas" in texto, "Erro de sintaxe e acao desperdicada: 1 estrela.")
	verificar("5 programas, 17 turnos (3.4 acoes por programa). Erros de Python: 1. Acoes desperdicadas: 1." in texto, "Relatorio conta programas, turnos, erros e desperdicio.")
	verificar("teste o codigo por partes" in texto and "planeje para nenhuma acao falhar" in texto, "Relatorio diz como ganhar cada estrela que faltou.")

# ─── Sala 14: tudo certo de primeira: 3 estrelas ────────────────────

func _testar_sala_limpa():
	var gi = jogo.gerenciador_inimigos
	var direcoes = {"cima": Vector2i(5, 1), "esquerda": Vector2i(4, 2), "direita": Vector2i(6, 2), "baixo": Vector2i(5, 3)}
	var chamadas: Array = []
	for d in direcoes:
		chamadas.append("golpear('" + d + "', " + str(gi.inimigos[direcoes[d]].golpes_restantes) + ")")
	var programa = "def golpear(direcao, vezes):\n    for i in range(vezes):\n        atacar(direcao)\n" + "\n".join(chamadas) + "\nfor i in range(4):\n    mover('direita')"
	var saida = await _saida_de(func():
		await jogo._executar_programa(programa)
		await _esperar_sala(jogo.SALA_SELO)
	)
	verificar("[eficiencia] Sala concluida: [***] 3 de 3 estrelas" in saida, "Um programa limpo: 3 estrelas. " + saida)
	verificar(not ("Proxima estrela" in saida), "Com 3 estrelas nao ha dica de melhora.")

	var resumo = _resumo(jogo.metricas.caminho_resumo())
	verificar(resumo.get("13", {}).get("estrelas") == "1" and resumo.get("14", {}).get("estrelas") == "3", "Estrelas por sala vao para o resumo das metricas.")
	var eventos = FileAccess.get_file_as_string(jogo.metricas.caminho_eventos())
	verificar(";13;Torre das Funcoes;eficiencia;1;" in eventos and "programas=5, turnos=17, erros=1, desperdicio=1" in eventos, "Evento de eficiencia com os numeros da sala.")

# ─── Fim da run: total de estrelas ──────────────────────────────────

func _testar_total_da_run():
	await jogo._iniciar_sala(jogo.SALA_ARQUIMAGO)
	var saida = await _saida_de(func(): jogo._concluir_torre())
	verificar("[eficiencia] Run completa: 4 de 6 estrelas em 2 salas." in saida, "Fim do jogo mostra o total da run: " + saida)
	verificar(_resumo(jogo.metricas.caminho_resumo()).get("TOTAL", {}).get("estrelas") == "4", "Linha TOTAL soma as estrelas (salas sem programa nao sao avaliadas).")
	await jogo._iniciar_run(3)
	verificar(jogo._eficiencia.is_empty() or jogo._eficiencia.keys() == [jogo.SALA_TORRE], "Run nova zera a eficiencia.")

# ─── Utilitarios ────────────────────────────────────────────────────

func _resumo(caminho: String) -> Dictionary:
	var linhas = FileAccess.get_file_as_string(caminho).split("\n", false)
	var colunas = linhas[0].trim_prefix("﻿").split(";")
	var por_sala = {}
	for linha in Array(linhas).slice(1):
		var valores = linha.split(";")
		var dados = {}
		for i in range(colunas.size()):
			dados[colunas[i]] = valores[i] if i < valores.size() else ""
		por_sala[dados.sala] = dados
	return por_sala

func _limpar():
	if DirAccess.dir_exists_absolute(PASTA):
		for arquivo in DirAccess.get_files_at(PASTA):
			DirAccess.remove_absolute(PASTA.path_join(arquivo))
		DirAccess.remove_absolute(PASTA)
	DirAccess.remove_absolute(PROGRESSO)

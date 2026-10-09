extends SceneTree

# Metricas internas da validacao (secao 4.4 e Tabela 13 do TCC): eventos e resumo
# por sala em CSV, so a partir de uma partida iniciada pelo menu.

const PASTA = "user://metricas_teste"
const PROGRESSO = "user://progresso_metricas_teste.cfg"

var falhas = 0
var jogo: Node

func _initialize():
	call_deferred("_testar")

func verificar(condicao: bool, descricao: String):
	if not condicao:
		falhas += 1
		push_error(descricao)

func _testar():
	_limpar()
	jogo = load("res://main.tscn").instantiate()
	root.add_child(jogo)
	jogo.ia.habilitado = false
	jogo.interpretador.atraso_entre_acoes = 0.0
	jogo.metricas.pasta = PASTA
	jogo.progresso.caminho = PROGRESSO
	jogo.progresso.carregar()
	await process_frame
	await process_frame

	await jogo._executar_programa("mover('direita')")
	verificar(not DirAccess.dir_exists_absolute(PASTA), "Antes de comecar pelo menu nada e gravado.")

	await _testar_programas()
	await _testar_salas_e_desafios()
	await _testar_sessoes()

	_limpar()
	print("Metricas: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

# ─── Programas: cada um com seu resultado ───────────────────────────

func _testar_programas():
	jogo.menu.participante_edit.text = " P07; <x> "
	jogo.menu.novo_jogo_button.emit_signal("pressed")
	for i in range(4):
		await process_frame
	var m = jogo.metricas
	verificar(m.participante == "P07x", "O codigo do participante vira so letras, numeros, - e _.")
	verificar(m.caminho_eventos().get_file().begins_with("P07x_") and FileAccess.file_exists(m.caminho_eventos()), "Novo jogo cria o CSV de eventos com o codigo no nome.")

	for comando in ["mover('direita')", "mover('direita'", "print(nada)", "for i in range(2): mover('baixo')", "print('a;b', \"c\")", "mover('cima')"]:
		await jogo._on_comando_enviado(comando)
	var eventos = _linhas(m.caminho_eventos())
	verificar(eventos[0].trim_prefix("﻿") == "participante;sessao;tempo_s;sala;bioma;evento;resultado;linhas;acoes;acoes_falhas;detalhe", "Cabecalho do CSV de eventos.")
	verificar(FileAccess.get_file_as_bytes(m.caminho_eventos()).slice(0, 3) == PackedByteArray([0xEF, 0xBB, 0xBF]), "CSV comeca com BOM UTF-8 (o Excel mostra os acentos).")
	var programas = eventos.filter(func(l): return ";programa;" in l)
	verificar(programas.size() == 6, "Cada comando vira um evento de programa: " + str(programas.size()))
	if programas.size() < 6:
		return
	verificar(";Tutorial;programa;ok;1;1;0;mover('direita')" in programas[0], "Programa certo: resultado ok, 1 acao. " + programas[0])
	verificar(";programa;erro_sintaxe;" in programas[1], "Erro de sintaxe classificado.")
	verificar(";programa;erro_execucao;" in programas[2], "Erro de execucao classificado.")
	verificar(";programa;bloqueio;" in programas[3], "Conceito ainda bloqueado classificado.")
	verificar(programas[4].ends_with(";\"print('a;b', \"\"c\"\")\""), "Codigo com ; e aspas fica entre aspas no CSV: " + programas[4])
	verificar(";programa;ok;1;1;1;mover('cima')" in programas[5], "Andar contra a parede conta como acao que falhou.")

# ─── Salas, desafios, morte e resumo ────────────────────────────────

func _testar_salas_e_desafios():
	var m = jogo.metricas
	jogo.debug_console._executar("tutorial_skip")
	await create_timer(0.3).timeout
	await jogo._on_comando_enviado("reiniciar_sala()")
	await jogo._on_comando_enviado("if poder > 2:")
	var desafio = jogo.desafios
	jogo.player.grid_pos = Vector2i(3, 6)
	desafio.comando("desafio(bau)")
	desafio.editor.text = "selos = 2\nabrir_bau(selos)"
	desafio._executar()
	desafio.editor.text = "selos = 3\nabrir_bau(selos)"
	desafio._executar()
	desafio.editor.text = "selos = 3\nabrir_bau(selos)"
	desafio._executar()
	desafio._fechar()
	jogo.player._receber_dano(jogo.player.hp, "Teste.")

	var eventos = "\n".join(_linhas(m.caminho_eventos()))
	verificar(";tutorial_concluido;" in eventos, "Fim do tutorial registrado.")
	verificar(";0;Tutorial;sala_concluida;" in eventos, "Sair do tutorial conclui a sala 0.")
	verificar(";1;Floresta dos Primeiros Passos;sala_reiniciada;" in eventos, "reiniciar_sala() registrado.")
	verificar(";desafio_bau;falha;" in eventos and ";desafio_bau;sucesso;" in eventos, "Tentativas do bau registradas.")
	verificar(";1;Floresta dos Primeiros Passos;morte;" in eventos, "Morte registrada na sala.")

	var resumo = _resumo(m.caminho_resumo())
	var tutorial = resumo.get("0", {})
	verificar(tutorial.get("programas") == "6" and tutorial.get("erros_sintaxe") == "1" and tutorial.get("erros_execucao") == "1", "Resumo do tutorial conta programas e erros: " + str(tutorial))
	verificar(tutorial.get("bloqueios") == "1" and tutorial.get("acoes_falhas") == "1" and tutorial.get("concluida") == "1", "Resumo do tutorial: bloqueio, acao que falhou e sala concluida.")
	var floresta = resumo.get("1", {})
	verificar(floresta.get("reinicios") == "1" and floresta.get("mortes") == "1" and floresta.get("concluida") == "0", "Resumo da Floresta: reinicio, morte e sala nao concluida: " + str(floresta))
	verificar(floresta.get("desafio_tentativas") == "2" and floresta.get("desafio_falhas") == "1", "Bau resolvido nao conta tentativas extras.")
	verificar(floresta.get("bloqueios") == "1", "Bloco com : antes do grimorio conta como bloqueio.")
	var total = resumo.get("TOTAL", {})
	verificar(total.get("programas") == "7" and total.get("mortes") == "1" and total.get("jogo_concluido") == "0", "Linha TOTAL soma as salas: " + str(total))

# ─── Sessoes: mesmo codigo continua, codigo novo abre outra ─────────

func _testar_sessoes():
	var m = jogo.metricas
	var arquivo = m.caminho_eventos()
	await jogo._on_comando_enviado("reiniciar()")
	await jogo.continuar(0)
	verificar(m.caminho_eventos() == arquivo, "Mesmo participante: a nova run continua a sessao.")
	verificar(_linhas(arquivo).any(func(l): return ";voltou_ao_menu;" in l), "reiniciar() (voltar ao menu) registrado.")
	var runs = _linhas(arquivo).filter(func(l): return ";run_inicio;" in l)
	verificar(runs.size() == 2 and runs[1].ends_with(";Floresta dos Primeiros Passos"), "Cada run registra o bioma de inicio.")
	var floresta = _resumo(m.caminho_resumo()).get("1", {})
	verificar(floresta.get("visitas") == "2", "Voltar a mesma sala soma visitas.")
	m.fechar()
	verificar(_resumo(m.caminho_resumo()).has("TOTAL"), "fechar() regrava o resumo (ao fechar a janela).")
	jogo.menu.abrir()
	jogo.menu.participante_edit.text = "P08"
	await jogo.continuar(0)
	verificar(m.participante == "P08" and m.caminho_eventos() != arquivo and m.caminho_eventos().get_file().begins_with("P08_"), "Outro codigo abre outra sessao.")
	verificar("P08" in jogo.debug_console._executar("metricas"), "Comando metricas do console mostra os arquivos.")

# ─── Utilitarios ────────────────────────────────────────────────────

func _linhas(caminho: String) -> Array:
	return Array(FileAccess.get_file_as_string(caminho).split("\n", false))

func _resumo(caminho: String) -> Dictionary:
	var linhas = _linhas(caminho)
	var colunas = linhas[0].trim_prefix("﻿").split(";")
	var por_sala = {}
	for linha in linhas.slice(1):
		var valores = linha.split(";")
		var dados = {}
		for i in range(colunas.size()):
			dados[colunas[i]] = valores[i] if i < valores.size() else ""
		por_sala[dados.sala] = dados
	return por_sala

func _limpar():
	if not DirAccess.dir_exists_absolute(PASTA):
		DirAccess.remove_absolute(PROGRESSO)
		return
	for arquivo in DirAccess.get_files_at(PASTA):
		DirAccess.remove_absolute(PASTA.path_join(arquivo))
	DirAccess.remove_absolute(PASTA)
	DirAccess.remove_absolute(PROGRESSO)

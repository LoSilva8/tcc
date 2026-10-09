extends RefCounted

# Metricas internas para a validacao (secao 4.4 e Tabela 13 do TCC): tentativas,
# erros de sintaxe e de execucao, tempo por sala, desafios e progressao entre
# biomas. Cada sessao gera dois CSV em user://metricas: os eventos, um por linha,
# e o resumo por sala. Nao guarda nome, so o codigo do participante (ex.: P01).
# Separador ";" para o Excel em portugues abrir direto.

const PASTA_PADRAO = "user://metricas"
const SEP = ";"
const COLUNAS_EVENTOS = ["participante", "sessao", "tempo_s", "sala", "bioma", "evento", "resultado", "linhas", "acoes", "acoes_falhas", "detalhe"]
const COLUNAS_RESUMO = ["participante", "sessao", "sala", "bioma", "visitas", "tempo_s", "programas", "erros_sintaxe", "erros_execucao", "bloqueios", "interrompidos", "acoes_falhas", "desafio_tentativas", "desafio_falhas", "reinicios", "mortes", "dicas", "concluida", "biomas_concluidos", "jogo_concluido"]
const ESTATISTICAS = ["visitas", "tempo_ms", "programas", "erros_sintaxe", "erros_execucao", "bloqueios", "interrompidos", "acoes_falhas", "desafio_tentativas", "desafio_falhas", "reinicios", "mortes", "dicas"]

var pasta = PASTA_PADRAO
# So grava depois que a partida comeca pelo menu: os testes instanciam o jogo
# direto e nunca escrevem na pasta real.
var ativo = false
var participante = ""
var sessao = ""

var _inicio_ms = 0
var _arquivo_eventos = ""
var _arquivo_resumo = ""
var _salas: Dictionary = {}  # indice -> {bioma, concluida e as ESTATISTICAS}
var _ordem_salas: Array = []
var _sala_atual = -1
var _entrada_ms = 0
var _biomas_concluidos: Array = []
var _jogo_concluido = false

# Chamado a cada Novo jogo / Continuar. Um codigo novo abre uma sessao nova;
# o mesmo codigo continua a sessao (o participante pode morrer e voltar ao menu).
func comecar(codigo: String, bioma: String):
	var limpo = _limpar_codigo(codigo)
	if sessao == "" or limpo != participante:
		_nova_sessao(limpo)
	_sair_da_sala()
	_sala_atual = -1
	_evento("run_inicio", "", bioma)

func entrar_sala(indice: int, bioma: String):
	if not ativo:
		return
	if indice == _sala_atual:
		_estatisticas().reinicios += 1
		_evento("sala_reiniciada")
		return
	if _sala_atual >= 0:
		_salas[_sala_atual].concluida = true
		_evento("sala_concluida")
	_sair_da_sala()
	_sala_atual = indice
	_entrada_ms = Time.get_ticks_msec()
	if not _salas.has(indice):
		var nova = {"bioma": bioma, "concluida": false}
		for chave in ESTATISTICAS:
			nova[chave] = 0
		_salas[indice] = nova
		_ordem_salas.append(indice)
	_salas[indice].visitas += 1
	_evento("sala_inicio")

# resumo vem de interpretador.resumo_execucao().
func programa(codigo: String, resumo: Dictionary):
	if not ativo or _sala_atual < 0:
		return
	var s = _estatisticas()
	s.programas += 1
	s.acoes_falhas += resumo.acoes_falhas
	var resultado = "ok"
	match resumo.erro:
		"sintaxe":
			resultado = "erro_sintaxe"
			s.erros_sintaxe += 1
		"execucao":
			resultado = "erro_execucao"
			s.erros_execucao += 1
		"bloqueio":
			resultado = "bloqueio"
			s.bloqueios += 1
		_:
			if resumo.interrupcao != "":
				resultado = "interrompido_" + resumo.interrupcao
				s.interrompidos += 1
	var linhas = codigo.strip_edges().split("\n").size()
	_evento("programa", resultado, codigo, str(linhas), str(resumo.acoes), str(resumo.acoes_falhas))

func desafio(nome: String, sucesso: bool, detalhe: String = ""):
	if not ativo or _sala_atual < 0:
		return
	var s = _estatisticas()
	s.desafio_tentativas += 1
	if not sucesso:
		s.desafio_falhas += 1
	_evento("desafio_" + nome, "sucesso" if sucesso else "falha", detalhe)

func morte():
	if not ativo or _sala_atual < 0:
		return
	_estatisticas().mortes += 1
	_evento("morte")

func dica(gerada_por_ia: bool):
	if not ativo or _sala_atual < 0:
		return
	_estatisticas().dicas += 1
	_evento("dica", "ia" if gerada_por_ia else "local")

func marcar(evento: String, detalhe: String = ""):
	if ativo:
		_evento(evento, "", detalhe)

func bioma_concluido(nome: String):
	if not ativo:
		return
	if not nome in _biomas_concluidos:
		_biomas_concluidos.append(nome)
	_evento("bioma_concluido", "", nome)

func concluir_jogo():
	if not ativo:
		return
	_jogo_concluido = true
	if _sala_atual >= 0:
		_salas[_sala_atual].concluida = true
	_evento("jogo_concluido")

# Fecha o tempo da sala atual e regrava o resumo (ex.: ao fechar o jogo).
func fechar():
	if not ativo or sessao == "":
		return
	_sair_da_sala()
	_entrada_ms = Time.get_ticks_msec()
	_salvar_resumo()

func caminho_eventos() -> String:
	return _arquivo_eventos

func caminho_resumo() -> String:
	return _arquivo_resumo

# ─── Internos ───────────────────────────────────────────────────────

func _nova_sessao(codigo: String):
	participante = codigo
	sessao = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "-")
	_inicio_ms = Time.get_ticks_msec()
	_salas = {}
	_ordem_salas = []
	_sala_atual = -1
	_biomas_concluidos = []
	_jogo_concluido = false
	DirAccess.make_dir_recursive_absolute(pasta)
	var base = pasta.path_join(participante + "_" + sessao)
	_arquivo_eventos = base + "_eventos.csv"
	_arquivo_resumo = base + "_resumo.csv"
	var arquivo = FileAccess.open(_arquivo_eventos, FileAccess.WRITE)
	if arquivo:
		# BOM: o Excel reconhece UTF-8 e mostra acentos do codigo do aluno.
		arquivo.store_string("﻿" + SEP.join(COLUNAS_EVENTOS) + "\n")
		arquivo.close()

func _estatisticas() -> Dictionary:
	return _salas[_sala_atual]

func _sair_da_sala():
	if _sala_atual >= 0 and _salas.has(_sala_atual):
		_salas[_sala_atual].tempo_ms += Time.get_ticks_msec() - _entrada_ms

func _evento(evento: String, resultado: String = "", detalhe: String = "", linhas: String = "", acoes: String = "", falhas: String = ""):
	var bioma = _salas[_sala_atual].bioma if _salas.has(_sala_atual) else ""
	var sala = str(_sala_atual) if _sala_atual >= 0 else ""
	var tempo = str(int((Time.get_ticks_msec() - _inicio_ms) / 1000))
	var campos = [participante, sessao, tempo, sala, bioma, evento, resultado, linhas, acoes, falhas, detalhe]
	var arquivo = FileAccess.open(_arquivo_eventos, FileAccess.READ_WRITE)
	if arquivo:
		arquivo.seek_end()
		arquivo.store_string(_linha_csv(campos))
		arquivo.close()
	_salvar_resumo()

func _salvar_resumo():
	var arquivo = FileAccess.open(_arquivo_resumo, FileAccess.WRITE)
	if arquivo == null:
		return
	var texto = "﻿" + SEP.join(COLUNAS_RESUMO) + "\n"
	var total = {"visitas": 0}
	for chave in ESTATISTICAS:
		total[chave] = 0
	for indice in _ordem_salas:
		var s = _salas[indice]
		var tempo = s.tempo_ms + (Time.get_ticks_msec() - _entrada_ms if indice == _sala_atual else 0)
		for chave in ESTATISTICAS:
			total[chave] += tempo if chave == "tempo_ms" else s[chave]
		texto += _linha_csv(_linha_resumo(str(indice), s.bioma, s, tempo, "1" if s.concluida else "0", "", ""))
	var biomas = "|".join(_biomas_concluidos)
	texto += _linha_csv(_linha_resumo("TOTAL", "", total, total.tempo_ms, "", biomas, "1" if _jogo_concluido else "0"))
	arquivo.store_string(texto)
	arquivo.close()

func _linha_resumo(sala: String, bioma: String, s: Dictionary, tempo_ms: int, concluida: String, biomas: String, jogo: String) -> Array:
	return [participante, sessao, sala, bioma, str(s.visitas), str(int(tempo_ms / 1000)), str(s.programas),
		str(s.erros_sintaxe), str(s.erros_execucao), str(s.bloqueios), str(s.interrompidos), str(s.acoes_falhas),
		str(s.desafio_tentativas), str(s.desafio_falhas), str(s.reinicios), str(s.mortes), str(s.dicas),
		concluida, biomas, jogo]

func _linha_csv(campos: Array) -> String:
	var partes: Array = []
	for campo in campos:
		var texto = str(campo).replace("\r", "").replace("\n", "\\n")
		if SEP in texto or "\"" in texto:
			texto = "\"" + texto.replace("\"", "\"\"") + "\""
		partes.append(texto)
	return SEP.join(partes) + "\n"

# So letras, numeros, - e _: o codigo vira parte do nome do arquivo.
func _limpar_codigo(codigo: String) -> String:
	var limpo = ""
	for c in codigo.strip_edges():
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c in "-_":
			limpo += c
	limpo = limpo.substr(0, 20)
	return limpo if limpo != "" else "anonimo"

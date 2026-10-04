extends Node

# Interpretador de um subconjunto real de Python para o PyAdventure.
#
# Fluxo: texto -> tokens (com INDENT/DEDENT, como o Python) -> arvore -> execucao.
# A execucao e uma corrotina: cada ACAO (mover, atacar, fireball) e um turno do
# jogo e, entre duas acoes, o interpretador espera `atraso_entre_acoes` segundos
# para o jogador ver o laco acontecendo. Programas com uma acao so terminam no
# mesmo frame (o `await` nao pausa), entao comandos simples continuam instantaneos.
# Funcoes do jogador (def) tambem podem agir, entao rodam antes de avaliar cada
# expressao (ver _resolver), cada chamada com seu escopo local (ver _locais).

signal linha_executando(linha: int)

const ACOES_COM_TURNO = ["mover", "atacar", "fireball"]
const COMANDOS = ["mover", "atacar", "fireball", "escolher", "print"]
const PALAVRAS_RESERVADAS = ["if", "elif", "else", "for", "while", "in", "not", "and", "or",
	"break", "continue", "pass", "True", "False", "None", "def", "return", "class",
	"import", "lambda", "try", "except", "with", "global", "del", "is", "yield"]
const DIRECOES = {
	"direita": Vector2i(1, 0),
	"esquerda": Vector2i(-1, 0),
	"cima": Vector2i(0, -1),
	"baixo": Vector2i(0, 1),
}
const MAX_ACOES = 80
const MAX_PASSOS = 3000
const MAX_FALHAS_SEGUIDAS = 3
const MAX_RANGE = 100
const MAX_CHAMADAS_ANINHADAS = 30
# Nomes que ja sao do jogo: o aluno nao pode criar funcoes com eles.
const NOMES_DO_JOGO = ["mover", "atacar", "fireball", "escolher", "print", "range", "len", "str",
	"int", "abs", "min", "max", "caminho_livre", "inimigo_a_frente", "inimigos_restantes",
	"minha_vida", "minha_mana", "abrir_bau", "abrir_porta", "abrir_comporta", "reiniciar",
	"reiniciar_sala", "desafio", "atacar_com"]

var variaveis: Dictionary = {}
# Funcoes criadas com def. Como as variaveis, continuam valendo nos proximos comandos.
var funcoes: Dictionary = {}
var player: Node = null
var ultimo_encadeado: bool = false
var atraso_entre_acoes: float = 0.0
var ao_agir: Callable
var ao_escrever: Callable
var executando: bool = false
# Progressao por bioma: o main desliga os lacos ate o Labirinto dos Lacos.
var lacos_liberados: bool = true
# Idem para def/return, liberados na Torre das Funcoes.
var funcoes_liberadas: bool = true

var _tokens: Array = []
var _pos: int = 0
var _erro: String = ""
var _erro_linha: int = 0
var _erro_tipo: String = ""
var _erro_cru: bool = false
var _sinal: String = ""
var _saidas: Array = []
var _acoes: int = 0
var _passos: int = 0
var _falhas_seguidas: int = 0
var _profundidade_cadeia: int = 0
var _profundidade_laco: int = 0
var _profundidade_while: int = 0
var _cancelar: bool = false
var _multilinha: bool = false
# Pilha de escopos: um dicionario de variaveis locais por chamada de funcao em andamento.
var _locais: Array = []
var _retorno = null
# Contadores do parser: break/continue so dentro de laco, return so dentro de def,
# def so fora de blocos.
var _parse_lacos: int = 0
var _parse_funcoes: int = 0
var _parse_blocos: int = 0

# ─── API publica ────────────────────────────────────────────────────

func executar(codigo: String) -> String:
	_preparar_execucao()
	_multilinha = codigo.strip_edges().contains("\n")
	var programa = _compilar(codigo)
	if _erro != "":
		_escrever(_mensagem_erro())
		executando = false
		return "\n".join(_saidas)
	await _exec_bloco(programa)
	executando = false
	return "\n".join(_saidas)

func cancelar_execucao():
	if executando:
		_cancelar = true

func dentro_de_laco() -> bool:
	return _profundidade_laco > 0

func dentro_de_while() -> bool:
	return _profundidade_while > 0

func dentro_de_funcao() -> bool:
	return not _locais.is_empty()

# Usado pelos desafios (bau/porta, comporta) para testar uma condicao isolada.
func _avaliar_condicao(condicao: String) -> bool:
	_erro = ""
	_tokens = _tokenizar(condicao.strip_edges())
	if _erro != "":
		return false
	_pos = 0
	var no = _parse_expr()
	if _erro != "":
		return false
	var resultado = _verdadeiro(_avaliar(no))
	return resultado and _erro == ""

# ─── Preparacao ─────────────────────────────────────────────────────

func _preparar_execucao():
	executando = true
	_erro = ""
	_erro_linha = 0
	_erro_tipo = ""
	_erro_cru = false
	_sinal = ""
	_saidas = []
	_acoes = 0
	_passos = 0
	_falhas_seguidas = 0
	_profundidade_cadeia = 0
	_profundidade_laco = 0
	_profundidade_while = 0
	_cancelar = false
	_locais = []
	_retorno = null

func _compilar(codigo: String) -> Array:
	_tokens = _tokenizar(codigo)
	if _erro != "":
		return []
	_pos = 0
	_parse_lacos = 0
	_parse_funcoes = 0
	_parse_blocos = 0
	var programa: Array = []
	while _ver().t != "FIM" and _erro == "":
		var s = _parse_stmt()
		if _erro != "":
			return []
		programa.append(s)
	return programa

# ─── Tokens ─────────────────────────────────────────────────────────

func _tok(tipo: String, valor, linha: int) -> Dictionary:
	return {"t": tipo, "v": valor, "l": linha}

func _tokenizar(codigo: String) -> Array:
	var toks: Array = []
	var linhas = codigo.replace("\r", "").replace("\t", "    ").split("\n")
	var pilha: Array = [0]
	var profundidade = 0
	for n in range(linhas.size()):
		var linha: String = linhas[n]
		var num = n + 1
		var i = 0
		if profundidade == 0:
			var conteudo = linha.strip_edges()
			if conteudo == "" or conteudo.begins_with("#"):
				continue
			var recuo = 0
			while recuo < linha.length() and linha[recuo] == " ":
				recuo += 1
			if recuo > pilha.back():
				pilha.append(recuo)
				toks.append(_tok("INDENT", "", num))
			else:
				while recuo < pilha.back():
					pilha.pop_back()
					toks.append(_tok("DEDENT", "", num))
				if recuo != pilha.back():
					_definir_erro("O recuo desta linha nao combina com nenhum bloco acima. Use multiplos de 4 espacos.", num, "sintaxe")
					return []
			i = recuo
		while i < linha.length():
			var c = linha[i]
			if c == " ":
				i += 1
				continue
			if c == "#":
				break
			if _letra(c):
				var j = i
				while j < linha.length() and (_letra(linha[j]) or _digito(linha[j])):
					j += 1
				toks.append(_tok("NOME", linha.substr(i, j - i), num))
				i = j
				continue
			if _digito(c):
				var j = i
				var tem_ponto = false
				while j < linha.length():
					if _digito(linha[j]):
						j += 1
					elif linha[j] == "." and not tem_ponto and j + 1 < linha.length() and _digito(linha[j + 1]):
						tem_ponto = true
						j += 1
					else:
						break
				var texto_num = linha.substr(i, j - i)
				toks.append(_tok("NUM", texto_num.to_float() if tem_ponto else texto_num.to_int(), num))
				i = j
				continue
			if c == "'" or c == "\"":
				var j = i + 1
				var valor = ""
				var fechou = false
				while j < linha.length():
					var d = linha[j]
					if d == "\\" and j + 1 < linha.length():
						var e = linha[j + 1]
						valor += "\n" if e == "n" else e
						j += 2
						continue
					if d == c:
						fechou = true
						break
					valor += d
					j += 1
				if not fechou:
					_definir_erro("Faltou fechar as aspas do texto. Abra e feche com o mesmo tipo: 'assim' ou \"assim\".", num, "sintaxe")
					return []
				toks.append(_tok("STR", valor, num))
				i = j + 1
				continue
			var dois = linha.substr(i, 2)
			if dois in ["==", "!=", "<=", ">=", "//", "+=", "-=", "*="]:
				toks.append(_tok("OP", dois, num))
				i += 2
				continue
			if c in "+-*/%<>=()[],:":
				if c == "(" or c == "[":
					profundidade += 1
				elif c == ")" or c == "]":
					profundidade = max(profundidade - 1, 0)
				toks.append(_tok("OP", c, num))
				i += 1
				continue
			_definir_erro("Simbolo inesperado: " + c, num, "sintaxe")
			return []
		if profundidade == 0:
			toks.append(_tok("NL", "", num))
	if profundidade > 0:
		_definir_erro("Faltou fechar um parentese ( ou colchete [.", linhas.size(), "sintaxe")
		return []
	var ultima = linhas.size()
	while pilha.size() > 1:
		pilha.pop_back()
		toks.append(_tok("DEDENT", "", ultima))
	toks.append(_tok("FIM", "", ultima))
	return toks

func _letra(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"

func _digito(c: String) -> bool:
	return c >= "0" and c <= "9"

# ─── Parser ─────────────────────────────────────────────────────────

func _ver(offset: int = 0) -> Dictionary:
	if _tokens.is_empty():
		return _tok("FIM", "", 0)
	return _tokens[min(_pos + offset, _tokens.size() - 1)]

func _avancar() -> Dictionary:
	var t = _ver()
	if _pos < _tokens.size() - 1:
		_pos += 1
	return t

func _eh(tipo: String, valor = null, offset: int = 0) -> bool:
	var t = _ver(offset)
	return t.t == tipo and (valor == null or t.v == valor)

func _esperar_op(valor: String, mensagem: String) -> bool:
	if _eh("OP", valor):
		_avancar()
		return true
	_definir_erro(mensagem, _ver().l, "sintaxe")
	return false

func _esperar_fim_de_linha():
	if _eh("NL"):
		_avancar()
		return
	if _eh("FIM") or _eh("DEDENT"):
		return
	if _eh("NOME") and _ver().v in ["elif", "else"]:
		_definir_erro("Em Python, " + _ver().v + " comeca em uma linha nova, alinhado com o if. Abra o grimorio ({ }) para escrever varias linhas.", _ver().l, "sintaxe")
		return
	if _eh("OP", "="):
		_definir_erro("Um = sozinho guarda valor. Para comparar use ==.", _ver().l, "sintaxe")
		return
	_definir_erro("Algo sobrou no fim da linha: '" + str(_ver().v) + "'. Cada linha deve ter um unico comando.", _ver().l, "sintaxe")

func _parse_stmt() -> Dictionary:
	var t = _ver()
	if t.t == "INDENT":
		_definir_erro("Recuo inesperado: esta linha esta mais para dentro, mas nao ha if, for ou while acima dela.", t.l, "sintaxe")
		return {}
	if t.t == "NOME":
		match t.v:
			"if":
				return _parse_if()
			"while", "for":
				if not lacos_liberados:
					_definir_erro("Ainda nao: lacos (for e while) serao liberados no Labirinto dos Lacos. Por enquanto, repita o comando linha a linha.", t.l, "bloqueio")
					return {}
				return _parse_while() if t.v == "while" else _parse_for()
			"elif", "else":
				_definir_erro("'" + t.v + "' apareceu sem um if antes. Ele precisa ficar alinhado com o if do mesmo bloco.", t.l, "sintaxe")
				return {}
			"def":
				return _parse_def()
	var s = _parse_simples()
	if _erro != "":
		return {}
	_esperar_fim_de_linha()
	return s

func _parse_simples() -> Dictionary:
	var t = _ver()
	if t.t == "NOME":
		match t.v:
			"pass", "break", "continue":
				if t.v != "pass" and _parse_lacos == 0:
					_definir_erro("'" + t.v + "' so pode ser usado dentro de um for ou while.", t.l, "sintaxe")
					return {}
				_avancar()
				return {"t": t.v, "l": t.l}
			"return":
				if _funcoes_bloqueadas(t):
					return {}
				if _parse_funcoes == 0:
					_definir_erro("'return' so pode aparecer dentro de uma funcao (def): ele devolve o resultado dela.", t.l, "sintaxe")
					return {}
				_avancar()
				var devolve = null
				if not (_eh("NL") or _eh("FIM") or _eh("DEDENT")):
					devolve = _parse_expr()
				return {"t": "return", "expr": devolve, "l": t.l}
			"if", "for", "while":
				_definir_erro("Um bloco " + t.v + " dentro de outro precisa comecar em uma linha nova, com recuo.", t.l, "sintaxe")
				return {}
			"def":
				return _parse_def()
		if _eh("OP", "=", 1):
			if t.v in PALAVRAS_RESERVADAS:
				_definir_erro("'" + t.v + "' e uma palavra reservada do Python e nao pode ser nome de variavel.", t.l, "sintaxe")
				return {}
			_avancar()
			_avancar()
			var expr = _parse_expr()
			return {"t": "atrib", "nome": t.v, "expr": expr, "l": t.l}
		if _ver(1).t == "OP" and _ver(1).v in ["+=", "-=", "*="]:
			_avancar()
			var op = _avancar().v
			var expr2 = _parse_expr()
			return {"t": "atrib_op", "nome": t.v, "op": op.substr(0, 1), "expr": expr2, "l": t.l}
	var e = _parse_expr()
	return {"t": "expr", "expr": e, "l": t.l}

func _parse_bloco(cabecalho: String) -> Array:
	if not _esperar_op(":", "Faltou ':' no fim do " + cabecalho + ". Ex.: " + cabecalho + " ...:"):
		return []
	_parse_blocos += 1
	var corpo = _parse_corpo(cabecalho)
	_parse_blocos -= 1
	return corpo

func _parse_corpo(cabecalho: String) -> Array:
	if _eh("NL"):
		_avancar()
		if not _eh("INDENT"):
			_definir_erro("Depois de '" + cabecalho + " ...:' a linha de baixo precisa de recuo (4 espacos).", _ver().l, "sintaxe")
			return []
		_avancar()
		var corpo: Array = []
		while not _eh("DEDENT") and not _eh("FIM") and _erro == "":
			corpo.append(_parse_stmt())
		if _eh("DEDENT"):
			_avancar()
		return corpo
	var s = _parse_simples()
	if _erro != "":
		return []
	_esperar_fim_de_linha()
	return [s]

func _parse_condicao(cabecalho: String):
	var cond = _parse_expr()
	if _erro == "" and _eh("OP", "="):
		_definir_erro("No " + cabecalho + ", para comparar use ==. Um = sozinho guarda valor.", _ver().l, "sintaxe")
	return cond

func _parse_if() -> Dictionary:
	var linha = _avancar().l
	var clausulas: Array = []
	var cond = _parse_condicao("if")
	if _erro != "":
		return {}
	clausulas.append({"cond": cond, "corpo": _parse_bloco("if")})
	while _erro == "" and _eh("NOME", "elif"):
		_avancar()
		var c2 = _parse_condicao("elif")
		if _erro != "":
			return {}
		clausulas.append({"cond": c2, "corpo": _parse_bloco("elif")})
	var senao = null
	if _erro == "" and _eh("NOME", "else"):
		_avancar()
		senao = _parse_bloco("else")
	return {"t": "if", "clausulas": clausulas, "senao": senao, "l": linha}

func _parse_while() -> Dictionary:
	var linha = _avancar().l
	var cond = _parse_condicao("while")
	if _erro != "":
		return {}
	_parse_lacos += 1
	var corpo = _parse_bloco("while")
	_parse_lacos -= 1
	return {"t": "while", "cond": cond, "corpo": corpo, "l": linha}

func _parse_for() -> Dictionary:
	var linha = _avancar().l
	if not _eh("NOME") or _ver().v in PALAVRAS_RESERVADAS:
		_definir_erro("Depois de for vem o nome de uma variavel. Ex.: for passo in passos:", linha, "sintaxe")
		return {}
	var nome = _avancar().v
	if not _eh("NOME", "in"):
		_definir_erro("Faltou o 'in' no for. Ex.: for " + nome + " in range(3):", linha, "sintaxe")
		return {}
	_avancar()
	var iteravel = _parse_expr()
	if _erro != "":
		return {}
	_parse_lacos += 1
	var corpo = _parse_bloco("for")
	_parse_lacos -= 1
	return {"t": "for", "var": nome, "iter": iteravel, "corpo": corpo, "l": linha}

func _parse_def() -> Dictionary:
	var t = _ver()
	if _funcoes_bloqueadas(t):
		return {}
	var linha = _avancar().l
	if _parse_blocos > 0:
		_definir_erro("Crie funcoes fora de if, for, while e de outras funcoes: o def comeca sem recuo.", linha, "sintaxe")
		return {}
	if not _eh("NOME") or _ver().v in PALAVRAS_RESERVADAS:
		_definir_erro("Depois de def vem o nome da funcao. Ex.: def atacar_duas_vezes(direcao):", linha, "sintaxe")
		return {}
	var nome = _avancar().v
	if nome in NOMES_DO_JOGO:
		_definir_erro("'" + nome + "' ja e um comando do jogo. Escolha outro nome para a sua funcao.", linha, "sintaxe")
		return {}
	if not _esperar_op("(", "Faltou '(' depois do nome. Ex.: def " + nome + "():"):
		return {}
	var params: Array = []
	while _erro == "" and not _eh("OP", ")"):
		if not _eh("NOME") or _ver().v in PALAVRAS_RESERVADAS:
			_definir_erro("Os parametros sao nomes de variaveis separados por virgula. Ex.: def " + nome + "(direcao, vezes):", linha, "sintaxe")
			return {}
		var param = _avancar().v
		if param in params:
			_definir_erro("O parametro '" + param + "' aparece duas vezes em " + nome + "(...).", linha, "sintaxe")
			return {}
		params.append(param)
		if _eh("OP", ","):
			_avancar()
		elif not _eh("OP", ")"):
			_definir_erro("Separe os parametros com virgula. Ex.: def " + nome + "(direcao, vezes):", linha, "sintaxe")
			return {}
	if not _esperar_op(")", "Faltou fechar o parentese dos parametros de " + nome + "."):
		return {}
	_parse_funcoes += 1
	var corpo = _parse_bloco("def")
	_parse_funcoes -= 1
	return {"t": "def", "nome": nome, "params": params, "corpo": corpo, "l": linha}

func _funcoes_bloqueadas(t: Dictionary) -> bool:
	if funcoes_liberadas:
		return false
	_definir_erro("Ainda nao: '" + t.v + "' sera liberado na Torre das Funcoes.", t.l, "bloqueio")
	return true

# Expressoes, da menor para a maior precedencia (como no Python).

func _parse_expr():
	return _parse_ou()

func _parse_ou():
	var a = _parse_e()
	while _erro == "" and _eh("NOME", "or"):
		var l = _avancar().l
		a = {"t": "ou", "a": a, "b": _parse_e(), "l": l}
	return a

func _parse_e():
	var a = _parse_nao()
	while _erro == "" and _eh("NOME", "and"):
		var l = _avancar().l
		a = {"t": "e", "a": a, "b": _parse_nao(), "l": l}
	return a

func _parse_nao():
	if _eh("NOME", "not"):
		var l = _avancar().l
		return {"t": "nao", "a": _parse_nao(), "l": l}
	return _parse_comparacao()

func _parse_comparacao():
	var primeiro = _parse_soma()
	var itens: Array = []
	var linha = _ver().l
	while _erro == "":
		var op = ""
		if _ver().t == "OP" and _ver().v in ["==", "!=", "<", ">", "<=", ">="]:
			op = _avancar().v
		elif _eh("NOME", "in"):
			_avancar()
			op = "in"
		elif _eh("NOME", "not") and _eh("NOME", "in", 1):
			_avancar()
			_avancar()
			op = "not in"
		else:
			break
		itens.append({"op": op, "b": _parse_soma()})
	if itens.is_empty():
		return primeiro
	return {"t": "cmp", "a": primeiro, "itens": itens, "l": linha}

func _parse_soma():
	var a = _parse_termo()
	while _erro == "" and _ver().t == "OP" and _ver().v in ["+", "-"]:
		var t = _avancar()
		a = {"t": "bin", "op": t.v, "a": a, "b": _parse_termo(), "l": t.l}
	return a

func _parse_termo():
	var a = _parse_unario()
	while _erro == "" and _ver().t == "OP" and _ver().v in ["*", "/", "//", "%"]:
		var t = _avancar()
		a = {"t": "bin", "op": t.v, "a": a, "b": _parse_unario(), "l": t.l}
	return a

func _parse_unario():
	if _ver().t == "OP" and _ver().v in ["-", "+"]:
		var t = _avancar()
		var a = _parse_unario()
		return a if t.v == "+" else {"t": "neg", "a": a, "l": t.l}
	return _parse_posfixo()

func _parse_posfixo():
	var a = _parse_atomo()
	while _erro == "":
		if _eh("OP", "("):
			if typeof(a) != TYPE_DICTIONARY or a.get("t") != "nome":
				_definir_erro("So da para chamar funcoes pelo nome. Ex.: mover('direita')", _ver().l, "sintaxe")
				return null
			var l = _avancar().l
			var args: Array = []
			if not _eh("OP", ")"):
				while _erro == "":
					args.append(_parse_expr())
					if _eh("OP", ","):
						_avancar()
						continue
					break
			if not _esperar_op(")", "Faltou fechar o parentese de " + a.nome + "(...)."):
				return null
			a = {"t": "chamada", "nome": a.nome, "args": args, "l": l}
		elif _eh("OP", "["):
			var l2 = _avancar().l
			var indice = _parse_expr()
			if not _esperar_op("]", "Faltou fechar o colchete ]."):
				return null
			a = {"t": "indice", "alvo": a, "i": indice, "l": l2}
		else:
			break
	return a

func _parse_atomo():
	var t = _ver()
	match t.t:
		"NUM", "STR":
			_avancar()
			return {"t": "valor", "v": t.v, "l": t.l}
		"NOME":
			if t.v == "True" or t.v == "False" or t.v == "None":
				_avancar()
				var constante = null
				if t.v == "True":
					constante = true
				elif t.v == "False":
					constante = false
				return {"t": "valor", "v": constante, "l": t.l}
			if t.v in PALAVRAS_RESERVADAS:
				_definir_erro("'" + t.v + "' esta fora de lugar nesta linha.", t.l, "sintaxe")
				return null
			_avancar()
			return {"t": "nome", "nome": t.v, "l": t.l}
		"OP":
			if t.v == "(":
				_avancar()
				var dentro = _parse_expr()
				_esperar_op(")", "Faltou fechar o parentese.")
				return dentro
			if t.v == "[":
				_avancar()
				var itens: Array = []
				if not _eh("OP", "]"):
					while _erro == "":
						itens.append(_parse_expr())
						if _eh("OP", ","):
							_avancar()
							if _eh("OP", "]"):
								break
							continue
						break
				_esperar_op("]", "Faltou fechar a lista com ].")
				return {"t": "lista", "itens": itens, "l": t.l}
	if t.t == "NL" or t.t == "FIM":
		_definir_erro("A linha terminou antes da hora: falta um valor ou uma condicao.", t.l, "sintaxe")
	else:
		_definir_erro("Nao esperava '" + str(t.v) + "' aqui.", t.l, "sintaxe")
	return null

# ─── Execucao (corrotinas) ──────────────────────────────────────────

func _exec_bloco(instrucoes: Array) -> void:
	for s in instrucoes:
		await _exec_stmt(s)
		if _sinal != "":
			return

func _exec_stmt(s: Dictionary) -> void:
	_passos += 1
	if _passos > MAX_PASSOS:
		_parar_laco_infinito()
		return
	if _cancelar:
		_sinal = "parar"
		_escrever("[grimorio] Execucao interrompida.")
		return
	emit_signal("linha_executando", s.l)
	match s.t:
		"pass":
			return
		"break", "continue":
			_sinal = s.t
		"atrib":
			var v = await _valor(s.expr)
			if _sinal != "":
				return
			_guardar_variavel(s.nome, v)
			if _ecoar():
				_escrever(s.nome + " = " + _repr(v))
		"atrib_op":
			if not tem_variavel(s.nome):
				_falhar("'" + s.nome + "' nao foi definida. Crie antes: " + s.nome + " = 0", s.l)
				return
			if not _locais.is_empty() and not _locais.back().has(s.nome):
				_falhar("'" + s.nome + "' e de fora da funcao. Dentro dela, " + s.nome + " " + s.op + "= nao muda a variavel de fora: receba o valor como parametro e devolva o novo com return.", s.l)
				return
			var delta = await _valor(s.expr)
			if _sinal != "":
				return
			var novo = _binario(s.op, ler_variavel(s.nome), delta, s.l)
			if _erro != "":
				_falhar_atual()
				return
			_guardar_variavel(s.nome, novo)
			if _ecoar():
				_escrever(s.nome + " = " + _repr(novo))
		"expr":
			var e = s.expr
			if typeof(e) == TYPE_DICTIONARY and e.get("t") == "chamada" and e.nome in COMANDOS:
				await _exec_comando(e)
				return
			var valor = await _valor(e)
			if _sinal != "":
				return
			if _ecoar() and valor != null:
				_escrever(_repr(valor))
		"def":
			funcoes[s.nome] = {"params": s.params, "corpo": s.corpo}
			variaveis.erase(s.nome)
			if _ecoar():
				_escrever("Funcao " + _assinatura(s.nome, s.params) + " criada.")
		"return":
			var devolvido = null
			if s.expr != null:
				devolvido = await _valor(s.expr)
				if _sinal != "":
					return
			_retorno = devolvido
			_sinal = "return"
		"if":
			await _exec_if(s)
		"while":
			await _exec_while(s)
		"for":
			await _exec_for(s)

func _exec_if(s: Dictionary) -> void:
	var cadeia = s.clausulas.size() > 1 or s.senao != null
	var corpo = null
	for c in s.clausulas:
		var cond = await _valor(c.cond)
		if _sinal != "":
			return
		if _verdadeiro(cond):
			corpo = c.corpo
			break
	if corpo == null and s.senao != null:
		corpo = s.senao
	if corpo == null:
		if _ecoar():
			_escrever("Condição falsa — nenhuma ação executada.")
		return
	if cadeia:
		_profundidade_cadeia += 1
	await _exec_bloco(corpo)
	if cadeia:
		_profundidade_cadeia -= 1

func _exec_while(s: Dictionary) -> void:
	_profundidade_laco += 1
	_profundidade_while += 1
	while true:
		var cond = await _valor(s.cond)
		if _sinal != "":
			break
		if not _verdadeiro(cond):
			break
		await _exec_bloco(s.corpo)
		if _sinal == "break":
			_sinal = ""
			break
		if _sinal == "continue":
			_sinal = ""
		if _sinal != "":
			break
		_passos += 1
		if _passos > MAX_PASSOS:
			_parar_laco_infinito()
			break
	_profundidade_laco -= 1
	_profundidade_while -= 1

func _exec_for(s: Dictionary) -> void:
	var colecao = await _valor(s.iter)
	if _sinal != "":
		return
	var itens: Array = []
	if typeof(colecao) == TYPE_ARRAY:
		itens = colecao.duplicate()
	elif typeof(colecao) == TYPE_STRING:
		for i in range(colecao.length()):
			itens.append(colecao[i])
	else:
		_falhar("O for percorre uma lista, um texto ou range(...). Ex.: for i in range(3):", s.l)
		return
	_profundidade_laco += 1
	for item in itens:
		_guardar_variavel(s.var, item)
		await _exec_bloco(s.corpo)
		if _sinal == "break":
			_sinal = ""
			break
		if _sinal == "continue":
			_sinal = ""
		if _sinal != "":
			break
	_profundidade_laco -= 1

func _exec_comando(e: Dictionary) -> void:
	var nome: String = e.nome
	var args: Array = e.args
	match nome:
		"print":
			var partes: Array = []
			for a in args:
				var v = await _valor(a)
				if _sinal != "":
					return
				partes.append(_texto(v))
			_escrever(" ".join(partes))
		"mover", "atacar":
			if args.size() != 1:
				_falhar(nome + "() recebe uma direcao. Ex.: " + nome + "('direita')", e.l)
				return
			var arg = args[0]
			if typeof(arg) == TYPE_DICTIONARY and arg.get("t") == "nome" and not tem_variavel(arg.nome):
				_falhar("'" + arg.nome + "' nao e uma string nem uma variavel definida.\nDica: use aspas — " + nome + "('" + arg.nome + "')", e.l)
				return
			var direcao = await _valor(arg)
			if _sinal != "":
				return
			await _acao(nome, [_texto(direcao)], e.l)
		"fireball":
			if args.size() != 2 or typeof(args[0]) != TYPE_DICTIONARY or args[0].get("t") != "nome":
				_falhar("fireball recebe o NOME de uma variavel e a direcao. Ex.: poder = 3 e depois fireball(poder, 'direita')", e.l)
				return
			var dir_no = args[1]
			var direcao_fb = ""
			if typeof(dir_no) == TYPE_DICTIONARY and dir_no.get("t") == "nome" and not tem_variavel(dir_no.nome):
				direcao_fb = dir_no.nome
			else:
				direcao_fb = _texto(await _valor(dir_no))
				if _sinal != "":
					return
			await _acao("fireball", [args[0].nome, direcao_fb], e.l)
		"escolher":
			if args.size() != 1:
				_falhar("Use escolher(1), escolher(2) ou escolher(3).", e.l)
				return
			var n = await _valor(args[0])
			if _sinal != "":
				return
			if typeof(n) != TYPE_INT:
				_falhar("escolher() recebe um numero. Ex.: escolher(1)", e.l)
				return
			await _acao("escolher", [n], e.l)

func _acao(nome: String, args: Array, linha: int) -> void:
	var com_turno = nome in ACOES_COM_TURNO
	if com_turno:
		if _acoes >= MAX_ACOES:
			_parar_laco_infinito()
			return
		if _acoes > 0 and atraso_entre_acoes > 0.0 and is_inside_tree():
			await get_tree().create_timer(atraso_entre_acoes).timeout
		if _cancelar:
			_sinal = "parar"
			_escrever("[grimorio] Execucao interrompida.")
			return
	emit_signal("linha_executando", linha)
	ultimo_encadeado = _profundidade_cadeia > 0
	var pendente_antes = player != null and not player.pending_escolha.is_empty()
	var resposta = "Erro: player nao encontrado"
	if player:
		resposta = player.executar_acao(nome, args)
	if com_turno:
		_acoes += 1
	_saidas.append(resposta)
	var continuar = true
	if ao_agir.is_valid():
		continuar = ao_agir.call(resposta, pendente_antes)
	if com_turno and _profundidade_laco > 0:
		_falhas_seguidas = _falhas_seguidas + 1 if _acao_falhou(resposta) else 0
		if _falhas_seguidas >= MAX_FALHAS_SEGUIDAS:
			_sinal = "parar"
			_escrever("[grimorio] Laco interrompido: a mesma acao falhou " + str(MAX_FALHAS_SEGUIDAS) + " vezes seguidas (ex.: andar contra a parede). Use caminho_livre() ou inimigo_a_frente() na condicao do laco.")
			return
	if not continuar and _sinal == "":
		_sinal = "parar"

func _acao_falhou(resposta: String) -> bool:
	var r = resposta.to_lower()
	for marcador in ["bloqueado", "ha uma parede", "nenhum inimigo", "mana insuficiente", "direcao invalida", "subiu de nivel"]:
		if marcador in r:
			return true
	return false

func _parar_laco_infinito():
	if _sinal == "parar":
		return
	_sinal = "parar"
	_escrever("[grimorio] Laco infinito? O programa passou do limite de " + str(MAX_ACOES) + " acoes e foi interrompido. Revise a condicao de parada. Se a sala travou, use reiniciar_sala().")

# ─── Funcoes do jogador e escopo ────────────────────────────────────

# Valor de uma expressao durante a execucao. Se algo interromper (erro, Esc, limite
# de acoes), devolve null com _sinal marcado: quem chamou so precisa olhar _sinal.
func _valor(no):
	var resolvido = await _resolver(no)
	if _sinal != "":
		return null
	var v = _avaliar(resolvido)
	if _erro != "":
		_falhar_atual()
		return null
	return v

# Funcoes do jogador podem fazer acoes (cada uma e um turno), entao rodam aqui, de
# forma assincrona, antes do _avaliar (sincrono). Cada chamada vira o valor que
# devolveu. and/or seguem em curto-circuito: o lado direito so roda se precisar.
func _resolver(no):
	if funcoes.is_empty() or not _tem_chamada_do_jogador(no):
		return no
	var r: Dictionary = no.duplicate()
	match no.t:
		"chamada":
			r.args = await _resolver_lista(no.args)
			if _interrompido():
				return null
			if funcoes.has(no.nome):
				var valores: Array = []
				for a in r.args:
					valores.append(_avaliar(a))
				if _erro != "":
					return null
				return {"t": "valor", "v": await _chamar_do_jogador(no.nome, valores, no.l), "l": no.l}
		"ou", "e":
			var a = await _resolver(no.a)
			if _interrompido():
				return null
			var va = _avaliar(a)
			if _erro != "":
				return null
			if _verdadeiro(va) == (no.t == "ou"):
				return {"t": "valor", "v": va, "l": no.l}
			return await _resolver(no.b)
		"cmp":
			r.a = await _resolver(no.a)
			var itens: Array = []
			for item in no.itens:
				if _interrompido():
					return null
				itens.append({"op": item.op, "b": await _resolver(item.b)})
			r.itens = itens
		"lista":
			r.itens = await _resolver_lista(no.itens)
		_:
			for chave in ["a", "b", "alvo", "i"]:
				if no.has(chave) and not _interrompido():
					r[chave] = await _resolver(no[chave])
	return null if _interrompido() else r

func _resolver_lista(nos: Array) -> Array:
	var resolvidos: Array = []
	for n in nos:
		resolvidos.append(await _resolver(n))
		if _interrompido():
			break
	return resolvidos

func _tem_chamada_do_jogador(no) -> bool:
	if typeof(no) != TYPE_DICTIONARY:
		return false
	if no.get("t") == "chamada" and funcoes.has(no.nome):
		return true
	for chave in ["a", "b", "alvo", "i"]:
		if _tem_chamada_do_jogador(no.get(chave)):
			return true
	for chave in ["args", "itens"]:
		for filho in no.get(chave, []):
			if _tem_chamada_do_jogador(filho):
				return true
	return false

func _interrompido() -> bool:
	return _sinal != "" or _erro != ""

func _chamar_do_jogador(nome: String, valores: Array, linha: int):
	var f = funcoes[nome]
	if valores.size() != f.params.size():
		_falhar(_assinatura(nome, f.params) + " espera " + _quantos_valores(f.params.size()) + ", mas recebeu " + _quantos_valores(valores.size()) + ".", linha)
		return null
	if _locais.size() >= MAX_CHAMADAS_ANINHADAS:
		_falhar("Chamadas de funcao demais ao mesmo tempo (limite " + str(MAX_CHAMADAS_ANINHADAS) + "). Uma funcao que chama a si mesma precisa de um caso que termine sem se chamar de novo.", linha)
		return null
	var escopo: Dictionary = {}
	for i in range(valores.size()):
		escopo[f.params[i]] = valores[i]
	_locais.append(escopo)
	await _exec_bloco(f.corpo)
	_locais.pop_back()
	if _sinal != "return":
		return null
	_sinal = ""
	var devolvido = _retorno
	_retorno = null
	return devolvido

# Escopo como no Python: dentro de uma funcao valem primeiro as variaveis locais
# (parametros e o que ela criou), depois as de fora. O player usa estas duas para
# achar a variavel do fireball.
func tem_variavel(nome: String) -> bool:
	return (not _locais.is_empty() and _locais.back().has(nome)) or variaveis.has(nome)

func ler_variavel(nome: String):
	if not _locais.is_empty() and _locais.back().has(nome):
		return _locais.back()[nome]
	return variaveis.get(nome)

func _guardar_variavel(nome: String, valor):
	if _locais.is_empty():
		variaveis[nome] = valor
		funcoes.erase(nome)
	else:
		_locais.back()[nome] = valor

# Como no console do Python: so ecoa resultados de comandos de uma linha, e nunca
# o que acontece dentro de uma funcao.
func _ecoar() -> bool:
	return not _multilinha and _locais.is_empty()

func _assinatura(nome: String, params: Array) -> String:
	return nome + "(" + ", ".join(params) + ")"

func _quantos_valores(n: int) -> String:
	if n == 0:
		return "nenhum valor"
	return str(n) + (" valor" if n == 1 else " valores")

# ─── Avaliacao de expressoes (sincrona) ─────────────────────────────

func _avaliar(no):
	if _erro != "" or typeof(no) != TYPE_DICTIONARY:
		return null
	match no.t:
		"valor":
			return no.v
		"nome":
			if tem_variavel(no.nome):
				return ler_variavel(no.nome)
			if funcoes.has(no.nome):
				_definir_erro("'" + no.nome + "' e uma funcao. Para usa-la, chame com parenteses: " + no.nome + "(...)", no.l, "execucao")
				return null
			_definir_erro("'" + no.nome + "' nao foi definida. Crie antes: " + no.nome + " = valor", no.l, "execucao")
			return null
		"lista":
			var lista: Array = []
			for item in no.itens:
				lista.append(_avaliar(item))
			return lista
		"neg":
			var v = _avaliar(no.a)
			if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
				return -v
			_definir_erro("O sinal - so funciona com numeros.", no.l, "execucao")
			return null
		"ou":
			var a = _avaliar(no.a)
			return a if _verdadeiro(a) else _avaliar(no.b)
		"e":
			var a2 = _avaliar(no.a)
			return _avaliar(no.b) if _verdadeiro(a2) else a2
		"nao":
			return not _verdadeiro(_avaliar(no.a))
		"bin":
			return _binario(no.op, _avaliar(no.a), _avaliar(no.b), no.l)
		"cmp":
			var esquerda = _avaliar(no.a)
			for item in no.itens:
				var direita = _avaliar(item.b)
				if _erro != "":
					return null
				if not _comparar(item.op, esquerda, direita, no.l):
					return false
				esquerda = direita
			return _erro == ""
		"indice":
			var alvo = _avaliar(no.alvo)
			var i = _avaliar(no.i)
			if _erro != "":
				return null
			if typeof(alvo) not in [TYPE_ARRAY, TYPE_STRING] or typeof(i) != TYPE_INT:
				_definir_erro("Use [numero] em listas ou textos. Ex.: passos[0]", no.l, "execucao")
				return null
			var tamanho = alvo.size() if typeof(alvo) == TYPE_ARRAY else alvo.length()
			var idx = i + tamanho if i < 0 else i
			if idx < 0 or idx >= tamanho:
				_definir_erro("Posicao " + str(i) + " fora da lista (ela tem " + str(tamanho) + " itens; a primeira posicao e 0).", no.l, "execucao")
				return null
			return alvo[idx]
		"chamada":
			return _chamar_funcao(no)
	return null

func _binario(op: String, a, b, linha: int):
	if _erro != "":
		return null
	var numeros = typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]
	match op:
		"+":
			if numeros:
				return a + b
			if typeof(a) == TYPE_STRING and typeof(b) == TYPE_STRING:
				return a + b
			if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
				return a + b
			_definir_erro("Nao da para somar " + _tipo(a) + " com " + _tipo(b) + ". Para juntar texto e numero use str(numero).", linha, "execucao")
			return null
		"-":
			if numeros:
				return a - b
		"*":
			if numeros:
				return a * b
			if typeof(a) == TYPE_STRING and typeof(b) == TYPE_INT:
				return a.repeat(max(b, 0))
		"/":
			if numeros:
				if b == 0:
					_definir_erro("Divisao por zero.", linha, "execucao")
					return null
				return float(a) / float(b)
		"//":
			if numeros:
				if b == 0:
					_definir_erro("Divisao por zero.", linha, "execucao")
					return null
				var q = floor(float(a) / float(b))
				return int(q) if typeof(a) == TYPE_INT and typeof(b) == TYPE_INT else q
		"%":
			if numeros:
				if b == 0:
					_definir_erro("Divisao por zero.", linha, "execucao")
					return null
				if typeof(a) == TYPE_INT and typeof(b) == TYPE_INT:
					return posmod(a, b)
				return fposmod(a, b)
	_definir_erro("A operacao " + op + " nao funciona com " + _tipo(a) + " e " + _tipo(b) + ".", linha, "execucao")
	return null

func _comparar(op: String, a, b, linha: int) -> bool:
	match op:
		"==":
			return _iguais(a, b)
		"!=":
			return not _iguais(a, b)
		"in", "not in":
			var dentro = false
			if typeof(b) == TYPE_ARRAY:
				for item in b:
					if _iguais(item, a):
						dentro = true
						break
			elif typeof(b) == TYPE_STRING and typeof(a) == TYPE_STRING:
				dentro = b.contains(a)
			else:
				_definir_erro("'in' procura um item dentro de uma lista ou texto.", linha, "execucao")
				return false
			return dentro if op == "in" else not dentro
	var numeros = typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]
	var textos = typeof(a) == TYPE_STRING and typeof(b) == TYPE_STRING
	if not (numeros or textos):
		_definir_erro("Nao da para comparar " + _tipo(a) + " com " + _tipo(b) + " usando " + op + ".", linha, "execucao")
		return false
	match op:
		"<":
			return a < b
		">":
			return a > b
		"<=":
			return a <= b
		">=":
			return a >= b
	return false

func _iguais(a, b) -> bool:
	var na = typeof(a) in [TYPE_INT, TYPE_FLOAT]
	var nb = typeof(b) in [TYPE_INT, TYPE_FLOAT]
	if na and nb:
		return float(a) == float(b)
	if typeof(a) != typeof(b):
		return false
	return a == b

func _chamar_funcao(no: Dictionary):
	var nome: String = no.nome
	if nome in COMANDOS:
		_definir_erro(nome + "(...) e uma acao: escreva-a sozinha na linha, sem usar o resultado.", no.l, "execucao")
		return null
	if funcoes.has(nome):
		# Na execucao, _resolver ja trocou estas chamadas pelo valor devolvido.
		_definir_erro("A funcao " + nome + "() nao pode ser usada aqui.", no.l, "execucao")
		return null
	match nome:
		"atacar_com":
			_definir_erro_cru("atacar_com foi substituido por fireball.\nUse: fireball(poder, 'direcao')", no.l)
			return null
		"abrir_bau", "abrir_porta", "abrir_comporta":
			_definir_erro(nome + "() so funciona dentro do desafio: fique ao lado do objeto e digite desafio(...).", no.l, "execucao")
			return null
		"reiniciar", "reiniciar_sala":
			_definir_erro("Digite " + nome + "() sozinho no terminal, fora de programas.", no.l, "execucao")
			return null
	var args: Array = []
	for a in no.args:
		args.append(_avaliar(a))
	if _erro != "":
		return null
	match nome:
		"range":
			return _range(args, no.l)
		"len":
			if args.size() == 1 and typeof(args[0]) == TYPE_ARRAY:
				return args[0].size()
			if args.size() == 1 and typeof(args[0]) == TYPE_STRING:
				return args[0].length()
			_definir_erro("len() mede uma lista ou um texto. Ex.: len(passos)", no.l, "execucao")
			return null
		"str":
			return _texto(args[0]) if args.size() == 1 else ""
		"int":
			if args.size() == 1:
				if typeof(args[0]) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
					return int(args[0])
				if typeof(args[0]) == TYPE_STRING and args[0].strip_edges().is_valid_int():
					return args[0].strip_edges().to_int()
			_definir_erro("int() precisa de um numero ou de um texto com numero.", no.l, "execucao")
			return null
		"abs":
			if args.size() == 1 and typeof(args[0]) in [TYPE_INT, TYPE_FLOAT]:
				return abs(args[0])
		"min", "max":
			var valores = args[0] if args.size() == 1 and typeof(args[0]) == TYPE_ARRAY else args
			if valores.size() > 0:
				var melhor = valores[0]
				for v in valores:
					if _erro == "" and _comparar("<" if nome == "min" else ">", v, melhor, no.l):
						melhor = v
				return melhor
		"caminho_livre", "inimigo_a_frente":
			var vetor = _direcao_do_sensor(nome, args, no.l)
			if _erro != "" or player == null:
				return false
			var alvo: Vector2i = player.grid_pos + vetor
			var gi = player.gerenciador_inimigos
			var tem_inimigo = gi != null and gi.tem_inimigo(alvo)
			if nome == "inimigo_a_frente":
				return tem_inimigo
			var mapa = player.mapa
			return mapa != null and mapa.posicao_valida(alvo) and not tem_inimigo
		"inimigos_restantes":
			if player and player.gerenciador_inimigos:
				return player.gerenciador_inimigos.quantidade_inimigos_vivos()
			return 0
		"minha_vida":
			return player.hp if player else 0
		"minha_mana":
			return player.mana if player else 0
		_:
			var suas = ""
			if not funcoes.is_empty():
				var assinaturas: Array = []
				for f in funcoes:
					assinaturas.append(_assinatura(f, funcoes[f].params))
				suas = "\nSuas funcoes: " + ", ".join(assinaturas)
			_definir_erro_cru("Comando nao reconhecido. Tente: mover('direita'), atacar('direita') ou fireball(poder, 'direita')" + suas, no.l)
			return null
	_definir_erro(nome + "() recebeu valores que ele nao entende.", no.l, "execucao")
	return null

func _direcao_do_sensor(nome: String, args: Array, linha: int) -> Vector2i:
	if args.size() != 1 or typeof(args[0]) != TYPE_STRING or not DIRECOES.has(args[0]):
		_definir_erro("Direcao invalida em " + nome + "(). Use: direita, esquerda, cima ou baixo.", linha, "execucao")
		return Vector2i.ZERO
	return DIRECOES[args[0]]

func _range(args: Array, linha: int):
	for a in args:
		if typeof(a) != TYPE_INT:
			_definir_erro("range() usa numeros inteiros. Ex.: range(3)", linha, "execucao")
			return null
	var inicio = 0
	var fim = 0
	var passo = 1
	match args.size():
		1:
			fim = args[0]
		2:
			inicio = args[0]
			fim = args[1]
		3:
			inicio = args[0]
			fim = args[1]
			passo = args[2]
		_:
			_definir_erro("range() recebe de 1 a 3 numeros. Ex.: range(3)", linha, "execucao")
			return null
	if passo == 0:
		_definir_erro("O passo do range() nao pode ser 0.", linha, "execucao")
		return null
	var lista: Array = []
	var i = inicio
	while (passo > 0 and i < fim) or (passo < 0 and i > fim):
		lista.append(i)
		if lista.size() > MAX_RANGE:
			_definir_erro("range() muito grande! Use no maximo " + str(MAX_RANGE) + " repeticoes.", linha, "execucao")
			return null
		i += passo
	return lista

# ─── Valores ────────────────────────────────────────────────────────

func _verdadeiro(v) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
		TYPE_STRING:
			return v != ""
		TYPE_ARRAY:
			return not v.is_empty()
	return true

func _texto(v) -> String:
	if typeof(v) == TYPE_STRING:
		return v
	return _repr(v)

func _repr(v) -> String:
	match typeof(v):
		TYPE_NIL:
			return "None"
		TYPE_BOOL:
			return "True" if v else "False"
		TYPE_STRING:
			return "'" + v + "'"
		TYPE_ARRAY:
			var partes: Array = []
			for item in v:
				partes.append(_repr(item))
			return "[" + ", ".join(partes) + "]"
	return str(v)

func _tipo(v) -> String:
	match typeof(v):
		TYPE_STRING:
			return "texto"
		TYPE_INT, TYPE_FLOAT:
			return "numero"
		TYPE_ARRAY:
			return "lista"
		TYPE_BOOL:
			return "True/False"
		TYPE_NIL:
			return "None"
	return "valor"

# ─── Erros e saida ──────────────────────────────────────────────────

func _definir_erro(mensagem: String, linha: int, tipo: String):
	if _erro != "":
		return
	_erro = mensagem
	_erro_linha = linha
	_erro_tipo = tipo
	_erro_cru = false

func _definir_erro_cru(mensagem: String, linha: int):
	if _erro != "":
		return
	_erro = mensagem
	_erro_linha = linha
	_erro_tipo = "execucao"
	_erro_cru = true

func _falhar(mensagem: String, linha: int):
	_definir_erro(mensagem, linha, "execucao")
	_falhar_atual()

func _falhar_atual():
	if _sinal == "erro":
		return
	_sinal = "erro"
	_escrever(_mensagem_erro())

func _mensagem_erro() -> String:
	if _erro_cru:
		return _erro
	if _erro_tipo == "bloqueio":
		return _erro + (" (linha " + str(_erro_linha) + ")" if _multilinha else "")
	var prefixo = "Erro de sintaxe" if _erro_tipo == "sintaxe" else "Erro"
	if _multilinha:
		return prefixo + " na linha " + str(_erro_linha) + ": " + _erro
	return prefixo + ": " + _erro

func _escrever(texto: String):
	_saidas.append(texto)
	if ao_escrever.is_valid():
		ao_escrever.call(texto)

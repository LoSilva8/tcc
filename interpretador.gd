extends Node

var variaveis: Dictionary = {}
var player: Node = null
var ultimo_encadeado: bool = false

func executar(linha: String) -> String:
	linha = linha.strip_edges()
	if linha == "":
		return ""

	ultimo_encadeado = false

	if linha.begins_with("for "):
		return _processar_for(linha)

	if linha.begins_with("if "):
		return _processar_if(linha)

	if _eh_atribuicao(linha):
		return _processar_atribuicao(linha)

	return _executar_comando(linha)

# ─── IF/ELIF/ELSE ────────────────────────────────────────

func _processar_if(linha: String) -> String:
	var comando = escolher_ramo_condicional(linha)

	if comando == null:
		return "Erro de sintaxe! Use: if condicao: comando (opcionalmente elif condicao: comando, e else: comando)"

	if comando == "":
		return "Condição falsa — nenhuma ação executada."

	# Um ramo pode conter uma atribuicao (ex.: if x > 2: poder = 3)
	if _eh_atribuicao(comando):
		return _processar_atribuicao(comando)

	return _executar_comando(comando)

# Analisa uma cadeia if/elif/else em UMA linha e devolve o comando do ramo
# escolhido, sem executa-lo. Retorna null em erro de sintaxe, ou "" se
# nenhuma condicao bateu (e nao havia else). Tambem atualiza
# ultimo_encadeado: true quando a linha usou elif e/ou else.
func escolher_ramo_condicional(linha: String):
	if not linha.begins_with("if "):
		return null

	var clausulas = _dividir_clausulas(linha)
	if clausulas == null or clausulas.is_empty() or clausulas[0]["tipo"] != "if":
		return null

	ultimo_encadeado = clausulas.size() > 1

	for c in clausulas:
		if c["tipo"] == "else":
			return c["comando"]
		if _avaliar_condicao(c["condicao"]):
			return c["comando"]

	return ""

func _dividir_clausulas(linha: String):
	var restante = linha
	var clausulas: Array = []

	while true:
		if restante.begins_with("if ") or restante.begins_with("elif "):
			var tipo = "if" if restante.begins_with("if ") else "elif"
			var corpo = restante.substr(3 if tipo == "if" else 5)
			var pos_dp = corpo.find(":")
			if pos_dp == -1:
				return null

			var condicao = corpo.substr(0, pos_dp).strip_edges()
			var resto = corpo.substr(pos_dp + 1).strip_edges()
			var prox = _achar_proxima_clausula(resto)
			var comando = ""

			if prox == -1:
				comando = resto.strip_edges()
				restante = ""
			else:
				comando = resto.substr(0, prox).strip_edges()
				restante = resto.substr(prox).strip_edges()

			if comando == "" or condicao == "":
				return null

			clausulas.append({"tipo": tipo, "condicao": condicao, "comando": comando})
			if restante == "":
				break
		elif restante.begins_with("else:"):
			var comando_else = restante.substr(5).strip_edges()
			if comando_else == "":
				return null
			clausulas.append({"tipo": "else", "condicao": "", "comando": comando_else})
			break
		else:
			return null

	return clausulas

func _achar_proxima_clausula(texto: String) -> int:
	var idx_elif = texto.find(" elif ")
	var idx_else = texto.find(" else:")
	if idx_elif == -1 and idx_else == -1:
		return -1
	if idx_elif == -1:
		return idx_else + 1
	if idx_else == -1:
		return idx_elif + 1
	return min(idx_elif, idx_else) + 1

func _avaliar_condicao(condicao: String) -> bool:
	condicao = condicao.strip_edges()

	# Operadores logicos (or tem precedencia mais baixa que and, como em Python)
	if " or " in condicao:
		for parte in condicao.split(" or ", false):
			if _avaliar_condicao(parte):
				return true
		return false

	if " and " in condicao:
		for parte in condicao.split(" and ", false):
			if not _avaliar_condicao(parte):
				return false
		return true

	condicao = _resolver_variaveis(condicao).strip_edges()

	# Suporte a operadores de comparação
	var operadores = ["==", "!=", ">=", "<=", ">", "<"]
	for op in operadores:
		if op in condicao:
			var partes = condicao.split(op, false, 1)
			if partes.size() == 2:
				var esq = _limpar_valor(partes[0].strip_edges())
				var dir = _limpar_valor(partes[1].strip_edges())
				return _comparar(esq, dir, op)

	# Suporte a "not x"
	if condicao.begins_with("not "):
		var valor = _limpar_valor(condicao.substr(4).strip_edges())
		return not _eh_verdadeiro(valor)

	# Valor direto (truthy/falsy)
	return _eh_verdadeiro(_limpar_valor(condicao))

func _comparar(esq, dir, op: String) -> bool:
	match op:
		"==": return esq == dir
		"!=": return esq != dir
		">":  return float(str(esq)) > float(str(dir))
		"<":  return float(str(esq)) < float(str(dir))
		">=": return float(str(esq)) >= float(str(dir))
		"<=": return float(str(esq)) <= float(str(dir))
	return false

func _eh_verdadeiro(valor) -> bool:
	if typeof(valor) == TYPE_BOOL:
		return valor
	if typeof(valor) == TYPE_INT or typeof(valor) == TYPE_FLOAT:
		return valor != 0
	if typeof(valor) == TYPE_STRING:
		return valor != "" and valor != "False" and valor != "None"
	return false

func _limpar_valor(valor: String):
	# Remove aspas de strings
	if (valor.begins_with("'") and valor.ends_with("'")) or \
	   (valor.begins_with('"') and valor.ends_with('"')):
		return valor.substr(1, valor.length() - 2)
	# Converte número
	if valor.is_valid_int():
		return valor.to_int()
	if valor.is_valid_float():
		return valor.to_float()
	# Booleanos Python
	if valor == "True": return true
	if valor == "False": return false
	return valor

# ─── FOR ────────────────────────────────────────────────

func _processar_for(linha: String) -> String:
	var regex = RegEx.new()
	regex.compile("for\\s+(\\w+)\\s+in\\s+range\\((.+)\\):\\s*(.+)")
	var resultado = regex.search(linha)

	if not resultado:
		return "Erro de sintaxe! Use: for i in range(3): mover('direita')"

	var variavel_loop = resultado.get_string(1)
	var arg_range = resultado.get_string(2).strip_edges()
	var comando = resultado.get_string(3).strip_edges()

	var repeticoes = _resolver_numero(arg_range)
	if repeticoes < 0:
		return "Erro: '" + arg_range + "' não é um número válido para range()"
	if repeticoes > 20:
		return "Erro: range() muito grande! Use no máximo 20."

	var saidas: Array = []
	for i in range(repeticoes):
		variaveis[variavel_loop] = i
		var resposta = _executar_comando(comando)
		saidas.append("  [" + str(i) + "] " + resposta)

	variaveis.erase(variavel_loop)
	return "\n".join(saidas)

func _resolver_numero(valor: String) -> int:
	if valor.is_valid_int():
		return valor.to_int()
	if valor in variaveis:
		var v = variaveis[valor]
		if typeof(v) == TYPE_INT: return v
		if typeof(v) == TYPE_FLOAT: return int(v)
	return -1

# ─── ATRIBUIÇÃO ─────────────────────────────────────────

func _eh_atribuicao(linha: String) -> bool:
	if not "=" in linha:
		return false
	if "==" in linha:
		return false
	var partes = linha.split("=", false, 1)
	if partes.size() < 2:
		return false
	var lado_esquerdo = partes[0].strip_edges()
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z_][a-zA-Z0-9_]*$")
	return regex.search(lado_esquerdo) != null

func _processar_atribuicao(linha: String) -> String:
	var partes = linha.split("=", false, 1)
	var nome = partes[0].strip_edges()
	var valor_raw = partes[1].strip_edges()

	if (valor_raw.begins_with("'") and valor_raw.ends_with("'")) or \
	   (valor_raw.begins_with('"') and valor_raw.ends_with('"')):
		variaveis[nome] = valor_raw.substr(1, valor_raw.length() - 2)
		return nome + " = '" + variaveis[nome] + "'"

	if valor_raw.is_valid_int():
		variaveis[nome] = valor_raw.to_int()
		return nome + " = " + str(variaveis[nome])

	if valor_raw.is_valid_float():
		variaveis[nome] = valor_raw.to_float()
		return nome + " = " + str(variaveis[nome])

	if valor_raw in variaveis:
		variaveis[nome] = variaveis[valor_raw]
		return nome + " = " + str(variaveis[nome])

	if valor_raw == "True": variaveis[nome] = true; return nome + " = True"
	if valor_raw == "False": variaveis[nome] = false; return nome + " = False"

	return "Erro: valor inválido para '" + nome + "'"

# ─── COMANDOS ───────────────────────────────────────────

func _executar_comando(linha: String) -> String:
	# Detecta fireball ANTES de resolver variaveis para preservar o nome usado.
	var regex_fireball = RegEx.new()
	regex_fireball.compile("fireball\\((\\w+),\\s*['\"]?(\\w+)['\"]?\\)")
	var resultado = regex_fireball.search(linha)

	if resultado:
		var nome_var = resultado.get_string(1)
		var direcao = resultado.get_string(2)
		if player:
			return player._fireball_com_variavel(nome_var, direcao)

	# Para outros comandos, resolve variaveis normalmente
	var linha_resolvida = _resolver_variaveis(linha)
	return _executar_comando_resolvido(linha_resolvida)

func _executar_comando_resolvido(linha: String) -> String:
	if player:
		return player.executar_comando(linha)
	return "Erro: player não encontrado"

func _resolver_variaveis(linha: String) -> String:
	# Substitui nomes de variaveis apenas FORA de strings literais.
	# Sem isso, com fogo = 2 definido, a condicao sinal == 'fogo'
	# virava '2' == '2' e todo ramo ficava verdadeiro.
	var resultado = ""
	var trecho = ""
	var aspa = ""
	for i in range(linha.length()):
		var ch = linha[i]
		if aspa == "":
			if ch == "'" or ch == '"':
				resultado += _substituir_variaveis(trecho)
				trecho = ""
				aspa = ch
				resultado += ch
			else:
				trecho += ch
		else:
			resultado += ch
			if ch == aspa:
				aspa = ""
	resultado += _substituir_variaveis(trecho)
	return resultado

func _substituir_variaveis(trecho: String) -> String:
	# Passada unica por identificadores: cada nome e trocado no maximo uma vez,
	# entao o valor inserido de uma variavel nunca e reprocessado por outra.
	if trecho == "":
		return trecho
	var resultado = ""
	var i = 0
	while i < trecho.length():
		var ch = trecho[i]
		if _inicio_identificador(ch):
			var j = i + 1
			while j < trecho.length() and _parte_identificador(trecho[j]):
				j += 1
			var nome = trecho.substr(i, j - i)
			if variaveis.has(nome):
				resultado += _valor_como_texto(variaveis[nome])
			else:
				resultado += nome
			i = j
		elif ch >= "0" and ch <= "9":
			# Numeros (ex.: 12, 3.5) nao sao identificadores
			var k = i + 1
			while k < trecho.length() and (_parte_identificador(trecho[k]) or trecho[k] == "."):
				k += 1
			resultado += trecho.substr(i, k - i)
			i = k
		else:
			resultado += ch
			i += 1
	return resultado

func _inicio_identificador(ch: String) -> bool:
	return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch == "_"

func _parte_identificador(ch: String) -> bool:
	return _inicio_identificador(ch) or (ch >= "0" and ch <= "9")

func _valor_como_texto(valor) -> String:
	if typeof(valor) == TYPE_STRING:
		return "'" + valor + "'"
	if typeof(valor) == TYPE_BOOL:
		return "True" if valor else "False"
	return str(valor)

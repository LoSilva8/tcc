extends Node

var variaveis: Dictionary = {}
var player: Node = null

func executar(linha: String) -> String:
	linha = linha.strip_edges()
	if linha == "":
		return ""
	
	if linha.begins_with("for "):
		return _processar_for(linha)
	
	if linha.begins_with("if "):
		return _processar_if(linha)
	
	if _eh_atribuicao(linha):
		return _processar_atribuicao(linha)
	
	return _executar_comando(linha)

# ─── IF/ELIF/ELSE ────────────────────────────────────────

func _processar_if(linha: String) -> String:
	# Suporta: if condicao: comando
	var regex = RegEx.new()
	regex.compile("if\\s+(.+):\\s*(.+)")
	var resultado = regex.search(linha)
	
	if not resultado:
		return "Erro de sintaxe! Use: if condicao: comando"
	
	var condicao = resultado.get_string(1).strip_edges()
	var comando = resultado.get_string(2).strip_edges()
	
	if _avaliar_condicao(condicao):
		return _executar_comando(_resolver_variaveis(comando))
	
	return "Condição falsa — nenhuma ação executada."

func _avaliar_condicao(condicao: String) -> bool:
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
		var linha_resolvida = _resolver_variaveis(comando)
		var resposta = _executar_comando_resolvido(linha_resolvida)
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
	var linha_resolvida = _resolver_variaveis(linha)
	return _executar_comando_resolvido(linha_resolvida)

func _executar_comando_resolvido(linha: String) -> String:
	if player:
		return player.executar_comando(linha)
	return "Erro: player não encontrado"

func _resolver_variaveis(linha: String) -> String:
	var resultado = linha
	for nome in variaveis:
		var valor = variaveis[nome]
		var valor_str = ""
		if typeof(valor) == TYPE_STRING:
			valor_str = "'" + valor + "'"
		elif typeof(valor) == TYPE_BOOL:
			valor_str = "True" if valor else "False"
		else:
			valor_str = str(valor)
		var regex = RegEx.new()
		regex.compile("\\b" + nome + "\\b")
		resultado = regex.sub(resultado, valor_str, true)
	return resultado

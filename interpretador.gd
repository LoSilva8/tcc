extends Node

var variaveis: Dictionary = {}
var player: Node = null

func executar(linha: String) -> String:
	linha = linha.strip_edges()
	
	if linha == "":
		return ""
	
	# Detecta loop for
	if linha.begins_with("for "):
		return _processar_for(linha)
	
	# Detecta atribuição
	if _eh_atribuicao(linha):
		return _processar_atribuicao(linha)
	
	# Comando normal
	return _executar_comando(linha)

# ─── FOR ────────────────────────────────────────────────

func _processar_for(linha: String) -> String:
	# Espera formato: for i in range(N): comando
	var regex = RegEx.new()
	regex.compile("for\\s+(\\w+)\\s+in\\s+range\\((.+)\\):\\s*(.+)")
	var resultado = regex.search(linha)
	
	if not resultado:
		return "Erro de sintaxe! Use: for i in range(3): mover('direita')"
	
	var variavel_loop = resultado.get_string(1)  # ex: i
	var arg_range = resultado.get_string(2).strip_edges()  # ex: 3 ou n
	var comando = resultado.get_string(3).strip_edges()  # ex: mover('direita')
	
	# Resolve o argumento do range (pode ser variável ou número)
	var repeticoes = _resolver_numero(arg_range)
	if repeticoes < 0:
		return "Erro: '" + arg_range + "' não é um número válido para range()"
	if repeticoes > 20:
		return "Erro: range() muito grande! Use no máximo 20."
	
	# Executa o loop
	var saidas: Array = []
	for i in range(repeticoes):
		variaveis[variavel_loop] = i
		var linha_resolvida = _resolver_variaveis(comando)
		var resposta = _executar_comando_resolvido(linha_resolvida)
		saidas.append("  [" + str(i) + "] " + resposta)
	
	# Remove a variável de loop após terminar (escopo)
	variaveis.erase(variavel_loop)
	
	return "\n".join(saidas)

func _resolver_numero(valor: String) -> int:
	# Pode ser número direto
	if valor.is_valid_int():
		return valor.to_int()
	
	# Pode ser variável
	if valor in variaveis:
		var v = variaveis[valor]
		if typeof(v) == TYPE_INT:
			return v
		if typeof(v) == TYPE_FLOAT:
			return int(v)
	
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
		else:
			valor_str = str(valor)
		var regex = RegEx.new()
		regex.compile("\\b" + nome + "\\b")
		resultado = regex.sub(resultado, valor_str, true)
	return resultado

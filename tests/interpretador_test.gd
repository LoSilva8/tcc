extends SceneTree

var falhas = 0
var it

func _initialize():
	call_deferred("_testar")

func verificar(condicao: bool, descricao: String):
	if not condicao:
		falhas += 1
		push_error(descricao)

func rodar(codigo: String) -> String:
	return await it.executar(codigo)

func _testar():
	it = load("res://interpretador.gd").new()

	# --- Compatibilidade com mensagens antigas (tutorial / feedback IA) ---
	verificar(await rodar("poder = 3") == "poder = 3", "Atribuicao simples ecoa 'nome = valor'.")
	verificar(it.variaveis.get("poder") == 3 and typeof(it.variaveis["poder"]) == TYPE_INT, "Numero inteiro continua int.")
	verificar(await rodar("nome = 'fogo'") == "nome = 'fogo'", "Texto ecoa entre aspas.")
	verificar(await rodar("mover(direita)") == "Erro: 'direita' nao e uma string nem uma variavel definida.\nDica: use aspas — mover('direita')", "Mensagem pedagogica de aspas preservada.")
	verificar((await rodar("pular('x')")).begins_with("Comando nao reconhecido."), "Comando desconhecido preservado.")
	verificar((await rodar("atacar_com(fogo, 'direita')")).begins_with("atacar_com foi substituido"), "atacar_com preservado.")
	var falsa = await rodar("if poder > 5: x = 1")
	verificar("falsa" in falsa and "nenhuma" in falsa.to_lower(), "Condicao falsa em uma linha mantem a mensagem.")
	verificar(it._avaliar_condicao("tem_chave == True") == false, "Condicao com variavel indefinida e falsa.")
	it.variaveis["tem_chave"] = true
	verificar(it._avaliar_condicao("tem_chave == True") and it._avaliar_condicao("not not tem_chave"), "Avaliar condicao (desafios) funciona.")

	# --- Python de verdade ---
	var prog = "total = 0\nfor i in range(5):\n    if i == 3:\n        continue\n    total += i\nprint(total)"
	verificar(await rodar(prog) == "7", "for + if + continue + += : 0+1+2+4 = 7.")
	prog = "n = 0\nwhile True:\n    n += 1\n    if n >= 4:\n        break\nprint('n vale', n)"
	verificar(await rodar(prog) == "n vale 4", "while True + break.")
	prog = "passos = ['cima', 'direita', 'direita']\nfor p in passos:\n    print(p)\nprint(len(passos), passos[-1])"
	verificar(await rodar(prog) == "cima\ndireita\ndireita\n3 direita", "for em lista, len e indice negativo.")
	prog = "x = 7\nif x < 5:\n    print('baixo')\nelif x < 10:\n    print('medio')\nelse:\n    print('alto')"
	verificar(await rodar(prog) == "medio", "if/elif/else em varias linhas.")
	verificar(await rodar("print(7 / 2, 7 // 2, 7 % 3, -2 + 5 * 2)") == "3.5 3 1 8", "Aritmetica igual ao Python.")
	verificar(await rodar("print('fogo' in ['gelo', 'fogo'], 3 not in [1, 2], 1 < 2 < 3)") == "True True True", "in / not in / comparacao encadeada.")
	verificar(await rodar("print([1, 2] + [3], 'ab' * 2, str(5) + '!')") == "[1, 2, 3] abab 5!", "Operacoes com listas e textos.")
	it.variaveis["fogo"] = 2
	it.variaveis["sinal"] = "gelo"
	verificar(await rodar("print(sinal == 'fogo', sinal == 'gelo')") == "False True", "Texto entre aspas nunca e trocado por variavel.")
	verificar(await rodar("if 1 > 0: print('sim')\nelse: print('nao')") == "sim", "if/else de uma linha por bloco.")

	# --- Erros com linha e explicacao ---
	verificar((await rodar("if x = 3:\n    print(1)")).begins_with("Erro de sintaxe na linha 1: No if, para comparar use =="), "= no lugar de == explicado.")
	verificar("Faltou ':' no fim do while" in await rodar("while True\n    print(1)"), "Falta de dois-pontos explicada.")
	verificar("precisa de recuo" in await rodar("for i in range(3):\nprint(i)"), "Falta de recuo explicada.")
	verificar("linha nova" in await rodar("if 1: print(1) elif 2: print(2)"), "elif na mesma linha nao e Python valido.")
	verificar("nao combina com nenhum bloco" in await rodar("if True:\n    print(1)\n  print(2)"), "Recuo torto explicado.")
	verificar("so pode ser usado dentro de um for ou while" in await rodar("break"), "break fora de laco explicado.")
	verificar("Torre das Funcoes" in await rodar("def f():\n    pass"), "def ainda bloqueado ate a Torre.")
	verificar("fora da lista" in await rodar("l = [1]\nprint(l[3])"), "Indice fora da lista explicado.")
	verificar("Nao da para somar texto com numero" in await rodar("print('a' + 1)"), "Erro de tipo explicado.")
	verificar("na linha 3" in await rodar("a = 1\nb = 2\nprint(c)"), "Erro de execucao aponta a linha.")

	# --- Protecao contra laco infinito (US05) ---
	var inf = await rodar("while True:\n    x = 1")
	verificar("Laco infinito" in inf, "Laco infinito sem acoes e interrompido.")
	verificar(not it.executando, "Interpretador libera a execucao depois de interromper.")
	verificar("range() muito grande" in await rodar("for i in range(1000):\n    pass"), "range gigante e recusado.")

	it.free()
	print("Interpretador: ", falhas, " falhas.")
	quit(1 if falhas else 0)

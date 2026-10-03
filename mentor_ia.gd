extends Node

func gerar_feedback(comando: String, resposta: String, conceitos_novos: Array, requisitos_pendentes: Array, sala: int) -> String:
	var codigo = comando.strip_edges()
	var resposta_lower = resposta.to_lower()
	
	if resposta.begins_with("Erro") or "nao reconhecido" in resposta_lower:
		return _feedback_erro(codigo, resposta_lower)
	
	if "mana insuficiente" in resposta_lower:
		return "Sem mana suficiente. Fireball custa 2 MP + o valor da variavel de poder; use um ataque curto ou mova com cuidado para recuperar 1 MP por rodada."
	
	if "protegido pela arena" in resposta_lower:
		return "Esse boss ensina escopo: alguns comandos so funcionam dentro de uma area especifica. Entre na arena marcada e ataque de la."
	
	if "bloqueado" in resposta_lower:
		return "Pense no mapa como uma matriz: cada movimento muda x ou y em 1. Use olhar() para descobrir uma rota antes de escrever muitos comandos."
	
	if "escudo magico bloqueou" in resposta_lower:
		return "Esse inimigo esta testando variaveis e mana. Guarde um numero, como poder = 3, depois use fireball(poder, 'direita'). O custo sera 2 + poder."
	
	if not conceitos_novos.is_empty():
		return _feedback_conceito(conceitos_novos[0])
	
	if not requisitos_pendentes.is_empty():
		return _feedback_proximo_passo(requisitos_pendentes[0], sala)
	
	return ""

func _feedback_erro(codigo: String, resposta_lower: String) -> String:
	if not ("(" in codigo) or not (")" in codigo):
		return "Parece faltar a estrutura de chamada de funcao: nome('argumento'). Exemplo: mover('direita')."
	
	if "aspas" in resposta_lower:
		return "Textos precisam de aspas. Direita, baixo e nomes parecidos sao strings quando aparecem como 'direita'."
	
	if "direcao invalida" in resposta_lower:
		return "As direcoes aceitas sao exatamente: 'direita', 'esquerda', 'cima' e 'baixo'. Programacao tambem exige escrita precisa."
	
	if "variavel" in resposta_lower:
		return "Variaveis precisam existir antes do uso. Primeiro crie com nome = valor, depois use o nome no comando."
	
	return "Leia a mensagem do jogo como uma pista de depuracao: compare seu comando com o exemplo e procure parenteses, aspas e virgulas."

func _feedback_conceito(conceito: String) -> String:
	match conceito:
		"sequencia":
			return "Sequenciamento e a base de um algoritmo: voce colocou passos em ordem para criar um plano."
		"variavel":
			return "Variavel e uma etiqueta para guardar um valor. O jogo lembra esse valor e voce pode reutilizar depois."
		"uso_variavel":
			return "Boa: usar a variavel mostra por que guardar valores e util. Mude o valor uma vez e o plano muda junto."
		"tipo_string":
			return "Isso e uma string: texto entre aspas. Direcoes sao textos porque representam palavras."
		"tipo_numero":
			return "Isso e um numero. Numeros servem para dano, contagem e comparacoes."
		"tipo_booleano":
			return "Isso e um booleano: True ou False. Booleanos combinam muito com if porque representam sim/nao."
		"condicional":
			return "Condicionais fazem o programa decidir. if hp > 3: atacar('direita') so executa quando a condicao e verdadeira."
		"loop":
			return "Loop evita repeticao manual. for i in range(3) executa o mesmo plano tres vezes."
	return ""

func _feedback_proximo_passo(conceito: String, sala: int) -> String:
	match conceito:
		"sequencia":
			return "Para concluir esta sala, escreva uma sequencia com ponto e virgula, por exemplo: mover('direita'); mover('direita')."
		"variavel":
			return "Crie uma variavel simples, por exemplo: direcao = 'baixo'."
		"uso_variavel":
			return "Agora use a variavel em um comando: mover(direcao) ou fireball(poder, 'direita')."
		"condicional":
			return "Use um if para decidir uma acao, por exemplo: if hp > 3: mover('direita')."
	return "Observe o objetivo da sala e tente transformar a ideia em codigo."

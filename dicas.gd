extends RefCounted

# Dicas progressivas por situacao da sala. No lugar de reduzir as dicas ao longo
# do bioma (RF018 no texto original), elas ficam sempre disponiveis com dica(),
# em 3 degraus: 1) o conceito, 2) o que fazer, 3) um exemplo quase pronto.
# Escritas a mao para funcionar sem internet; as dicas de erro de Python
# continuam com feedback_ia.gd.

const DICAS = {
	"floresta_bau": [
		"A chave da porta esta no bau dourado do abrigo ao sul. Fique ao lado dele e digite desafio(bau).",
		"No desafio do bau, guarde o numero de selos (3) em uma variavel e entregue essa variavel a abrir_bau.",
		"Exemplo, em duas linhas:\nselos = 3\nabrir_bau(selos)",
	],
	"floresta_porta": [
		"Voce ja tem a chave. Fique ao lado da porta azul e digite desafio(porta).",
		"A porta pede uma decisao com if / else: se tem_chave for True, abra a porta; senao, avise que falta a chave.",
		"Exemplo, com as acoes recuadas 4 espacos:\nif tem_chave == True:\n    abrir_porta()\nelse:\n    print('Preciso da chave')",
	],
	"floresta_guardiao": [
		"O Guardiao da Saida so pode ser atacado de dentro da area marcada perto da saida.",
		"Entre na area marcada, fique na mesma linha ou coluna dele e ataque na direcao dele.",
		"Exemplo, com ele a sua direita: poder = 3 e depois fireball(poder, 'direita'). Fireball custa 2 + poder de mana.",
	],
	"floresta_inimigos": [
		"A saida so libera quando todas as criaturas da floresta forem derrotadas.",
		"Inimigos comuns caem com atacar('direcao'). Os de escudo so caem com fireball(poder, 'direcao').",
		"Exemplo, com o inimigo de escudo a sua esquerda: poder = 3 e depois fireball(poder, 'esquerda'). Sem mana, ande: cada turno recupera 1 MP.",
	],
	"caverna_comporta": [
		"A comporta de cristal bloqueia o caminho. Fique ao lado dela e digite desafio(comporta).",
		"A comporta pede uma cadeia if / elif / else que cubra as tres temperaturas do cristal: 'fria', 'quente' e 'ideal'.",
		"Exemplo:\nif temperatura_cristal == 'fria':\n    print('Preciso de mais calor')\nelif temperatura_cristal == 'quente':\n    print('Preciso de menos calor')\nelse:\n    abrir_comporta()",
	],
	"caverna_ecos": [
		"Ecos elementais so caem com fireball do elemento escrito embaixo deles. Inimigos de escudo caem com qualquer fireball.",
		"O nome da variavel e o elemento: crie fogo = 3, gelo = 3 ou arcano = 3 e use a variavel do elemento do Eco.",
		"Exemplo, com um Eco de gelo a sua direita: gelo = 3 e depois fireball(gelo, 'direita'). Sem mana, ande para recuperar.",
	],
	"oraculo": [
		"O Oraculo so sente fireball do elemento que ele sinaliza, e o sinal muda a cada ataque. O sinal atual fica em sinal_oraculo.",
		"Tenha fogo, gelo e arcano criados e escolha a fireball com if / elif / else lendo sinal_oraculo. Na ultima fase, so uma cadeia if / elif / else o fere.",
		"Exemplo no grimorio (troque a direcao pela do Oraculo):\nif sinal_oraculo == 'fogo':\n    fireball(fogo, 'direita')\nelif sinal_oraculo == 'gelo':\n    fireball(gelo, 'direita')\nelse:\n    fireball(arcano, 'direita')",
	],
	"nevoa": [
		"A nevoa esconde o corredor, e ele muda de tamanho a cada visita: contar casas nao funciona.",
		"Repita mover ENQUANTO houver caminho: while caminho_livre('direcao'). O corredor segue para a direita, para baixo e para a direita de novo.",
		"Exemplo no grimorio:\nfor direcao in ['direita', 'baixo', 'direita']:\n    while caminho_livre(direcao):\n        mover(direcao)",
	],
	"elos": [
		"Golpes soltos nao partem um Elo: so golpes repetidos por um laco (for ou while).",
		"Voce nao sabe quantos Elos existem: use um while com sensores. Ataque se houver um Elo a frente; senao, avance.",
		"Exemplo:\nwhile inimigos_restantes() > 0:\n    if inimigo_a_frente('direita'):\n        atacar('direita')\n    else:\n        mover('direita')",
	],
	"ponte": [
		"A ponte so aceita passos dados dentro de um laco, e o caminho esta guardado na lista passos.",
		"Percorra a lista com for: para cada item de passos, mova nessa direcao. Se o laco parar no meio, a ponte se desfaz.",
		"Exemplo:\nfor passo in passos:\n    mover(passo)",
	],
	"ouroboros": [
		"A serpente so sente atacar(...) dentro de um while. Magia reflete, e golpes soltos ou de for nao contam.",
		"Fique ao lado dela e repita o ataque enquanto ela estiver ali. Se o laco terminar antes dela cair, ela se fecha de novo.",
		"Exemplo, com ela a sua direita:\nwhile inimigo_a_frente('direita'):\n    atacar('direita')",
	],
	"sentinelas": [
		"As Sentinelas so sentem golpes vindos de dentro de uma funcao (def). Golpes soltos e lacos sem funcao nao contam.",
		"Crie uma funcao que ataca duas vezes para baixo e chame-a acima de cada Sentinela.",
		"Exemplo no grimorio:\ndef golpe_duplo():\n    atacar('baixo')\n    atacar('baixo')\nDepois, acima de cada Sentinela, digite golpe_duplo()",
	],
	"gemeas": [
		"As Sentinelas Gemeas so sentem funcoes com parametros, e cada uma pede um numero de golpes (veja RUNA acima delas).",
		"Crie uma funcao que recebe a direcao e quantas vezes atacar, e chame-a uma vez para cada Sentinela.",
		"Exemplo:\ndef golpear(direcao, vezes):\n    for i in range(vezes):\n        atacar(direcao)\ngolpear('cima', 2)",
	],
	"selo": [
		"O Selo testa a funcao poder_da_runa(runa): ela precisa DEVOLVER, com return, o poder de cada runa: fogo 3, gelo 2, arcano 1.",
		"Use if / elif para escolher o valor e return para devolve-lo. print so mostra na tela; o Selo precisa do return. Depois digite abrir_selo().",
		"Exemplo:\ndef poder_da_runa(runa):\n    if runa == 'fogo':\n        return 3\n    elif runa == 'gelo':\n        return 2\n    return 1",
	],
	"arquimago": [
		"O Arquimago muda de pedestal a cada turno e so sente golpes de uma funcao que decide com if, chamada dentro de um laco.",
		"Na funcao, descubra com inimigo_a_frente(d) em qual direcao ele esta e ataque so ali. Chame a funcao num while que so para quando ele cair.",
		"Exemplo:\ndef golpe():\n    for d in ['cima', 'baixo', 'esquerda', 'direita']:\n        if inimigo_a_frente(d):\n            atacar(d)\n            return\nwhile inimigos_restantes() > 0:\n    golpe()",
	],
	"saida": [
		"O objetivo desta sala esta cumprido: va ate a saida verde.",
		"Use mover('direcao') ate pisar na saida verde, marcada com uma seta.",
		"Se algo bloquear o caminho, leia a mensagem do terminal: ela diz o que esta no caminho.",
	],
	"geral": [
		"Leia o anuncio da sala no terminal e abra o Livro (botao no canto) para ver os comandos liberados.",
		"Se uma acao falhar, leia a mensagem: ela diz o que o jogo espera. reiniciar_sala() recomeca a sala.",
		"Teste por partes: execute um comando de cada vez antes de juntar tudo em um programa.",
	],
}

# Respostas do jogo que indicam que o aluno tentou, mas a regra da sala nao
# aceitou (nao sao erros de Python, entao a IA nao reage a elas).
const FALHAS_DE_REGRA = [
	"ignora o golpe solto", "ignora funcoes sem parametros", "absorveu o golpe solto",
	"refletem a magia", "se fecha a cada golpe solto", "se fechou de novo",
	"desfaz golpes soltos", "se recompos", "veio as cegas", "selos se refizeram",
	"nao afeta o Eco", "atravessam o Eco", "escudo magico bloqueou",
	"nao e o elemento certo", "nao ecoam no Oraculo", "ignora respostas isoladas", "protegido pela arena",
	"nao sustenta passos soltos", "ela se desfez",
]

var _niveis: Dictionary = {}  # topico -> ultimo degrau mostrado (0 a 3)

func nivel(topico: String) -> int:
	return _niveis.get(topico, 0)

# Proximo degrau do topico (pedido com dica()); no ultimo, repete o exemplo.
func proxima(topico: String) -> Dictionary:
	var degrau = mini(nivel(topico) + 1, 3)
	_niveis[topico] = degrau
	return {"nivel": degrau, "texto": DICAS[topico][degrau - 1]}

# Primeiro degrau, so na primeira falha de regra do topico (para nao repetir).
func empurrao(topico: String) -> String:
	if nivel(topico) > 0:
		return ""
	_niveis[topico] = 1
	return DICAS[topico][0]

func eh_falha_de_regra(resposta: String) -> bool:
	for marca in FALHAS_DE_REGRA:
		if marca in resposta:
			return true
	return false

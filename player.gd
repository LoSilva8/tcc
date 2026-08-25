extends CharacterBody2D

const TAMANHO_CELULA = 64

var grid_pos: Vector2i = Vector2i(1, 1)
var mapa: Node = null
var gerenciador_inimigos: Node = null
var interpretador: Node = null

var hp: int = 10
var hp_max: int = 10
var vivo: bool = true

signal jogador_morreu
signal hp_alterado(hp_atual, hp_max)
signal chegou_na_saida

func _ready():
	_sincronizar_posicao()

func executar_comando(comando: String) -> String:
	if not vivo:
		return "Voce esta derrotado. Digite reiniciar() para tentar novamente."
	
	comando = comando.strip_edges()
	
	if comando == "reiniciar()":
		return "Use reiniciar() no terminal para recomecar."
	
	# Detecta mover() com aspas — correto
	var regex_mover = RegEx.new()
	regex_mover.compile("mover\\(['\"](.+)['\"]\\)")
	var resultado_mover = regex_mover.search(comando)
	if resultado_mover:
		return _mover(resultado_mover.get_string(1))

	# Detecta mover() sem aspas — erro pedagógico
	var regex_mover_sem_aspas = RegEx.new()
	regex_mover_sem_aspas.compile("mover\\((\\w+)\\)")
	var resultado_sem_aspas = regex_mover_sem_aspas.search(comando)
	if resultado_sem_aspas:
		var arg = resultado_sem_aspas.get_string(1)
		# Verifica se é uma variável definida pelo jogador
		if interpretador and arg in interpretador.variaveis:
			return _mover(str(interpretador.variaveis[arg]))
		# Se não for variável, é erro de sintaxe
		return "Erro: '" + arg + "' nao e uma string nem uma variavel definida.\nDica: use aspas — mover('" + arg + "')"
		
	# Detecta atacar() com aspas — correto
	var regex_atacar = RegEx.new()
	regex_atacar.compile("atacar\\(['\"](.+)['\"]\\)")
	var resultado_atacar = regex_atacar.search(comando)
	if resultado_atacar:
		return _atacar(resultado_atacar.get_string(1))

	# Detecta atacar() sem aspas — erro pedagógico
	var regex_atacar_sem_aspas = RegEx.new()
	regex_atacar_sem_aspas.compile("atacar\\((\\w+)\\)")
	var resultado_atacar_sem_aspas = regex_atacar_sem_aspas.search(comando)
	if resultado_atacar_sem_aspas:
		var arg = resultado_atacar_sem_aspas.get_string(1)
		if interpretador and arg in interpretador.variaveis:
			return _atacar(str(interpretador.variaveis[arg]))
		return "Erro: '" + arg + "' nao e uma string nem uma variavel definida.\nDica: use aspas — atacar('" + arg + "')"
	
	var regex_atacar_com = RegEx.new()
	regex_atacar_com.compile("atacar_com\\((\\w+),\\s*['\"]?(\\w+)['\"]?\\)")
	var resultado_atacar_com = regex_atacar_com.search(comando)
	if resultado_atacar_com:
		var nome_var = resultado_atacar_com.get_string(1)
		var direcao = resultado_atacar_com.get_string(2)
		return _atacar_com_variavel(nome_var, direcao)
	
	return "Comando nao reconhecido. Tente: mover('direita') ou atacar('direita')"

func _mover(direcao: String) -> String:
	var nova_pos = grid_pos
	
	match direcao:
		"direita": nova_pos.x += 1
		"esquerda": nova_pos.x -= 1
		"cima": nova_pos.y -= 1
		"baixo": nova_pos.y += 1
		_: return "Direcao invalida. Use: direita, esquerda, cima ou baixo."
	
	if mapa and mapa.eh_parede(nova_pos):
		return "Bloqueado. Ha uma parede nessa direcao."
	
	if gerenciador_inimigos and gerenciador_inimigos.tem_inimigo(nova_pos):
		return _receber_dano(1, "Voce colidiu com um inimigo.")
	
	grid_pos = nova_pos
	_sincronizar_posicao()
	
	if mapa and mapa.checar_saida(grid_pos):
		emit_signal("chegou_na_saida")
		return "Voce encontrou a saida."
	
	return "Moveu para " + direcao + ". Posicao: " + str(grid_pos)

func _atacar(direcao: String) -> String:
	var alvo = grid_pos
	
	match direcao:
		"direita": alvo.x += 1
		"esquerda": alvo.x -= 1
		"cima": alvo.y -= 1
		"baixo": alvo.y += 1
		_: return "Direcao invalida."
	
	if gerenciador_inimigos:
		return gerenciador_inimigos.atacar_posicao(alvo)
	
	return "Erro: gerenciador nao encontrado."

func receber_dano_externo(dano: int) -> String:
	return _receber_dano(dano, "Um inimigo te atacou.")

func _receber_dano(dano: int, motivo: String) -> String:
	hp -= dano
	hp = max(hp, 0)
	emit_signal("hp_alterado", hp, hp_max)
	
	if hp <= 0:
		vivo = false
		emit_signal("jogador_morreu")
		return motivo + " HP: 0/" + str(hp_max) + "\nVoce foi derrotado. A run terminou."
	
	return motivo + " HP: " + str(hp) + "/" + str(hp_max)

func resetar():
	hp = hp_max
	vivo = true
	grid_pos = Vector2i(1, 1)
	_sincronizar_posicao()
	emit_signal("hp_alterado", hp, hp_max)

func _atacar_com_variavel(nome_variavel: String, direcao: String) -> String:
	var alvo = grid_pos
	
	match direcao:
		"direita": alvo.x += 1
		"esquerda": alvo.x -= 1
		"cima": alvo.y -= 1
		"baixo": alvo.y += 1
		_: return "Direcao invalida."
	
	var dano = 1
	if interpretador and nome_variavel in interpretador.variaveis:
		var valor = interpretador.variaveis[nome_variavel]
		if typeof(valor) == TYPE_INT or typeof(valor) == TYPE_FLOAT:
			dano = int(valor)
	
	if gerenciador_inimigos:
		return gerenciador_inimigos.atacar_posicao(alvo, dano, true, nome_variavel)
	
	return "Erro: gerenciador nao encontrado."

func _sincronizar_posicao():
	var destino = Vector2(grid_pos) * TAMANHO_CELULA + Vector2(TAMANHO_CELULA / 2, TAMANHO_CELULA / 2)
	var tween = create_tween()
	tween.tween_property(self, "position", destino, 0.15)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

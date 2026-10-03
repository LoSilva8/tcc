extends CharacterBody2D

const TAMANHO_CELULA = 64
const HP_MAX_BASE = 10
const FIREBALL_ALCANCE = 4
const MANA_MAX_BASE = 6
const FIREBALL_CUSTO_BASE = 2
const MANA_RECUPERADA_POR_RODADA = 1

var grid_pos: Vector2i = Vector2i(1, 1)
var mapa: Node = null
var gerenciador_inimigos: Node = null
var interpretador: Node = null

var hp: int = 10
var hp_max: int = 10
var mana: int = 6
var mana_max: int = 6
var vivo: bool = true

var nivel: int = 1
var xp: int = 0
var xp_prox: int = 5
var dano_base: int = 1
var pending_escolha: Array = []
var xp_habilitado: bool = false

signal jogador_morreu
signal hp_alterado(hp_atual, hp_max)
signal mana_alterada(mana_atual, mana_max)
signal chegou_na_saida
signal xp_alterado(xp_atual, xp_prox, nivel)
signal nivel_up(opcoes)

func _ready():
	_sincronizar_posicao()

func executar_comando(comando: String) -> String:
	if not vivo:
		return "Voce esta derrotado. Digite reiniciar() para tentar novamente."
	
	comando = comando.strip_edges()
	
	if not pending_escolha.is_empty() and comando != "reiniciar()":
		var regex_escolher = RegEx.new()
		regex_escolher.compile("^escolher\\((\\d+)\\)$")
		var resultado_escolher = regex_escolher.search(comando)
		if resultado_escolher:
			return escolher_upgrade(int(resultado_escolher.get_string(1)))
		return "Voce subiu de nivel! Escolha uma runa antes de continuar.\nUse: escolher(1), escolher(2) ou escolher(3)"
	
	if comando == "reiniciar()":
		return "Use reiniciar() no terminal para recomecar."
	
	# Detecta mover() com aspas — correto
	var regex_mover = RegEx.new()
	regex_mover.compile("mover\\(['\"](.+)['\"]\\)")
	var resultado_mover = regex_mover.search(comando)
	if resultado_mover:
		return _mover(resultado_mover.get_string(1))

	# Detecta mover() sem aspas — erro pedagogico
	var regex_mover_sem_aspas = RegEx.new()
	regex_mover_sem_aspas.compile("mover\\((\\w+)\\)")
	var resultado_sem_aspas = regex_mover_sem_aspas.search(comando)
	if resultado_sem_aspas:
		var arg = resultado_sem_aspas.get_string(1)
		if interpretador and arg in interpretador.variaveis:
			return _mover(str(interpretador.variaveis[arg]))
		return "Erro: '" + arg + "' nao e uma string nem uma variavel definida.\nDica: use aspas — mover('" + arg + "')"
		
	# Detecta atacar() com aspas — correto
	var regex_atacar = RegEx.new()
	regex_atacar.compile("atacar\\(['\"](.+)['\"]\\)")
	var resultado_atacar = regex_atacar.search(comando)
	if resultado_atacar:
		return _atacar(resultado_atacar.get_string(1))

	# Detecta atacar() sem aspas — erro pedagogico
	var regex_atacar_sem_aspas = RegEx.new()
	regex_atacar_sem_aspas.compile("atacar\\((\\w+)\\)")
	var resultado_atacar_sem_aspas = regex_atacar_sem_aspas.search(comando)
	if resultado_atacar_sem_aspas:
		var arg = resultado_atacar_sem_aspas.get_string(1)
		if interpretador and arg in interpretador.variaveis:
			return _atacar(str(interpretador.variaveis[arg]))
		return "Erro: '" + arg + "' nao e uma string nem uma variavel definida.\nDica: use aspas — atacar('" + arg + "')"
	
	var regex_fireball = RegEx.new()
	regex_fireball.compile("fireball\\((\\w+),\\s*['\"]?(\\w+)['\"]?\\)")
	var resultado_fireball = regex_fireball.search(comando)
	if resultado_fireball:
		var nome_var = resultado_fireball.get_string(1)
		var direcao = resultado_fireball.get_string(2)
		return _fireball_com_variavel(nome_var, direcao)
	
	var regex_atacar_com = RegEx.new()
	regex_atacar_com.compile("atacar_com\\((.+)\\)")
	if regex_atacar_com.search(comando):
		return "atacar_com foi substituido por fireball.\nUse: fireball(poder, 'direcao')"
	
	return "Comando nao reconhecido. Tente: mover('direita'), atacar('direita') ou fireball(poder, 'direita')"

# Ponto de entrada do interpretador: recebe a acao ja com os argumentos avaliados.
# Mantem as mesmas travas de executar_comando (derrotado / runa pendente).
func executar_acao(nome: String, args: Array) -> String:
	if not vivo:
		return "Voce esta derrotado. Digite reiniciar() para tentar novamente."
	if nome == "escolher":
		return escolher_upgrade(int(args[0]))
	if not pending_escolha.is_empty():
		return "Voce subiu de nivel! Escolha uma runa antes de continuar.\nUse: escolher(1), escolher(2) ou escolher(3)"
	match nome:
		"mover":
			return _mover(str(args[0]))
		"atacar":
			return _atacar(str(args[0]))
		"fireball":
			return _fireball_com_variavel(str(args[0]), str(args[1]))
	return "Comando nao reconhecido. Tente: mover('direita'), atacar('direita') ou fireball(poder, 'direita')"

func _mover(direcao: String) -> String:
	var nova_pos = grid_pos
	
	match direcao:
		"direita": nova_pos.x += 1
		"esquerda": nova_pos.x -= 1
		"cima": nova_pos.y -= 1
		"baixo": nova_pos.y += 1
		_: return "Direcao invalida. Use: direita, esquerda, cima ou baixo."
	
	if mapa and mapa.eh_parede(nova_pos):
		if mapa.sala_atual == 1 and nova_pos == mapa.PORTA_POS:
			return "Bloqueado. Para abrir a porta, digite desafio(porta)."
		if mapa.sala_atual == 1 and nova_pos == mapa.BAU_POS:
			return "Bloqueado. Para abrir o bau, digite desafio(bau)."
		if mapa.sala_atual == 5 and nova_pos == mapa.COMPORTA_POS:
			return "Bloqueado. Para estabilizar a comporta, digite desafio(comporta)."
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
		return gerenciador_inimigos.atacar_posicao(alvo, dano_base)
	
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
	hp_max = HP_MAX_BASE
	hp = hp_max
	mana_max = MANA_MAX_BASE
	mana = mana_max
	vivo = true
	grid_pos = Vector2i(1, 1)
	_sincronizar_posicao()
	emit_signal("hp_alterado", hp, hp_max)
	emit_signal("mana_alterada", mana, mana_max)
	
	nivel = 1
	xp = 0
	xp_prox = 5
	dano_base = 1
	pending_escolha = []
	xp_habilitado = false
	emit_signal("xp_alterado", xp, xp_prox, nivel)

func curar_total():
	hp = hp_max
	mana = mana_max
	vivo = true
	emit_signal("hp_alterado", hp, hp_max)
	emit_signal("mana_alterada", mana, mana_max)

func _fireball_com_variavel(nome_variavel: String, direcao_arg: String) -> String:
	if interpretador == null or not (nome_variavel in interpretador.variaveis):
		return "A variavel '" + nome_variavel + "' nao foi definida.\nCrie-a antes: " + nome_variavel + " = valor"
	
	var poder = interpretador.variaveis[nome_variavel]
	if not (typeof(poder) == TYPE_INT or typeof(poder) == TYPE_FLOAT):
		return "Fireball precisa de uma variavel numerica.\nExemplo: poder = 3"
	var custo_mana = _calcular_custo_fireball(poder)
	if mana < custo_mana:
		return "Mana insuficiente para fireball. Custo: " + str(custo_mana) + " MP (2 + " + str(max(int(poder), 0)) + " de poder). Mana: " + str(mana) + "/" + str(mana_max) + "\nUse mover('direcao') ou atacar('direcao') para passar uma rodada e recuperar mana."
	
	var direcao = _resolver_direcao_fireball(direcao_arg)
	var vetor = _vetor_direcao(direcao)
	if vetor == Vector2i.ZERO:
		return "Direcao invalida. Use: direita, esquerda, cima ou baixo."
	
	if gerenciador_inimigos == null:
		return "Erro: gerenciador nao encontrado."
	
	_gastar_mana(custo_mana)
	
	var dano = clamp(int(poder) + max(dano_base - 1, 0), 1, 8)
	var ultimo_ponto = grid_pos
	
	for distancia in range(1, FIREBALL_ALCANCE + 1):
		var alvo = grid_pos + vetor * distancia
		
		if mapa and mapa.eh_parede(alvo):
			_mostrar_fireball(ultimo_ponto)
			return "Fireball bateu em uma parede antes de atingir um inimigo. Custo: " + str(custo_mana) + " MP. Mana: " + str(mana) + "/" + str(mana_max) + "."
		
		ultimo_ponto = alvo
		
		if gerenciador_inimigos.tem_inimigo(alvo):
			_mostrar_fireball(alvo)
			var encadeado = interpretador.ultimo_encadeado if interpretador else false
			var resultado = gerenciador_inimigos.atacar_posicao(alvo, dano, true, nome_variavel, encadeado)
			return "Fireball lancada com " + nome_variavel + " = " + str(poder) + ". Custo: " + str(custo_mana) + " MP. Mana: " + str(mana) + "/" + str(mana_max) + ".\n" + resultado
	
	_mostrar_fireball(ultimo_ponto)
	return "Fireball voou " + str(FIREBALL_ALCANCE) + " casas para " + direcao + ", mas nao atingiu inimigos. Custo: " + str(custo_mana) + " MP. Mana: " + str(mana) + "/" + str(mana_max) + "."

func _calcular_custo_fireball(poder) -> int:
	return FIREBALL_CUSTO_BASE + max(int(poder), 0)

func _gastar_mana(qtd: int):
	mana = max(mana - qtd, 0)
	emit_signal("mana_alterada", mana, mana_max)

func recuperar_mana_rodada() -> String:
	var mana_antes = mana
	mana = min(mana + MANA_RECUPERADA_POR_RODADA, mana_max)
	
	if mana == mana_antes:
		return ""
	
	emit_signal("mana_alterada", mana, mana_max)
	return "[mana] +" + str(mana - mana_antes) + " Mana: " + str(mana) + "/" + str(mana_max)

func _resolver_direcao_fireball(direcao_arg: String) -> String:
	if direcao_arg in ["direita", "esquerda", "cima", "baixo"]:
		return direcao_arg
	if interpretador and direcao_arg in interpretador.variaveis:
		return str(interpretador.variaveis[direcao_arg])
	return direcao_arg

func _vetor_direcao(direcao: String) -> Vector2i:
	match direcao:
		"direita": return Vector2i(1, 0)
		"esquerda": return Vector2i(-1, 0)
		"cima": return Vector2i(0, -1)
		"baixo": return Vector2i(0, 1)
	return Vector2i.ZERO

func _mostrar_fireball(alvo_grid: Vector2i):
	var cena = get_tree().current_scene
	if cena == null:
		return
	
	var origem = Vector2(grid_pos) * TAMANHO_CELULA + Vector2(TAMANHO_CELULA / 2, TAMANHO_CELULA / 2)
	var destino = Vector2(alvo_grid) * TAMANHO_CELULA + Vector2(TAMANHO_CELULA / 2, TAMANHO_CELULA / 2)
	
	var rastro = Line2D.new()
	rastro.width = 9.0
	rastro.default_color = Color(1.0, 0.36, 0.08, 0.9)
	rastro.points = PackedVector2Array([origem, destino])
	rastro.z_index = 25
	cena.add_child(rastro)
	
	var tween = create_tween()
	tween.tween_property(rastro, "modulate:a", 0.0, 0.28)
	tween.tween_callback(rastro.queue_free)

func ganhar_xp(qtd: int):
	if qtd <= 0 or not xp_habilitado:
		return
	
	xp += qtd
	emit_signal("xp_alterado", xp, xp_prox, nivel)
	
	while xp >= xp_prox:
		xp -= xp_prox
		nivel += 1
		xp_prox = 5 + (nivel - 1) * 3
		emit_signal("xp_alterado", xp, xp_prox, nivel)
		_solicitar_escolha_nivel()

func _solicitar_escolha_nivel():
	pending_escolha = _sortear_upgrades(3)
	emit_signal("nivel_up", pending_escolha)

func _sortear_upgrades(qtd: int) -> Array:
	var pool = [
		{"nome": "Furia Arcana", "desc": "+1 de dano base em todos os ataques", "tipo": "dano", "valor": 1},
		{"nome": "Vigor da Serpente", "desc": "+3 HP maximo e cura completa", "tipo": "hp_max", "valor": 3},
		{"nome": "Folego Extra", "desc": "Cura totalmente o HP atual", "tipo": "cura", "valor": 0},
		{"nome": "Precisao Elfica", "desc": "+2 de dano base", "tipo": "dano", "valor": 2},
		{"nome": "Fonte de Mana", "desc": "+2 MP maximo e recupera 2 MP", "tipo": "mana_max", "valor": 2},
	]
	pool.shuffle()
	var qtd_real = min(qtd, pool.size())
	return pool.slice(0, qtd_real)

func escolher_upgrade(indice: int) -> String:
	if pending_escolha.is_empty():
		return "Nao ha escolhas pendentes."
	if indice < 1 or indice > pending_escolha.size():
		return "Escolha invalida. Use um numero entre 1 e " + str(pending_escolha.size()) + "."
	
	var escolha = pending_escolha[indice - 1]
	match escolha["tipo"]:
		"dano":
			dano_base += escolha["valor"]
		"hp_max":
			hp_max += escolha["valor"]
			hp = hp_max
			emit_signal("hp_alterado", hp, hp_max)
		"mana_max":
			mana_max += escolha["valor"]
			mana = min(mana + escolha["valor"], mana_max)
			emit_signal("mana_alterada", mana, mana_max)
		"cura":
			hp = hp_max
			emit_signal("hp_alterado", hp, hp_max)
	
	pending_escolha = []
	return "Voce escolheu: " + escolha["nome"] + "!\n" + escolha["desc"]

func _sincronizar_posicao():
	var destino = Vector2(grid_pos) * TAMANHO_CELULA + Vector2(TAMANHO_CELULA / 2, TAMANHO_CELULA / 2)
	var tween = create_tween()
	tween.tween_property(self, "position", destino, 0.15)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

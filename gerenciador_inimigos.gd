extends Node2D

const InimigoCena = preload("res://inimigo.tscn")
const InimigoEscudoCena = preload("res://inimigo_escudo.tscn")
const InimigoElementalCena = preload("res://inimigo_elemental.tscn")
const ChefeFlorestaCena = preload("res://chefe_floresta.tscn")
const ChefeCavernaCena = preload("res://chefe_caverna.tscn")
const BossSaidaCena = preload("res://boss_saida.tscn")
const EloCena = preload("res://elo.tscn")
const OuroborosCena = preload("res://ouroboros.tscn")
const SentinelaCena = preload("res://sentinela.tscn")
const ArquimagoCena = preload("res://arquimago.tscn")
const TAMANHO_CELULA = 64
const PASSOS = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var inimigos: Dictionary = {}
var mapa: Node = null
var player: Node = null

signal chefe_derrotado

func spawnar_inimigo(pos: Vector2i):
	if pos in inimigos:
		return
	if mapa and mapa.eh_parede(pos):
		return

	var inimigo = InimigoCena.instantiate()
	add_child(inimigo)
	inimigo.inicializar(pos)
	inimigos[pos] = inimigo

func spawnar_inimigo_escudo(pos: Vector2i, hp_inicial: int = 5):
	if pos in inimigos:
		return
	if mapa and mapa.eh_parede(pos):
		return

	var inimigo = InimigoEscudoCena.instantiate()
	add_child(inimigo)
	inimigo.inicializar(pos, hp_inicial)
	inimigos[pos] = inimigo

func spawnar_inimigo_elemental(pos: Vector2i, hp_inicial: int = 4, elemento: String = ""):
	if pos in inimigos:
		return
	if mapa and mapa.eh_parede(pos):
		return

	var inimigo = InimigoElementalCena.instantiate()
	add_child(inimigo)
	inimigo.inicializar(pos, hp_inicial, elemento)
	inimigos[pos] = inimigo

func spawnar_chefe(pos: Vector2i):
	if pos in inimigos:
		return
	if mapa and mapa.eh_parede(pos):
		return

	var chefe = ChefeFlorestaCena.instantiate()
	add_child(chefe)
	chefe.inicializar(pos)
	chefe.chefe_derrotado.connect(func(): emit_signal("chefe_derrotado"))
	inimigos[pos] = chefe

func spawnar_chefe_caverna(pos: Vector2i):
	if pos in inimigos:
		return
	if mapa and mapa.eh_parede(pos):
		return

	var chefe = ChefeCavernaCena.instantiate()
	add_child(chefe)
	chefe.inicializar(pos)
	chefe.chefe_derrotado.connect(func(): emit_signal("chefe_derrotado"))
	inimigos[pos] = chefe

func spawnar_elo(pos: Vector2i):
	if pos in inimigos:
		return
	if mapa and mapa.eh_parede(pos):
		return
	var elo = EloCena.instantiate()
	add_child(elo)
	elo.inicializar(pos)
	inimigos[pos] = elo

func spawnar_ouroboros(pos: Vector2i):
	if pos in inimigos:
		return
	if mapa and mapa.eh_parede(pos):
		return
	var serpente = OuroborosCena.instantiate()
	add_child(serpente)
	serpente.inicializar(pos)
	serpente.chefe_derrotado.connect(func(): emit_signal("chefe_derrotado"))
	inimigos[pos] = serpente

func spawnar_sentinela(pos: Vector2i, golpes: int = 2, exige_parametro: bool = false):
	if pos in inimigos:
		return
	if mapa and mapa.eh_parede(pos):
		return
	var sentinela = SentinelaCena.instantiate()
	add_child(sentinela)
	sentinela.inicializar(pos, golpes, exige_parametro)
	if mapa and not mapa.eh_parede(pos + Vector2i(0, -1)) and mapa.eh_parede(pos + Vector2i(0, 1)):
		sentinela.rotulo_embaixo()
	inimigos[pos] = sentinela

func spawnar_arquimago(pos: Vector2i, pedestais: Array):
	if pos in inimigos:
		return
	var arquimago = ArquimagoCena.instantiate()
	add_child(arquimago)
	arquimago.inicializar(pos, pedestais)
	arquimago.chefe_derrotado.connect(func(): emit_signal("chefe_derrotado"))
	inimigos[pos] = arquimago

func chefe_labirinto_vivo() -> bool:
	for pos in inimigos:
		var i = inimigos[pos]
		if i.get_script() == preload("res://ouroboros.gd") and i.vivo:
			return true
	return false

# Efeitos que dependem do fim de um programa (ex.: o Ouroboros se fecha de novo).
func fim_de_programa() -> String:
	var avisos: Array = []
	for pos in inimigos.keys():
		var i = inimigos[pos]
		if i.vivo and i.has_method("ao_fim_do_programa"):
			var aviso = i.ao_fim_do_programa()
			if aviso != "":
				avisos.append(aviso)
	return "\n".join(avisos)

func _laco_ativo(so_while: bool) -> bool:
	if player == null or player.interpretador == null:
		return false
	return player.interpretador.dentro_de_while() if so_while else player.interpretador.dentro_de_laco()

func _funcao_ativa() -> bool:
	return player != null and player.interpretador != null and player.interpretador.dentro_de_funcao()

func _if_ativo() -> bool:
	return player != null and player.interpretador != null and player.interpretador.dentro_de_if()

func spawnar_boss_saida(pos: Vector2i, area_inicio: Vector2i, area_tamanho: Vector2i):
	if pos in inimigos:
		return
	if mapa and mapa.eh_parede(pos):
		return

	var boss = BossSaidaCena.instantiate()
	add_child(boss)
	boss.inicializar(pos, area_inicio, area_tamanho)
	inimigos[pos] = boss

func chefe_vivo() -> bool:
	for pos in inimigos:
		var i = inimigos[pos]
		if i.get_script() == preload("res://chefe_floresta.gd") and i.vivo:
			return true
	return false

func chefe_caverna_vivo() -> bool:
	for pos in inimigos:
		var i = inimigos[pos]
		if i.get_script() == preload("res://chefe_caverna.gd") and i.vivo:
			return true
	return false

func sinal_chefe_caverna() -> String:
	for pos in inimigos:
		var i = inimigos[pos]
		if i.get_script() == preload("res://chefe_caverna.gd") and i.vivo:
			return i.sinal_atual
	return ""

func boss_saida_vivo() -> bool:
	for pos in inimigos:
		var i = inimigos[pos]
		if i.has_method("eh_boss_saida") and i.eh_boss_saida() and i.vivo:
			return true
	return false

func atacar_posicao(pos: Vector2i, dano: int = 1, usando_variavel: bool = false, nome_variavel: String = "", encadeado: bool = false) -> String:
	if pos in inimigos:
		var inimigo = inimigos[pos]
		if not inimigo.vivo:
			inimigos.erase(pos)
			return "Nenhum inimigo aqui."
		if _ataque_bloqueado_por_area(inimigo):
			return inimigo.mensagem_fora_da_area()

		var resultado = ""

		if inimigo.get_script() == preload("res://chefe_floresta.gd"):
			if not usando_variavel:
				resultado = "Ataques comuns nao afetam o Guardiao de Runas.\nUse fireball(variavel, 'direcao') com o nome certo."
			else:
				resultado = inimigo.receber_dano(dano, nome_variavel)
		elif inimigo.get_script() == preload("res://chefe_caverna.gd"):
			if not usando_variavel:
				resultado = "Ataques comuns nao ecoam no Oraculo Bifurcado.\nUse fireball(variavel, 'direcao') com o elemento certo."
			else:
				resultado = inimigo.receber_dano(dano, nome_variavel, encadeado)
		elif inimigo.get_script() == preload("res://elo.gd"):
			resultado = inimigo.receber_dano(dano, _laco_ativo(false))
		elif inimigo.get_script() == preload("res://ouroboros.gd"):
			resultado = inimigo.receber_dano(dano, usando_variavel, _laco_ativo(true))
		elif inimigo.get_script() == preload("res://arquimago.gd"):
			resultado = inimigo.receber_dano(dano, _funcao_ativa(), _laco_ativo(false), _if_ativo())
		elif inimigo.get_script() == preload("res://sentinela.gd"):
			var interpretador = player.interpretador if player else null
			resultado = inimigo.receber_dano(dano, _funcao_ativa(), interpretador != null and interpretador.funcao_com_parametros())
		elif inimigo.get_script() == preload("res://inimigo_escudo.gd"):
			resultado = inimigo.receber_dano(dano, usando_variavel)
		elif inimigo.get_script() == preload("res://inimigo_elemental.gd"):
			resultado = inimigo.receber_dano(dano, usando_variavel, nome_variavel)
		else:
			resultado = inimigo.receber_dano(dano)

		if "xp_gerado" in inimigo and inimigo.xp_gerado > 0:
			if player:
				player.ganhar_xp(inimigo.xp_gerado)
			inimigo.xp_gerado = 0

		if not inimigo.vivo:
			inimigos.erase(pos)

		return resultado

	return "Nenhum inimigo nessa direcao."

func tem_inimigo(pos: Vector2i) -> bool:
	return pos in inimigos and inimigos[pos].vivo

func quantidade_inimigos_vivos() -> int:
	var total = 0
	for pos in inimigos.keys():
		var inimigo = inimigos[pos]
		if inimigo.vivo:
			total += 1
	return total

func tem_inimigos_vivos() -> bool:
	return quantidade_inimigos_vivos() > 0

func processar_turno_inimigos() -> String:
	if player == null or not player.vivo:
		return ""
	if inimigos.is_empty():
		return ""

	var eventos: Array = []
	var posicoes = inimigos.keys()

	for pos_atual in posicoes:
		if player == null or not player.vivo:
			break
		if not inimigos.has(pos_atual):
			continue

		var inimigo = inimigos[pos_atual]
		if not inimigo.vivo:
			inimigos.erase(pos_atual)
			continue
		if inimigo.has_method("turno_especial"):
			var evento = inimigo.turno_especial(player)
			if evento != "":
				eventos.append(evento)
			if inimigo.vivo and inimigo.has_method("proximo_pedestal"):
				var destino = inimigo.proximo_pedestal()
				if not inimigos.has(destino):
					_mover_inimigo(pos_atual, destino, inimigo)
			continue
		if inimigo.has_method("pode_agir_contra") and not inimigo.pode_agir_contra(player.grid_pos):
			continue

		if _distancia(pos_atual, player.grid_pos) == 1:
			eventos.append(_inimigo_ataca(inimigo))
			continue

		var nova_pos = _proximo_passo(pos_atual, player.grid_pos, inimigo)
		if nova_pos != pos_atual:
			_mover_inimigo(pos_atual, nova_pos, inimigo)
			eventos.append("[inimigo] " + _nome_inimigo(inimigo) + " avancou para " + str(nova_pos) + ".")

	if eventos.is_empty():
		return ""

	return "[turno dos inimigos]\n" + "\n".join(eventos)

func _inimigo_ataca(inimigo: Node) -> String:
	var dano = _dano_inimigo(inimigo)
	var resposta = player.receber_dano_externo(dano)
	return "[inimigo] " + _nome_inimigo(inimigo) + " atacou. " + resposta

func _dano_inimigo(inimigo: Node) -> int:
	if inimigo.get_script() == preload("res://chefe_floresta.gd"):
		return 2
	if inimigo.get_script() == preload("res://chefe_caverna.gd"):
		return 2
	if inimigo.has_method("eh_boss_saida") and inimigo.eh_boss_saida():
		return 2
	return 1

func _nome_inimigo(inimigo: Node) -> String:
	if inimigo.get_script() == preload("res://inimigo_escudo.gd"):
		return "Guardiao do Bosque"
	if inimigo.get_script() == preload("res://inimigo_elemental.gd"):
		return "Eco Elemental"
	if inimigo.get_script() == preload("res://chefe_floresta.gd"):
		return "Guardiao de Runas"
	if inimigo.get_script() == preload("res://chefe_caverna.gd"):
		return "Oraculo Bifurcado"
	if inimigo.get_script() == preload("res://elo.gd"):
		return "Elo"
	if inimigo.get_script() == preload("res://ouroboros.gd"):
		return "Ouroboros"
	if inimigo.get_script() == preload("res://sentinela.gd"):
		return "Sentinela Gemea" if inimigo.exige_parametro else "Sentinela Runica"
	if inimigo.get_script() == preload("res://arquimago.gd"):
		return "Arquimago da Corrupcao"
	if inimigo.has_method("eh_boss_saida") and inimigo.eh_boss_saida():
		return "Guardiao da Saida"
	return "Sentinela da Floresta"

func _mover_inimigo(pos_atual: Vector2i, nova_pos: Vector2i, inimigo: Node):
	inimigos.erase(pos_atual)
	inimigos[nova_pos] = inimigo
	inimigo.grid_pos = nova_pos

	var destino = Vector2(nova_pos) * TAMANHO_CELULA + Vector2(TAMANHO_CELULA / 2, TAMANHO_CELULA / 2)
	var tween = inimigo.create_tween()
	tween.tween_property(inimigo, "position", destino, 0.16)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

func _proximo_passo(origem: Vector2i, alvo: Vector2i, inimigo: Node = null) -> Vector2i:
	var fila: Array = [origem]
	var veio_de: Dictionary = {}
	veio_de[origem] = origem

	var indice = 0
	while indice < fila.size():
		var atual = fila[indice]
		indice += 1

		if atual == alvo:
			break

		for passo in PASSOS:
			var proxima = atual + passo
			if veio_de.has(proxima):
				continue
			if not _pode_visitar(proxima, alvo, inimigo):
				continue

			veio_de[proxima] = atual
			fila.append(proxima)

	if not veio_de.has(alvo):
		return _melhor_passo_simples(origem, alvo, inimigo)

	var passo_final = alvo
	while veio_de[passo_final] != origem:
		passo_final = veio_de[passo_final]

	return passo_final

func _melhor_passo_simples(origem: Vector2i, alvo: Vector2i, inimigo: Node = null) -> Vector2i:
	var melhor = origem
	var melhor_distancia = _distancia(origem, alvo)

	for passo in PASSOS:
		var candidato = origem + passo
		if not _pode_visitar(candidato, alvo, inimigo):
			continue

		var distancia_candidato = _distancia(candidato, alvo)
		if distancia_candidato < melhor_distancia:
			melhor = candidato
			melhor_distancia = distancia_candidato

	return melhor

func _pode_visitar(pos: Vector2i, alvo: Vector2i, inimigo: Node = null) -> bool:
	if inimigo and inimigo.has_method("pode_ocupar") and not inimigo.pode_ocupar(pos):
		return false
	if pos == alvo:
		return true
	if mapa and mapa.has_method("posicao_valida") and not mapa.posicao_valida(pos):
		return false
	if mapa and mapa.eh_parede(pos):
		return false
	if mapa and pos == mapa.saida_pos:
		return false
	if inimigos.has(pos):
		return false
	if player and pos == player.grid_pos:
		return false
	return true

func _ataque_bloqueado_por_area(inimigo: Node) -> bool:
	if player == null:
		return false
	if not inimigo.has_method("pode_ser_atacado_por"):
		return false
	return not inimigo.pode_ser_atacado_por(player.grid_pos)

func _distancia(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

extends Node2D

const InimigoCena = preload("res://inimigo.tscn")
const InimigoEscudoCena = preload("res://inimigo_escudo.tscn")
const ChefeFlorestaCena = preload("res://chefe_floresta.tscn")

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

func chefe_vivo() -> bool:
	for pos in inimigos:
		var i = inimigos[pos]
		if i.get_script() == preload("res://chefe_floresta.gd") and i.vivo:
			return true
	return false

func atacar_posicao(pos: Vector2i, dano: int = 1, usando_variavel: bool = false, nome_variavel: String = "") -> String:
	if pos in inimigos:
		var inimigo = inimigos[pos]
		if not inimigo.vivo:
			inimigos.erase(pos)
			return "Nenhum inimigo aqui."
		
		var resultado = ""
		
		if inimigo.get_script() == preload("res://chefe_floresta.gd"):
			if not usando_variavel:
				resultado = "Suas magias normais nao tem efeito no Guardiao de Runas.\nUse atacar_com(variavel, 'direcao') com o nome certo."
			else:
				resultado = inimigo.receber_dano(dano, nome_variavel)
		elif inimigo.get_script() == preload("res://inimigo_escudo.gd"):
			resultado = inimigo.receber_dano(dano, usando_variavel)
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

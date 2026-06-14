extends Node2D

const InimigoCena = preload("res://inimigo.tscn")
const InimigoEscudoCena = preload("res://inimigo_escudo.tscn")

var inimigos: Dictionary = {}
var mapa: Node = null

func spawnar_inimigo(pos: Vector2i):
	if pos in inimigos:
		return
	if mapa and mapa.eh_parede(pos):
		return
	
	var inimigo = InimigoCena.instantiate()
	add_child(inimigo)
	inimigo.inicializar(pos)
	inimigos[pos] = inimigo

func spawnar_inimigo_escudo(pos: Vector2i):
	if pos in inimigos:
		return
	if mapa and mapa.eh_parede(pos):
		return
	
	var inimigo = InimigoEscudoCena.instantiate()
	add_child(inimigo)
	inimigo.inicializar(pos)
	inimigos[pos] = inimigo
	
	print("Filho de:", inimigo.get_parent().name)

func atacar_posicao(pos: Vector2i, dano: int = 1, usando_variavel: bool = false) -> String:
	if pos in inimigos:
		var inimigo = inimigos[pos]
		if not inimigo.vivo:
			inimigos.erase(pos)
			return "Nenhum inimigo aqui."
		
		var resultado = ""
		
		# Verifica se é inimigo com escudo
		if inimigo.has_method("receber_dano") and inimigo.get_script() == preload("res://inimigo_escudo.gd"):
			resultado = inimigo.receber_dano(dano, usando_variavel)
		else:
			resultado = inimigo.receber_dano(dano)
		
		if not inimigo.vivo:
			inimigos.erase(pos)
		
		return resultado
	
	return "Nenhum inimigo nessa direção."

func tem_inimigo(pos: Vector2i) -> bool:
	return pos in inimigos and inimigos[pos].vivo

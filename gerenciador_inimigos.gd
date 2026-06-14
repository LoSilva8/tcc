extends Node2D

const InimigoCena = preload("res://inimigo.tscn")

var inimigos: Dictionary = {}
var mapa: Node = null  # referência ao mapa, definida pelo Main

func spawnar_inimigo(pos: Vector2i):
	if pos in inimigos:
		return
	
	# Não spawna em cima de parede
	if mapa and mapa.eh_parede(pos):
		return
	
	var inimigo = InimigoCena.instantiate()
	add_child(inimigo)
	inimigo.inicializar(pos)
	inimigos[pos] = inimigo

func atacar_posicao(pos: Vector2i) -> String:
	if pos in inimigos:
		var inimigo = inimigos[pos]
		if not inimigo.vivo:
			inimigos.erase(pos)
			return "Nenhum inimigo aqui."
		
		var resultado = inimigo.receber_dano(1)
		if not inimigo.vivo:
			inimigos.erase(pos)
		return resultado
	
	return "Nenhum inimigo nessa direção."

func tem_inimigo(pos: Vector2i) -> bool:
	return pos in inimigos and inimigos[pos].vivo

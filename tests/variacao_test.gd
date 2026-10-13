extends SceneTree

# Sorteio nas salas de layout fixo (RF008 / RF036): na Floresta as criaturas mudam
# de lugar; nas galerias das Cavernas mudam o formato, a saida e os inimigos.

var falhas = 0
var jogo: Node

func _initialize():
	call_deferred("_testar")

func verificar(condicao: bool, descricao: String):
	if not condicao:
		falhas += 1
		push_error(descricao)

func _testar():
	jogo = load("res://main.tscn").instantiate()
	root.add_child(jogo)
	jogo.ia.habilitado = false
	jogo.interpretador.atraso_entre_acoes = 0.0
	await process_frame
	await process_frame
	jogo.menu.fechar()
	jogo.debug_console._executar("tutorial_skip")
	await create_timer(0.3).timeout

	await _testar_floresta()
	await _testar_galerias()
	await _testar_sem_sorteio()

	print("Variacao: ", falhas, " falhas.")
	jogo.queue_free()
	await process_frame
	quit(1 if falhas else 0)

func _distancias() -> Dictionary:
	return jogo.mapa._distancias(jogo.mapa.inicio_pos, jogo.mapa.posicao_valida)

func _contar(script_path: String) -> Array:
	var achados: Array = []
	for pos in jogo.gerenciador_inimigos.inimigos:
		if jogo.gerenciador_inimigos.inimigos[pos].get_script() == load(script_path):
			achados.append(pos)
	return achados

func _testar_floresta():
	var mapa = jogo.mapa
	var proibidas = jogo._vizinhas(mapa.BAU_POS) + jogo._vizinhas(mapa.PORTA_POS)
	var arranjos = {}
	for visita in range(10):
		await jogo._iniciar_sala(jogo.SALA_FLORESTA)
		var normais = _contar("res://inimigo.gd")
		var escudos = _contar("res://inimigo_escudo.gd")
		var criaturas = normais + escudos
		verificar(normais.size() == 3 and escudos.size() == 2, "Floresta sempre tem 3 criaturas comuns e 2 de escudo.")
		verificar(_contar("res://boss_saida.gd") == [Vector2i(10, 7)], "O Guardiao da Saida continua na arena.")
		var dist = _distancias()
		for pos in criaturas:
			verificar(dist.get(pos, 0) >= 4, "Criatura a pelo menos 4 passos do inicio: " + str(pos))
			verificar(not pos in proibidas, "Criatura nao fica ao lado do bau nem da porta: " + str(pos))
		criaturas.sort()
		arranjos[str(criaturas)] = true
	verificar(arranjos.size() >= 3, "As criaturas da Floresta mudam de lugar a cada visita: " + str(arranjos.size()))

func _testar_galerias():
	var mapa = jogo.mapa
	for sala in [6, 7]:
		var saidas = {}
		var formatos = {}
		for visita in range(15):
			await jogo._iniciar_sala(sala)
			var dist = _distancias()
			verificar(dist.has(mapa.saida_pos), "Galeria " + str(sala) + ": a saida sorteada e alcancavel.")
			verificar(dist.get(mapa.saida_pos, 0) >= 3, "Galeria " + str(sala) + ": a saida fica longe do inicio.")
			var elementais = _contar("res://inimigo_elemental.gd")
			var escudos = _contar("res://inimigo_escudo.gd")
			verificar(elementais.size() == 2 and escudos.size() == 1, "Galeria " + str(sala) + ": 2 Ecos e 1 inimigo de escudo.")
			for pos in elementais + escudos:
				verificar(pos != mapa.saida_pos and dist.get(pos, 0) >= 3, "Inimigo fora da saida e longe do inicio: " + str(pos))
			saidas[mapa.saida_pos] = true
			formatos["".join(mapa.layout_atual).replace("E", ".")] = true
		verificar(saidas.size() >= 3, "Galeria " + str(sala) + ": a saida muda de lugar (RF036): " + str(saidas.size()))
		verificar(formatos.size() >= 2, "Galeria " + str(sala) + ": o formato muda entre visitas.")

func _testar_sem_sorteio():
	var mapa = jogo.mapa
	mapa.variar_salas = false
	await jogo._iniciar_sala(jogo.SALA_FLORESTA)
	var criaturas = _contar("res://inimigo.gd") + _contar("res://inimigo_escudo.gd")
	criaturas.sort()
	verificar(criaturas == [Vector2i(1, 6), Vector2i(4, 6), Vector2i(6, 1), Vector2i(6, 5), Vector2i(7, 3)], "Sem sorteio, a Floresta usa as posicoes fixas.")
	await jogo._iniciar_sala(6)
	verificar(mapa.layout_atual == mapa.layouts[6] and mapa.saida_pos == Vector2i(4, 3), "Sem sorteio, a galeria 6 usa o layout fixo.")
	mapa.variar_salas = true

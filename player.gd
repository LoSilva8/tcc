extends CharacterBody2D

const TAMANHO_CELULA = 64

var grid_pos: Vector2i = Vector2i(1, 1)
var mapa: Node = null
var gerenciador_inimigos: Node = null

# HP do jogador
var hp: int = 10
var hp_max: int = 10
var vivo: bool = true
func _mover(direcao: String) -> String:
	var nova_pos = grid_pos
	
	match direcao:
		"direita": nova_pos.x += 1
		"esquerda": nova_pos.x -= 1
		"cima": nova_pos.y -= 1
		"baixo": nova_pos.y += 1
		_: return "Direção inválida! Use: direita, esquerda, cima ou baixo"
	
	if mapa and mapa.eh_parede(nova_pos):
		return "Bloqueado! Há uma parede nessa direção."
	
	if gerenciador_inimigos and gerenciador_inimigos.tem_inimigo(nova_pos):
		return _receber_dano(1, "Você colidiu com um inimigo!")
	
	grid_pos = nova_pos
	_sincronizar_posicao()
	
	# Checa se chegou na saída
	if mapa and mapa.checar_saida(grid_pos):
		emit_signal("chegou_na_saida")
		return "🚪 Você encontrou a saída!"
	
	return "Moveu para " + direcao + "! Posição: " + str(grid_pos)
# Sinal emitido quando o jogador morre
signal jogador_morreu
signal hp_alterado(hp_atual, hp_max)
signal chegou_na_saida

func _ready():
	_sincronizar_posicao()

func executar_comando(comando: String) -> String:
	if not vivo:
		return "Você está derrotado! Digite reiniciar() para tentar novamente."
	
	comando = comando.strip_edges()
	
	# Detecta reiniciar()
	if comando == "reiniciar()":
		return "Use o botão de reinício ou aguarde..."
	
	# Detecta mover()
	var regex_mover = RegEx.new()
	regex_mover.compile("mover\\(['\"]?(\\w+)['\"]?\\)")
	var resultado_mover = regex_mover.search(comando)
	if resultado_mover:
		return _mover(resultado_mover.get_string(1))
	
	# Detecta atacar()
	var regex_atacar = RegEx.new()
	regex_atacar.compile("atacar\\(['\"]?(\\w+)['\"]?\\)")
	var resultado_atacar = regex_atacar.search(comando)
	if resultado_atacar:
		return _atacar(resultado_atacar.get_string(1))
	
	return "Comando não reconhecido. Tente: mover('direita') ou atacar('direita')"

func _atacar(direcao: String) -> String:
	var alvo = grid_pos
	
	match direcao:
		"direita": alvo.x += 1
		"esquerda": alvo.x -= 1
		"cima": alvo.y -= 1
		"baixo": alvo.y += 1
		_: return "Direção inválida!"
	
	if gerenciador_inimigos:
		return gerenciador_inimigos.atacar_posicao(alvo)
	
	return "Erro: gerenciador não encontrado."

func receber_dano_externo(dano: int) -> String:
	return _receber_dano(dano, "Um inimigo te atacou!")

func _receber_dano(dano: int, motivo: String) -> String:
	hp -= dano
	hp = max(hp, 0)
	emit_signal("hp_alterado", hp, hp_max)
	
	if hp <= 0:
		vivo = false
		emit_signal("jogador_morreu")
		return motivo + " HP: 0/" + str(hp_max) + "\n💀 Você foi derrotado! A run terminou."
	
	return motivo + " HP: " + str(hp) + "/" + str(hp_max)

func resetar():
	hp = hp_max
	vivo = true
	grid_pos = Vector2i(1, 1)
	_sincronizar_posicao()
	emit_signal("hp_alterado", hp, hp_max)

func _sincronizar_posicao():
	var destino = Vector2(grid_pos) * TAMANHO_CELULA + Vector2(TAMANHO_CELULA / 2, TAMANHO_CELULA / 2)
	var tween = create_tween()
	tween.tween_property(self, "position", destino, 0.15)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

extends Node2D

const TAMANHO_CELULA = 64

var grid_pos: Vector2i = Vector2i(0, 0)
var vivo: bool = true

var partes = ["braco_esquerdo", "braco_direito", "nucleo"]
var variavel_exigida = {
	"braco_esquerdo": "fogo",
	"braco_direito": "gelo",
	"nucleo": "arcano"
}
var hp_partes = {"braco_esquerdo": 4, "braco_direito": 4, "nucleo": 6}
var hp_max_partes = {"braco_esquerdo": 4, "braco_direito": 4, "nucleo": 6}
var parte_atual_index = 0

signal chefe_derrotado

@onready var hp_label = $HPLabel
@onready var parte_label = $ParteLabel
@onready var braco_esquerdo_rect = $BracoEsquerdoRect
@onready var braco_direito_rect = $BracoDireitoRect
@onready var nucleo_rect = $NucleoRect

func inicializar(pos: Vector2i):
	grid_pos = pos
	call_deferred("_aplicar_posicao")

func _aplicar_posicao():
	position = Vector2(
		grid_pos.x * TAMANHO_CELULA + TAMANHO_CELULA / 2,
		grid_pos.y * TAMANHO_CELULA + TAMANHO_CELULA / 2
	)
	_atualizar_labels()

func parte_atual() -> String:
	return partes[parte_atual_index]

func receber_dano(dano: int, nome_variavel: String) -> String:
	if not vivo:
		return "O guardiao ja foi derrotado."
	
	var parte = parte_atual()
	var exigida = variavel_exigida[parte]
	
	if nome_variavel != exigida:
		return "O " + _nome_legivel(parte) + " nao reage a essa magia.\nEle exige uma variavel chamada '" + exigida + "'.\nTente: " + exigida + " = valor"
	
	hp_partes[parte] -= dano
	hp_partes[parte] = max(hp_partes[parte], 0)
	
	if hp_partes[parte] <= 0:
		var texto = _nome_legivel(parte).capitalize() + " destruido!"
		parte_atual_index += 1
		
		if parte_atual_index >= partes.size():
			vivo = false
			_atualizar_labels()
			_morrer()
			return texto + "\nGUARDIAO DE RUNAS DERROTADO!"
		else:
			_atualizar_labels()
			var proxima = parte_atual()
			return texto + "\nAgora ataque o " + _nome_legivel(proxima) + " com a variavel '" + variavel_exigida[proxima] + "'."
	
	_atualizar_labels()
	return _nome_legivel(parte).capitalize() + " atingido! HP: " + str(hp_partes[parte]) + "/" + str(hp_max_partes[parte])

func _nome_legivel(parte: String) -> String:
	match parte:
		"braco_esquerdo": return "braco esquerdo"
		"braco_direito": return "braco direito"
		"nucleo": return "nucleo"
	return parte

func _atualizar_labels():
	if not vivo:
		hp_label.text = ""
		parte_label.text = "DERROTADO"
		return
	
	var parte = parte_atual()
	hp_label.text = "HP " + str(hp_partes[parte]) + "/" + str(hp_max_partes[parte])
	parte_label.text = _nome_legivel(parte).capitalize() + " (" + variavel_exigida[parte] + ")"
	
	_atualizar_visual_partes()

func _atualizar_visual_partes():
	# Escurece partes destruídas, ilumina a parte ativa
	var cor_ativa = Color(1.0, 0.85, 0.2, 1)
	var cor_inativa = Color(0.85, 0.65, 0.13, 0.5)
	var cor_destruida = Color(0.2, 0.2, 0.2, 0.3)
	
	braco_esquerdo_rect.color = cor_destruida if hp_partes["braco_esquerdo"] <= 0 else (cor_ativa if parte_atual() == "braco_esquerdo" else cor_inativa)
	braco_direito_rect.color = cor_destruida if hp_partes["braco_direito"] <= 0 else (cor_ativa if parte_atual() == "braco_direito" else cor_inativa)
	nucleo_rect.color = cor_destruida if hp_partes["nucleo"] <= 0 else (cor_ativa if parte_atual() == "nucleo" else cor_inativa)
func _morrer():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
	emit_signal("chefe_derrotado")

extends RefCounted

# Progresso permanente do jogador (RF019, RNF005, US01): o que sobrevive ao fim
# da run e a fechar o jogo. XP e nivel ficam de fora, pois zeram a cada run (RF033).

const CAMINHO_PADRAO = "user://progresso.cfg"
const SECAO = "progresso"

var caminho = CAMINHO_PADRAO
# So grava depois que uma partida comeca pelo menu. Os testes instanciam o jogo
# direto, sem passar pelo menu, e assim nunca sobrescrevem o progresso real.
var ativo = false

var tutorial_concluido = false
var bioma_liberado = 0  # indice em main.BIOMAS: 0 Floresta, 1 Cavernas, 2 Labirinto, 3 Torre
var grimorio_desbloqueado = false
var lacos_desbloqueados = false
var funcoes_desbloqueadas = false
var jogo_concluido = false

func tem_progresso() -> bool:
	return tutorial_concluido

func zerar():
	tutorial_concluido = false
	bioma_liberado = 0
	grimorio_desbloqueado = false
	lacos_desbloqueados = false
	funcoes_desbloqueadas = false
	jogo_concluido = false

# Arquivo ausente ou corrompido vale como jogo novo.
func carregar() -> bool:
	zerar()
	var config = ConfigFile.new()
	if config.load(caminho) != OK:
		return false
	tutorial_concluido = _ler(config, "tutorial_concluido", false)
	bioma_liberado = maxi(_ler(config, "bioma_liberado", 0), 0)
	grimorio_desbloqueado = _ler(config, "grimorio_desbloqueado", false)
	lacos_desbloqueados = _ler(config, "lacos_desbloqueados", false)
	funcoes_desbloqueadas = _ler(config, "funcoes_desbloqueadas", false)
	jogo_concluido = _ler(config, "jogo_concluido", false)
	return true

func salvar() -> bool:
	if not ativo:
		return false
	var config = ConfigFile.new()
	config.set_value(SECAO, "tutorial_concluido", tutorial_concluido)
	config.set_value(SECAO, "bioma_liberado", bioma_liberado)
	config.set_value(SECAO, "grimorio_desbloqueado", grimorio_desbloqueado)
	config.set_value(SECAO, "lacos_desbloqueados", lacos_desbloqueados)
	config.set_value(SECAO, "funcoes_desbloqueadas", funcoes_desbloqueadas)
	config.set_value(SECAO, "jogo_concluido", jogo_concluido)
	return config.save(caminho) == OK

func _ler(config: ConfigFile, chave: String, padrao):
	var valor = config.get_value(SECAO, chave, padrao)
	return valor if typeof(valor) == typeof(padrao) else padrao

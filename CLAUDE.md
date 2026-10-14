# PyAdventure — TCC Eng. de Software (PUCPR)
Roguelike educacional em Godot 4 para ensinar Python a iniciantes.
Equipe: Lorenzo Silva Bonet, Júlio César Ramalho Batista, João Pedro Santos. Orientadores: Giulio Bondin, Lisiane Reips.

## Documento do TCC (requisitos, biomas, RAs, validação MEEGA+)
Texto completo em `docs/TCC.md`. Ler a seção relevante antes de implementar ou alterar uma mecânica:
- Requisitos RF001–RF052 e RNF001–RNF005: Tabela 9 (seção 3.3). Histórias de usuário: seção 3.2.
- Biomas, cenário e critério de conclusão: Tabela 11 (seção 3.4.3). Resultados de aprendizagem RA01–RA05: Tabela 12.
- Validação (pré-teste, pós-teste, MEEGA+): capítulo 4. Cronograma e riscos: capítulo 5.

O arquivo não é importado com `@` de propósito: tem ~25k tokens e seria carregado em toda sessão.
O `docs/TCC.md` não vai para o git (o repositório é público e o texto não pode vazar antes da entrega). Para gerar ou atualizar a partir do docx: `python docs/docx2md.py <TCC.docx> docs/TCC.md` (não precisa de pandoc).

## Rodar e testar
- Godot 4.6. Nesta máquina: `C:\Users\Desktop\Desktop\Godot_v4.6.1-stable_win64.exe`.
- Cada arquivo em `tests/` é um script `SceneTree` independente; sai com código 1 se algo falhar:
  `<godot.exe> --headless --path . -s tests/progressao_test.gd`
- Rodar todas as suítes antes de commitar. Testes desligam a IA (`jogo.ia.habilitado = false`) e o atraso entre ações.
- Console de debug no jogo: F1 (`ajuda`, `sala <n>`, `spawn <tipo> <x> <y>`, `tutorial_skip`, `hp`, `matar_tudo`, `var`, `pos`).

## Arquitetura
- `main.gd`: orquestra as salas (`_iniciar_sala`), HUD, terminal de uma linha, grimório (CodeEdit multi-linha, Ctrl+Enter executa), livro de magias, desbloqueios por bioma e `_iniciar_run(bioma)` (-1 = pelo tutorial).
- `menu_principal.gd`: tela inicial com Novo jogo, Continuar a partir de um bioma liberado e o campo do código do participante (validação). `reiniciar()` volta para ela.
- `metricas.gd`: métricas internas da validação (seção 4.4 e Tabela 13 do TCC). Por sessão, dois CSV em `user://metricas` (separador `;`, BOM para o Excel): `<codigo>_<data>_eventos.csv` (cada programa com resultado ok/erro_sintaxe/erro_execucao/bloqueio/interrompido, ações que falharam, desafios, mortes, dicas, salas e biomas) e `_resumo.csv` (uma linha por sala + TOTAL). Só grava após começar pelo menu; testes apontam `metricas.pasta` para uma pasta de teste. Console: `metricas`.
- Eficiência do código (US04, em `main.gd`): ao concluir cada sala, `_relatar_eficiencia` dá até 3 estrelas (concluir; sem erros de Python; sem ações desperdiçadas) e mostra programas, turnos e ações por programa; o total da run aparece no fim do jogo. Um painel (`estrelas_panel`) mostra as estrelas por 5 s, porque o relatório no terminal rola com o anúncio da sala seguinte. Salas sem nenhum programa não são avaliadas. Estrelas também vão para as métricas (evento `eficiencia`, coluna `estrelas`).
- `progresso.gd`: progresso permanente em `user://progresso.cfg` (tutorial feito, bioma liberado, grimório, laços). Só grava depois que a partida começa pelo menu, então os testes nunca tocam no save real. XP e nível não são salvos (zeram a cada run).
- `interpretador.gd`: subconjunto real de Python escrito em GDScript. Texto → tokens (com INDENT/DEDENT) → árvore → execução como corrotina. Cada ação (mover, atacar, fireball) gasta 1 turno. Funções do jogador (`def`, parâmetros, `return`, escopo local) podem agir, por isso rodam antes de avaliar a expressão (`_resolver`). `dentro_de_laco_sem_fim()` diz se a ação vem de um `while` cuja condição nunca muda (`while True`, `while 1 < 2`) e sem `break`/`return` no corpo. O player lê variáveis por `tem_variavel`/`ler_variavel` para enxergar as locais. `funcoes_liberadas`/`lacos_liberados` vêm do main (`funcoes_desbloqueadas` fica false até o jogador entrar na Torre).
- `player.gd`: movimento em grid, ataque, fireball (custo 2 + poder, recupera 1 MP por rodada), XP, nível e upgrades.
- `mapa.gd`: layout das salas por índice, geração procedural, desenho por bioma. Sorteio nas salas fixas (RF008/RF036, `variar_salas`): na Floresta as 5 criaturas mudam de lugar (longe do início, fora do baú/porta; arena e Guardião fixos); nas galerias 6 e 7 o formato, a saída e os inimigos são sorteados; Encruzilhada (5) e Oráculo (8) ficam fixos. **Testes que dependem de posições fixas usam `jogo.mapa.variar_salas = false`.**
- `gerenciador_inimigos.gd`: spawn e turno dos inimigos (normal, escudo, elemental, chefes, Elo, Ouroboros, Sentinela). O Guardião de Runas (`chefe_floresta.gd`, chefe da Floresta, em `mapa.GUARDIAO_POS`) fica preso na arena e cada runa lê as variáveis do mago (Tabela 11 e RA02, tipos): Braço de Pedra = a variável da fireball precisa valer o número da runa, que muda a cada golpe (reatribuir); Braço de Cristal = `feitico` precisa guardar a palavra como texto; Núcleo = as duas no mesmo golpe. Só apanha de dentro da arena, esmaga quem fica ao lado e as raízes ferem na arena a cada 3 turnos (com aviso). Cada bioma tem criaturas que so caem com o conceito novo: Elos so com golpes dentro de laco, Ouroboros so dentro de while (e nao de um while sem fim), Sentinelas so com golpes de dentro de uma funcao, Sentinelas Gemeas so de funcao com parametros. O Selo do Retorno (`abrir_selo()`) chama `poder_da_runa(runa)` do aluno via `interpretador.testar_funcao` e confere o valor devolvido. O Arquimago (chefe final) salta entre pedestais e so sente golpes de funcao + laco + if (`dentro_de_funcao`, `dentro_de_laco`, `dentro_de_if`), o criterio da Tabela 11, e tambem recusa while sem fim; vence-lo conclui o jogo (`_concluir_torre`, `progresso.jogo_concluido`).
- Desafios: `tutorial.gd` (Floresta), `desafio_bau_porta.gd` (baú com variável, porta com if), `desafio_comporta.gd` (if/elif/else nas Cavernas).
- Feedback de erro: `feedback_ia.gd` (Groq, modelo `openai/gpt-oss-20b`; chave em `GROQ_API_KEY` ou `user://feedback_ia.cfg`) reage a erros de Python; `mentor_ia.gd` existe mas não é usado. **Feitos por um colega: não alterar nem remover sem confirmar com o Lorenzo** (a constante `REGRAS` recebeu frases da Torre em commits anteriores).
- Dicas progressivas: `dicas.gd` guarda dicas escritas à mão por tópico (situação da sala, ex.: Floresta baú → porta → Guardião), em 3 degraus (conceito, o que fazer, exemplo). `dica()` no terminal sobe um degrau; a primeira falha de regra de um tópico (Sentinela, Elo, Selo...) mostra o 1º degrau sozinho; a cada 3 programas com problema o jogo lembra de `dica()`. Funciona sem internet. Substitui a ideia de reduzir dicas da RF018. Métricas: eventos `dica_pedida`/`dica_automatica`, coluna `dicas_pedidas`.
- Biomas: Floresta dos Primeiros Passos → Cavernas Condicionais → Labirinto dos Laços → Torre das Funções.

| Bioma | Salas | Conceitos | Status |
|---|---|---|---|
| Floresta dos Primeiros Passos | 1 (0 = tutorial; 2–4 são salas antigas, só via debug) | sintaxe, variáveis, tipos; chefe Guardião de Runas | pronto |
| Cavernas Condicionais | 5–8 | if/elif/else; chefe Oráculo Bifurcado | pronto |
| Labirinto dos Laços | 9–12 | for/while, listas; chefe Ouroboros | pronto |
| Torre das Funções | 13 (Salão das Sentinelas), 14 (Câmara dos Parâmetros), 15 (Selo do Retorno), 16 (Arquimago) | def, parâmetros, retorno; chefe Arquimago da Corrupção | pronto |

## Convenções
- Código, identificadores, comentários e textos do jogo em português, em geral sem acento.
- Commits no estilo Conventional Commits em português (`feat:`, `fix:`), sem acento.
- Cada bioma ou mecânica nova vem com sua suíte em `tests/<nome>_test.gd`.
- Ao implementar um requisito do TCC, citar o ID no comentário (ex.: `RF019`).

## Estado atual (2026-10-14)
Pronto: Floresta com tutorial, Cavernas, Labirinto, grimório multi-linha, interpretador com blocos, fireball/mana, XP e nível, feedback por IA, syntax highlighting, progressão por bioma (grimório liberado a partir das Cavernas, laços a partir do Labirinto, funções na Torre), menu principal, progresso salvo em disco, a Torre das Funções completa com final de jogo, as métricas internas para a validação, a eficiência do código em estrelas (US04) e o executável Windows (`build/PyAdventure.exe`, preset "Windows Desktop") , as dicas progressivas com `dica()`, o sorteio de inimigos e saídas nas salas fixas, o Guardião de Runas como chefe da Floresta (substituiu o antigo Guardião da Saída, que caía com qualquer golpe) e os chefes Ouroboros/Arquimago recusando `while True` sem `break`. As 17 suítes de teste passam (também rodam no Linux com o Godot 4.6.1).

Falta, comparando com o documento do TCC:
- RF023 diz `atacar_com(Elemento, 'direção')`, mas o código trocou por `fireball(poder, 'direcao')`. Atualizar o documento ou o código.
- RF036 (saída gerada aleatoriamente): vale nas galerias das Cavernas e nas salas do Labirinto, mas na Floresta a saída fica fixa dentro da arena do Guardião (exceção de design). O grupo deve registrar essa exceção no documento.
- RF018 e Tabela 11 ("dicas reduzidas", "ausência de dicas") descrevem dicas que diminuem; o jogo agora tem dicas progressivas sob demanda. O grupo deve reescrever esses trechos no documento.
- Tabela 9: RF038–RF049 repetem RF026–RF037 (só RF041 muda, "escudo arcano"). RF050/RF051 pedem chefes com "escudos elementais"; no jogo cada chefe cai pelo conceito do bioma. RF021/RF024/RF026 dizem que vida, dano e mana sobem com o nível; no jogo o jogador escolhe um upgrade (`escolher(n)`). O grupo deve reescrever.
- RA01 cita `move_right()`/`open_door()` (no jogo: `mover('direita')`, `abrir_porta()`). Tabela 11: a Floresta cita "entrada e saída" (só há `print`, sem `input()`) e a Torre cita dicionários (o interpretador não tem `{}`); tirar do documento ou implementar.
- Seção 1.3 diz que o capítulo 4 traz cronograma e riscos (estão no 5). Tabela 14 termina em 15/06/2026: falta o cronograma do 2º semestre.
- RNF003: só existe o preset de exportação "Windows Desktop" (faltam Linux e macOS).
- Preparar os instrumentos da validação do capítulo 4 (pré-teste, pós-teste, MEEGA+, ficha de observação): fica com o resto do grupo. A seção 4.4 não cita funções entre os conteúdos dos testes, embora a Torre as ensine.

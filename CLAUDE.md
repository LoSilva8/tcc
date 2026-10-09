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
- `progresso.gd`: progresso permanente em `user://progresso.cfg` (tutorial feito, bioma liberado, grimório, laços). Só grava depois que a partida começa pelo menu, então os testes nunca tocam no save real. XP e nível não são salvos (zeram a cada run).
- `interpretador.gd`: subconjunto real de Python escrito em GDScript. Texto → tokens (com INDENT/DEDENT) → árvore → execução como corrotina. Cada ação (mover, atacar, fireball) gasta 1 turno. Funções do jogador (`def`, parâmetros, `return`, escopo local) podem agir, por isso rodam antes de avaliar a expressão (`_resolver`). O player lê variáveis por `tem_variavel`/`ler_variavel` para enxergar as locais. `funcoes_liberadas`/`lacos_liberados` vêm do main (`funcoes_desbloqueadas` fica false até o jogador entrar na Torre).
- `player.gd`: movimento em grid, ataque, fireball (custo 2 + poder, recupera 1 MP por rodada), XP, nível e upgrades.
- `mapa.gd`: layout das salas por índice, geração procedural, desenho por bioma.
- `gerenciador_inimigos.gd`: spawn e turno dos inimigos (normal, escudo, elemental, chefes, Elo, Ouroboros, Sentinela). Cada bioma tem criaturas que so caem com o conceito novo: Elos so com golpes dentro de laco, Ouroboros so dentro de while, Sentinelas so com golpes de dentro de uma funcao, Sentinelas Gemeas so de funcao com parametros. O Selo do Retorno (`abrir_selo()`) chama `poder_da_runa(runa)` do aluno via `interpretador.testar_funcao` e confere o valor devolvido. O Arquimago (chefe final) salta entre pedestais e so sente golpes de funcao + laco + if (`dentro_de_funcao`, `dentro_de_laco`, `dentro_de_if`), o criterio da Tabela 11; vence-lo conclui o jogo (`_concluir_torre`, `progresso.jogo_concluido`).
- Desafios: `tutorial.gd` (Floresta), `desafio_bau_porta.gd` (baú com variável, porta com if), `desafio_comporta.gd` (if/elif/else nas Cavernas).
- Feedback de erro: `feedback_ia.gd` (Groq, modelo `openai/gpt-oss-20b`; chave em `GROQ_API_KEY` ou `user://feedback_ia.cfg`) e `mentor_ia.gd` (feedback local, sem rede).
- Biomas: Floresta dos Primeiros Passos → Cavernas Condicionais → Labirinto dos Laços → Torre das Funções.

| Bioma | Salas | Conceitos | Status |
|---|---|---|---|
| Floresta dos Primeiros Passos | 1 (0 = tutorial; 2–4 são salas antigas, só via debug) | sintaxe, variáveis | pronto |
| Cavernas Condicionais | 5–8 | if/elif/else; chefe Oráculo Bifurcado | pronto |
| Labirinto dos Laços | 9–12 | for/while, listas; chefe Ouroboros | pronto |
| Torre das Funções | 13 (Salão das Sentinelas), 14 (Câmara dos Parâmetros), 15 (Selo do Retorno), 16 (Arquimago) | def, parâmetros, retorno; chefe Arquimago da Corrupção | pronto |

## Convenções
- Código, identificadores, comentários e textos do jogo em português, em geral sem acento.
- Commits no estilo Conventional Commits em português (`feat:`, `fix:`), sem acento.
- Cada bioma ou mecânica nova vem com sua suíte em `tests/<nome>_test.gd`.
- Ao implementar um requisito do TCC, citar o ID no comentário (ex.: `RF019`).

## Estado atual (2026-10-09)
Pronto: Floresta com tutorial, Cavernas, Labirinto, grimório multi-linha, interpretador com blocos, fireball/mana, XP e nível, feedback por IA, syntax highlighting, progressão por bioma (grimório liberado a partir das Cavernas, laços a partir do Labirinto, funções na Torre), menu principal, progresso salvo em disco, a Torre das Funções completa com final de jogo e as métricas internas para a validação. As 13 suítes de teste passam.

Falta, comparando com o documento do TCC:
- RF023 diz `atacar_com(Elemento, 'direção')`, mas o código trocou por `fireball(poder, 'direcao')`. Atualizar o documento ou o código.
- Preparar os instrumentos da validação do capítulo 4 (pré-teste, pós-teste, MEEGA+, ficha de observação): fica com o resto do grupo.

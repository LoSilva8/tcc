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
- `menu_principal.gd`: tela inicial com Novo jogo e Continuar a partir de um bioma liberado. `reiniciar()` volta para ela.
- `progresso.gd`: progresso permanente em `user://progresso.cfg` (tutorial feito, bioma liberado, grimório, laços). Só grava depois que a partida começa pelo menu, então os testes nunca tocam no save real. XP e nível não são salvos (zeram a cada run).
- `interpretador.gd`: subconjunto real de Python escrito em GDScript. Texto → tokens (com INDENT/DEDENT) → árvore → execução como corrotina. Cada ação (mover, atacar, fireball) gasta 1 turno. Funções do jogador (`def`, parâmetros, `return`, escopo local) podem agir, por isso rodam antes de avaliar a expressão (`_resolver`). O player lê variáveis por `tem_variavel`/`ler_variavel` para enxergar as locais. `funcoes_liberadas`/`lacos_liberados` vêm do main (`funcoes_desbloqueadas` fica false até existir a Torre).
- `player.gd`: movimento em grid, ataque, fireball (custo 2 + poder, recupera 1 MP por rodada), XP, nível e upgrades.
- `mapa.gd`: layout das salas por índice, geração procedural, desenho por bioma.
- `gerenciador_inimigos.gd`: spawn e turno dos inimigos (normal, escudo, elemental, chefes, Elo, Ouroboros).
- Desafios: `tutorial.gd` (Floresta), `desafio_bau_porta.gd` (baú com variável, porta com if), `desafio_comporta.gd` (if/elif/else nas Cavernas).
- Feedback de erro: `feedback_ia.gd` (Groq, modelo `openai/gpt-oss-20b`; chave em `GROQ_API_KEY` ou `user://feedback_ia.cfg`) e `mentor_ia.gd` (feedback local, sem rede).
- Biomas: Floresta dos Primeiros Passos → Cavernas Condicionais → Labirinto dos Laços → Torre das Funções.

| Bioma | Salas | Conceitos | Status |
|---|---|---|---|
| Floresta dos Primeiros Passos | 1 (0 = tutorial; 2–4 são salas antigas, só via debug) | sintaxe, variáveis | pronto |
| Cavernas Condicionais | 5–8 | if/elif/else; chefe Oráculo Bifurcado | pronto |
| Labirinto dos Laços | 9–12 | for/while, listas; chefe Ouroboros | pronto |
| Torre das Funções | — | def, parâmetros, retorno; chefe Arquimago da Corrupção | não iniciado |

## Convenções
- Código, identificadores, comentários e textos do jogo em português, em geral sem acento.
- Commits no estilo Conventional Commits em português (`feat:`, `fix:`), sem acento.
- Cada bioma ou mecânica nova vem com sua suíte em `tests/<nome>_test.gd`.
- Ao implementar um requisito do TCC, citar o ID no comentário (ex.: `RF019`).

## Estado atual (2026-10-04)
Pronto: Floresta com tutorial, Cavernas, Labirinto, grimório multi-linha, interpretador com blocos, fireball/mana, XP e nível, feedback por IA, syntax highlighting, progressão por bioma (grimório liberado a partir das Cavernas, laços a partir do Labirinto), menu principal e progresso salvo em disco. As 11 suítes de teste passam.

Falta, comparando com o documento do TCC:
- Torre das Funções e o chefe final Arquimago da Corrupção (RF014, Tabela 11). Etapa 1 pronta: o interpretador já suporta funções (`tests/funcoes_test.gd`). Faltam as salas (etapa 2) e o chefe (etapa 3), que devem ligar `funcoes_desbloqueadas` e salvá-lo no progresso.
- RF023 diz `atacar_com(Elemento, 'direção')`, mas o código trocou por `fireball(poder, 'direcao')`. Atualizar o documento ou o código.
- Preparar a validação do capítulo 4 (pré-teste, pós-teste, questionário MEEGA+, ficha de observação).

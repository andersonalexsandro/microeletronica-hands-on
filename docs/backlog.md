# Backlog — AES Top-Level System (MiniSoC AES)

O backlog é atualizado no início de cada semana. Cada item tem um identificador estável (`Bxx-n`, em que `xx` é a semana prevista), que é o mesmo usado nas mensagens de commit e nas *issues*. Os defeitos reportados pelo verificador parceiro entram como *issues* e são referenciados aqui, na seção [Defeitos e issues](#defeitos-e-issues).

**Replanejado em 04/11/2026** para o cronograma revisado em 27/10/2026: 13 semanas de entrega, encerramento em 29/01/2027, recesso de 21/12/2026 a 03/01/2027 e o Block Guide MiniSoC AES v1.0.0 como especificação funcional. As referências a seções (por exemplo, "seção 6") remetem ao Block Guide.

**Status:** `feito` · `em andamento` · `a fazer` · `bloqueado`

---

## Riscos e bloqueios

| ID | Risco ou bloqueio | Impacto | Ação | Status |
| --- | --- | --- | --- | --- |
| R-1 | Especificação funcional não recebida | Interfaces, mapa de registradores e protocolo indefinidos | Especificação definida: Block Guide MiniSoC AES v1.0.0, o mesmo da trilha DV | fechado (27/10) |
| R-2 | Acesso SSH ao servidor `microeletronica3` recusado (`Permission denied (publickey)`) | O fluxo Synopsys não roda. As semanas 2 a 7 seguem com Verilator e Icarus, mas a síntese (sem. 8), o Formality (sem. 9) e o UPF (sem. 11 a 13) dependem do servidor | Regularizar a chave com o suporte **antes de 11/12** e rodar `make` lá | aberto |
| R-3 | Interfaces de topo e dos modelos do PLL e da memória precisam ser idênticas às do Block Guide | Retrabalho no RTL e no ambiente do verificador se divergirem | Nomes de módulos, arquivos e sinais seguem o Block Guide; a confirmação final é a primeira execução do ambiente DV sobre o RTL v1.0 (sem. 7) | aberto |
| R-4 | Verificador parceiro ainda não definido | Pontos de contato das semanas 3, 7, 10 e 12 | Confirmar a dupla com o instrutor | aberto |
| R-5 | Ambiguidades do Block Guide: 17 pontos em aberto, conferidos com o texto da v1.0.0 (lista em [`reports/semana_02.md`](reports/semana_02.md#dúvidas-sobre-o-block-guide-seções-1-a-3-e-8)) | Microarquitetura (sem. 3), SPI (sem. 5), AES engine (sem. 6) e modos da sem. 10 (CFB, PCBC) | Levar ao ponto de acompanhamento com o instrutor | aberto |
| R-6 | O Block Guide fixa `clk` em 2 GHz e permite `sys_clk` de 2 GHz (divisor /1) | Uma rodada AES por ciclo e o banco de registradores dificilmente fecham timing nessas frequências (sem. 3 e 8) | Confirmar com o instrutor as frequências-alvo da síntese; a microarquitetura prevê dividir a rodada em 2 estágios se for preciso | aberto |

---

## Fase 1 — Kick-off e ambiente (semana 1, concluída)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B01-1 | Repositório com a estrutura sugerida, `.gitignore` e README | Estrutura criada; artefatos e PDK fora do Git | feito |
| B01-2 | Fluxo mínimo com um único comando (lint + simulação), nos dois ambientes | `make` em clone limpo termina com "fluxo minimo OK" | feito (local); servidor pendente (R-2) |
| B01-3 | Exemplo mínimo: S-box + testbench self-checking | 256/256 entradas conferidas; lint sem avisos | feito |
| B01-4 | Modelo de referência do AES em Python | Vetores do FIPS-197 (Ap. B, C.1–C.3) passam | feito |
| B01-5 | Relatório de estudo de AES e SPI | `docs/reports/estudo_aes_spi.md` | feito |
| B01-6 | Backlog inicial | Este documento | feito |
| B01-7 | Relatório da semana 1 e tag `w01-setup` | `docs/reports/semana_01.md` | feito |

## Fase 2 — Desenvolvimento do RTL (semanas 2 a 7)

### Semana 2 — desafio SubBytes e ShiftRows (30/10)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B02-1 | `minisoc_aes_sbox` | 8 → 8 bits, combinacional; 256/256 entradas conferidas com a tabela de referência | feito |
| B02-2 | `minisoc_aes_sub_bytes` | 16 instâncias da S-box; confere com o FIPS-197 Ap. B | feito |
| B02-3 | `minisoc_aes_shift_rows` | Só fiação; confere com o FIPS-197 Ap. B | feito |
| B02-4 | Testbench autoverificável | S-box nas 256 entradas; Ap. B nas rodadas 1 e 10 (e todas as rodadas de B e C.1), executado por `make` | feito |
| B02-5 | Opcional: InvSubBytes e InvShiftRows | `InvSubBytes(SubBytes(x)) = x` e `InvShiftRows(ShiftRows(x)) = x` | feito |
| B02-6 | Leitura das seções 1 a 3 e 8 do Block Guide | Lista de dúvidas em `reports/semana_02.md`, conferida com o texto da v1.0.0 | feito |
| B02-7 | Repositório na organização da seção 10 (`rtl/minisoc_*`) | Prefixo `minisoc_`; `models/` removida | feito |
| B02-8 | Relatório da semana e tag `w02-subbytes-shiftrows` | `docs/reports/semana_02.md` | feito |

### Semana 3 — microarquitetura e transformações de rodada (06/11)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B03-1 | Documento de microarquitetura v1.0 (`docs/architecture/`) | Diagrama interno, AES iterativo (ou alternativa justificada), FSM do `minisoc_aes_top`, CDC por toggle (seção 5.3), sequência de reset (seção 4.2) | feito (`microarquitetura_v1.0.md`) |
| B03-2 | MixColumns e AddRoundKey | Conferem com o FIPS-197 Ap. B | feito |
| B03-3 | InvMixColumns | Confere com o FIPS-197 Ap. C.1 (cifra inversa); InvSubBytes e InvShiftRows já feitos (B02-5) | feito |
| B03-4 | Testes unitários de todas as transformações | Ap. B (cifragem) e Ap. C.1 (cifragem inversa) em `make test` | feito (5425 checagens) |
| B03-5 | Defesa curta e apresentação ao verificador parceiro | Microarquitetura aprovada pelo instrutor | a fazer (parceiro não definido, R-4) |

### Semana 4 — expansão de chave e datapath AES-128 (13/11)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B04-1 | `minisoc_aes_key_exp` | 11 round keys; escolha pré-computada × on-the-fly justificada (área e ordem inversa na decriptação) | a fazer |
| B04-2 | `minisoc_aes_dp` | Cifra e cifra inversa de um bloco, com a interface de controle da microarquitetura (start/done) | a fazer |
| B04-3 | Testbench com os vetores do padrão | Ap. B e C.1 nos dois sentidos; lint sem erros | a fazer |

### Semana 5 — SPI front-end e PLL mock (20/11)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B05-1 | `minisoc_spi` (seção 5) | Mode 0, MSB-first, frame de 40 bits; escrita em uma transação e leitura em duas (NOP 0x3F) | a fazer |
| B05-2 | Travessia `spi_sclk` → `clk` | Evento de frame completo por sincronização de toggle | a fazer |
| B05-3 | Banco de registradores (seção 6) | KEY0–3, IV0–3, COUNTER_HI/LO, NUM_BLOCKS, AES_CONTROL (START write-one-pulse), AES_STATUS, VERSION, SYSTEM_CONTROL, SYSTEM_STATUS | a fazer |
| B05-4 | `minisoc_pll_mock` (seção 4.1) | Enable, PLL_DIV_SEL (/1, /2, /4, /8), locked após atraso pseudoaleatório | a fazer |
| B05-5 | Testbench dirigido | Todos os registradores R/W escritos e lidos via SPI; R não alterados por escrita; PLL travando nos 4 divisores (passos 8 e 9 da seção 9) | a fazer |

### Semana 6 — AES engine e memória compartilhada (27/11)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B06-1 | `minisoc_memory` (seção 7) | 1024 × 32, single-port síncrona, sem reset, ownership por MEM_SEL_AES | a fazer |
| B06-2 | `minisoc_aes_top` (seção 8) | Captura no START; 4 leituras, processamento e escrita in-place por bloco; BUSY, DONE, ERROR, BLOCKS_DONE | a fazer |
| B06-3 | Modos ECB, CBC e CTR | Cifragem e decriptação | a fazer |
| B06-4 | Configuração inválida | NUM_BLOCKS fora de 1..256 ou MODE reservado → ERROR, sem processamento | a fazer |
| B06-5 | Modelo de referência dos modos (Python) e testbench de bloco | 1, 2 e 256 blocos em cada modo, nos dois sentidos | a fazer |

### Semana 7 — integração do top-level e RTL v1.0 (04/12)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B07-1 | `minisoc_top` | Interfaces CLK, RESET, SPI e MEMORY DATA idênticas às da seção 3 | a fazer |
| B07-2 | Sequência de reset (seção 4.2) | Sistema em reset até o clock liberado pelo PLL e os ciclos exigidos | a fazer |
| B07-3 | Teste de ponta a ponta | Os 14 passos do modelo de programação (seção 9) | a fazer |
| B07-4 | Análise de CDC | `spi_sclk` × `clk`, `clk` × `sys_clk`, `mem_clk` × `sys_clk`; nenhuma violação sem justificativa | a fazer |
| B07-5 | Tag `w07-rtl-v1.0` e entrega ao verificador parceiro | Tag comunicada; limitações (PCBC, CFB, OFB) informadas | a fazer |

## Fase 3 — Síntese inicial (semana 8, 11/12)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B08-1 | SDC | `clk`, `sys_clk` (gerado), `spi_sclk` e `mem_clk`; grupos assíncronos; I/O; sincronizadores | a fazer |
| B08-2 | PLL mock e memória como caixas-pretas ou macros | Conforme orientação do instrutor | a fazer |
| B08-3 | Síntese do RTL v1.0 com o PDK, gerando o SVF | Sem erros e sem latches não intencionais (depende de R-2) | a fazer |
| B08-4 | Relatório de baseline | Área, timing e potência; caminhos críticos; timing atendido ou plano de correção | a fazer |

## Fase 4 — Verificação formal de equivalência (semana 9, 18/12)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B09-1 | Fluxo do Formality por script | RTL (referência), netlist (implementação), PDK, SVF e caixas-pretas consistentes com a síntese | a fazer |
| B09-2 | Match e verify | Sem pontos não casados ou não verificados sem justificativa | a fazer |
| B09-3 | Exercício de diagnóstico | Alteração intencional registrada no relatório | a fazer |

**Recesso:** 21/12/2026 a 03/01/2027, sem entregas. Issues abertas no período são tratadas na semana 10.

## Fase 5 — Fechamento funcional (semana 10, 08/01)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B10-1 | Modos PCBC, CFB e OFB | Os seis modos conferem com o modelo de referência | a fazer |
| B10-2 | Correção das issues do verificador parceiro | Issues classificadas e tratadas | a fazer |
| B10-3 | Nova síntese e nova equivalência | Equivalência RTL v1.1 × netlist confirmada | a fazer |
| B10-4 | Tag `w10-rtl-v1.1` e entrega ao verificador parceiro | Tag comunicada | a fazer |

## Fase 6 — Intenção de potência e baixo consumo (semanas 11 e 12)

### Semana 11 — arquitetura de energia e UPF (15/01)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B11-1 | Perfil de atividade e modos de operação | Blocos ociosos por situação identificados | a fazer |
| B11-2 | Domínios de potência e tabela de estados | Blocos sempre ligados (SPI, banco de registradores, PLL) justificados | a fazer |
| B11-3 | Isolamento, retenção e sequências de desligar e religar | Aprovados na defesa | a fazer |
| B11-4 | UPF | Domínios, redes, chaves, isolamento e retenção; verificação estática sem erros | a fazer |
| B11-5 | Simulação power-aware | Desligar e religar o domínio do AES: corrupção e isolamento corretos | a fazer |

### Semana 12 — técnicas de baixo consumo e RTL v2.0 (22/01)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B12-1 | Controlador de energia | Isolar, salvar, desligar, religar, restaurar e liberar, integrado ao banco | a fazer |
| B12-2 | Clock gating com células ICG | Pontos arquiteturais (por exemplo, `sys_clk` do AES ocioso) | a fazer |
| B12-3 | Outras técnicas | Isolamento de operandos e redução de chaveamento, conforme a arquitetura aprovada | a fazer |
| B12-4 | Testbench das transições de energia | Funcionalidade da v1.1 preservada | a fazer |
| B12-5 | Tag `w12-rtl-v2.0` e entrega para regressão | Tag comunicada | a fazer |

## Fase 7 — Síntese low power e encerramento (semana 13, 29/01)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B13-1 | Síntese do RTL v2.0 com UPF e clock gating automático | Sem erros | a fazer |
| B13-2 | Comparação com o baseline da semana 8 | Área, timing e potência por modo de operação; ganhos e custos justificados | a fazer |
| B13-3 | Equivalência RTL v2.0 × netlist low power | Considerando o UPF e o clock gating | a fazer |
| B13-4 | Documentação, defeitos do parceiro e release final | Reprodutível pelos scripts (simulação, síntese, formal e UPF) | a fazer |
| B13-5 | Apresentação final | Inclui o resultado da verificação do parceiro | a fazer |
| B13-6 | Artigo técnico (quando houver) | Pode ser concluído após o encerramento | a fazer |

---

## Defeitos e issues

| Issue | Origem | Classificação (RTL / ambiente / especificação) | Corrigido em | Status |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

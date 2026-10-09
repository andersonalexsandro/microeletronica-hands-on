# Backlog — AES Top-Level System

O backlog é atualizado no início de cada semana. Cada item tem um identificador estável (`Bxx-n`, em que `xx` é a semana prevista), que é o mesmo usado nas mensagens de commit e nas *issues*. Os defeitos reportados pelo verificador parceiro entram como *issues* e são referenciados aqui, na seção [Defeitos e issues](#defeitos-e-issues).

**Status:** `feito` · `em andamento` · `a fazer` · `bloqueado`

---

## Riscos e bloqueios

| ID | Risco ou bloqueio | Impacto | Ação | Status |
| --- | --- | --- | --- | --- |
| R-1 | Especificação funcional e Figura 1 (arquitetura de topo) ainda não recebidas | Semana 2 inteira (interfaces, mapa de registradores) | Pedir ao instrutor; enquanto isso, a lista de dúvidas está em `reports/estudo_aes_spi.md` §7 | aberto |
| R-2 | Acesso SSH ao servidor `microeletronica3` recusado (`Permission denied (publickey)`) | Fluxo Synopsys (`TOOLS=synopsys`) ainda não executado; o local foi validado | Regularizar a chave com o suporte do servidor e rodar `make` lá | aberto |
| R-3 | Interfaces de topo e dos modelos do PLL e da memória precisam ser compatíveis com o RTL de referência da trilha DV | Retrabalho no RTL e no ambiente de verificação se divergirem | Obter a interface do RTL de referência antes de fechar a arquitetura (B02-3) | aberto |
| R-4 | Verificador parceiro ainda não definido | Ponto de contato da semana 2 | Confirmar a dupla com o instrutor | aberto |

---

## Fase 1 — Especificação e arquitetura (semanas 1–2)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B01-1 | Repositório com a estrutura sugerida, `.gitignore` e README | Estrutura criada; artefatos e PDK fora do Git | feito |
| B01-2 | Fluxo mínimo com um único comando (lint + simulação), nos dois ambientes | `make` em clone limpo termina com "fluxo minimo OK" | feito (local); servidor pendente (R-2) |
| B01-3 | Exemplo mínimo: S-box + testbench self-checking | 256/256 entradas conferidas; lint sem avisos | feito |
| B01-4 | Modelo de referência do AES em Python | Vetores do FIPS-197 (Ap. B, C.1–C.3) passam | feito |
| B01-5 | Relatório de estudo de AES e SPI | `docs/reports/estudo_aes_spi.md` | feito |
| B01-6 | Backlog inicial | Este documento | feito |
| B01-7 | Relatório da semana 1 e tag `w01-setup` | `docs/reports/semana_01.md` | feito |
| B02-1 | Diagrama de blocos e interfaces internas | Todos os sinais entre os blocos nomeados, com largura, direção e domínio de clock | a fazer |
| B02-2 | Interfaces de topo (GLOBAL RESET, clk from OSC, SPI IF, MEMORY DATA IF) | Conferidas com a especificação e com o RTL de referência da trilha DV | a fazer |
| B02-3 | Interfaces dos modelos do PLL e da memória | Nome do módulo, portas, larguras e bits de configuração iguais aos da trilha DV | a fazer |
| B02-4 | Mapa de registradores | Endereço, campo, largura, acesso (RW/RO/W1C), valor de reset e domínio de cada registrador | a fazer |
| B02-5 | Estratégia de clock e reset | Travessia SCLK ↔ sistema definida; reset de cada domínio; sequência de *locked* do PLL | a fazer |
| B02-6 | Microarquitetura do AES | Escolha justificada (iterativa por rodada × alternativas), com latência e área estimadas | a fazer |
| B02-7 | Interface do núcleo AES | Controle e status, chave e acesso aos dados definidos | a fazer |
| B02-8 | Documento de arquitetura v1.0 e defesa | Aprovado pelo instrutor; apresentado ao verificador parceiro | a fazer |

## Fase 2 — Desenvolvimento do RTL (semanas 3–6)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B03-1 | SubBytes, ShiftRows, MixColumns e AddRoundKey | Cada transformação confere com os valores intermediários do FIPS-197 Ap. B (`aes_ref.py --trace`) | a fazer |
| B03-2 | Testes unitários das transformações | Um testbench self-checking por transformação, rodando em `make test` | a fazer |
| B04-1 | Expansão de chave | Palavras `w[i]` conferem com o FIPS-197 Ap. A (`aes_ref.py --keyexp`) | a fazer |
| B04-2 | Controle do núcleo (sequência das rodadas, início e fim) | Segue a interface B02-7 | a fazer |
| B04-3 | Testbench do núcleo com os vetores do padrão | Ap. B e C passam; lint sem erros | a fazer |
| B05-1 | Interface SPI no domínio do SCLK | Registrador de deslocamento, contador de bits e MISO no SCLK | a fazer |
| B05-2 | Sincronização SCLK → sistema | Nenhum barramento multibit sincronizado bit a bit | a fazer |
| B05-3 | Banco de registradores (incluindo a configuração do PLL) | Escrita e leitura via SPI de todos os registradores | a fazer |
| B05-4 | Bloco de RESET | Assert assíncrono e deassert síncrono por domínio; segura o sistema até o *locked* | a fazer |
| B05-5 | Modelo comportamental do PLL (`models/`) | Configuração padrão, *locked* e resposta à reconfiguração | a fazer |
| B05-6 | Testbench de registradores, reset e PLL | Escrita/leitura via SPI, sequência de reset e travamento | a fazer |
| B06-1 | MEMORY / DATA System | Lê blocos pela MEMORY DATA IF, entrega ao AES e escreve o resultado | a fazer |
| B06-2 | Modelo da memória (`models/`) | Interface B02-3 | a fazer |
| B06-3 | Integração do top-level | Interfaces de topo conforme a especificação | a fazer |
| B06-4 | Teste de ponta a ponta | Configuração via SPI → entrada → AES → saída | a fazer |
| B06-5 | Análise de CDC | Nenhuma violação sem justificativa | a fazer |
| B06-6 | Tag `RTL v1.0` e entrega ao parceiro | Tag `w06-rtl-v1.0` comunicada | a fazer |

## Fase 3 — Síntese inicial (semana 7)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B07-1 | SDC: clock do PLL e SCLK assíncronos entre si, I/O e caminhos de sincronização | Sem caminhos sem restrição | a fazer |
| B07-2 | Modelos do PLL e da memória como caixas-pretas ou macros | Conforme orientação do instrutor | a fazer |
| B07-3 | Síntese do RTL v1.0 com o PDK, gerando o SVF | Sem erros e sem latches não intencionais | a fazer |
| B07-4 | Relatório de baseline (área, timing, potência, caminho crítico) | Timing atendido ou plano de correção | a fazer |

## Fase 4 — Equivalência formal (semanas 8–9)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B08-1 | Fluxo Formality por script (RTL × netlist, SVF, caixas-pretas) | `make formal` executável | a fazer |
| B08-2 | *Match* e *verify* do baseline | Todos os pontos casados ou justificados | a fazer |
| B09-1 | Depuração de não equivalências e pontos não verificados | Causas registradas | a fazer |
| B09-2 | Exercício de diagnóstico (alteração intencional) | Registrado no relatório | a fazer |
| B09-3 | Correção dos defeitos até aqui, nova síntese e nova equivalência; tag `RTL v1.1` | Equivalência confirmada | a fazer |

## Fase 5 — Intenção de potência (semanas 10–11)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B10-1 | Perfil de atividade e modos de operação | Blocos ociosos por situação identificados | a fazer |
| B10-2 | Domínios de potência e tabela de estados de potência | RESET, PLL e SPI sempre ligados (ou justificativa) | a fazer |
| B10-3 | Estratégias de isolamento e retenção; sequências de desligar e religar | Aprovadas na defesa | a fazer |
| B11-1 | UPF (domínios, redes, chaves, isolamento, retenção) | Verificação estática sem erros | a fazer |
| B11-2 | Simulação *power-aware* | Corrupção em domínio desligado; isolamento e retenção corretos | a fazer |

## Fase 6 — Baixo consumo (semanas 12–14)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B12-1 | Controlador de energia (isolar, salvar, desligar, religar, restaurar, liberar) | Transições funcionando na simulação *power-aware* | a fazer |
| B12-2 | Comandos e status de energia no banco de registradores | Acessíveis via SPI | a fazer |
| B13-1 | Clock gating (ICG) nos pontos arquiteturais | Funcionalidade da v1.0 preservada | a fazer |
| B13-2 | Isolamento de operandos e redução de chaveamento | Técnica e local documentados | a fazer |
| B13-3 | Tag `RTL v2.0` e entrega ao parceiro para regressão | Tag `w13-rtl-v2.0` comunicada | a fazer |
| B14-1 | Síntese com UPF e inserção de clock gating | Sem erros | a fazer |
| B14-2 | Comparação com o baseline por modo de operação | Ganhos e custos quantificados | a fazer |
| B14-3 | Equivalência RTL v2.0 × netlist low power | Confirmada | a fazer |

## Fase 7 — Encerramento (semana 15)

| ID | Item | Critério de pronto | Status |
| --- | --- | --- | --- |
| B15-1 | Documentação consolidada e guia do repositório | Reprodutível pelos scripts | a fazer |
| B15-2 | Estado final dos defeitos do parceiro | Todas as *issues* classificadas e fechadas ou justificadas | a fazer |
| B15-3 | Apresentação final (com o resultado da verificação do parceiro) | Realizada | a fazer |
| B15-4 | Artigo (versão preliminar) | Entregue | a fazer |

---

## Defeitos e issues

| Issue | Origem | Classificação (RTL / ambiente / especificação) | Corrigido em | Status |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

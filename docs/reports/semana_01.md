# Relatório — Semana 1: kick-off, estudo e ambiente

**Tag:** `w01-setup` · **Backlog:** itens B01-1 a B01-7 ([`../backlog.md`](../backlog.md))

## Entregável e critério de aceite

| Entregável da semana | Onde está | Situação |
| --- | --- | --- |
| Repositório estruturado | raiz do repositório ([`README.md`](../../README.md)) | feito |
| Backlog inicial | [`docs/backlog.md`](../backlog.md) | feito |
| Ambiente executando um exemplo mínimo (compilação, lint e simulação) | `make` ([`Makefile`](../../Makefile)) | feito no ambiente local; **pendente no servidor** (ver Problemas) |
| Relatório de estudo sobre AES e SPI | [`estudo_aes_spi.md`](estudo_aes_spi.md) | feito |

**Critério de aceite:** *o repositório pode ser clonado em um ambiente limpo e o fluxo mínimo executado com um único comando.* Foi conferido clonando o repositório numa pasta vazia e rodando apenas `make`. Resultado abaixo.

## O que foi feito

1. **Estrutura do repositório.** Segue a estrutura sugerida no plano (`docs/`, `rtl/`, `models/`, `tb/`, `formal/`, `syn/`, `upf/`, `scripts/`) e acrescenta:
   - `lint/reports/`, com os relatórios de lint versionados, como pedem as regras gerais;
   - `build/`, ignorada pelo Git, para onde vão todas as saídas das ferramentas.

   As pastas das fases seguintes têm um README curto dizendo o que vão conter. A biblioteca do PDK e todos os artefatos gerados estão no `.gitignore`.

2. **Fluxo com um único comando.** O `make` roda o lint do RTL e todos os testbenches `tb/tb_*.sv`. Ele detecta o ambiente sozinho:
   - no servidor da residência, carrega `/Tools/synopsys/snps.sh` e usa `vlogan +lint=all` e `vlogan → vcs → simv`;
   - fora dele, usa Verilator (`--lint-only -Wall`) e Icarus Verilog.

   O RTL e os testbenches são os mesmos nos dois casos. A lista de fontes fica num único arquivo, [`rtl/rtl.f`](../../rtl/rtl.f), que também vai servir à síntese e ao Formality. Cada testbench imprime `TEST PASSED` ou `TEST FAILED`, e o `make` falha se algum não passar.

3. **Exemplo mínimo.** É a S-box do AES ([`rtl/aes_pkg.sv`](../../rtl/aes_pkg.sv), [`rtl/aes_sbox.sv`](../../rtl/aes_sbox.sv)), em vez de um "hello world". Assim ela já serve de bloco da semana 3 e exercita um package e um módulo. O testbench ([`tb/tb_aes_sbox.sv`](../../tb/tb_aes_sbox.sv)) calcula a S-box pela definição matemática (inverso em GF(2⁸) + transformação afim) e confere as 256 entradas e os três valores citados no FIPS-197.

4. **Modelo de referência** ([`scripts/aes_ref.py`](../../scripts/aes_ref.py)). AES-128/192/256 em Python puro, cifra e decifra. Gera o estado rodada a rodada e a expansão de chave, que serão o oráculo dos testes das semanas 3 e 4. `make ref` roda o auto-teste com os vetores do padrão.

5. **Estudo.** Cobre AES, SPI, CDC e reset e a arquitetura de topo, com as implicações para o RTL e 16 questões em aberto para a especificação e para o parceiro ([`estudo_aes_spi.md`](estudo_aes_spi.md)).

## Resultados

Ambiente local: Verilator 5.020, Icarus Verilog 12.0, GNU Make 4.3 e Python 3.12.

| Verificação | Resultado |
| --- | --- |
| `make` num clone limpo (`TOOLS=oss`) | `== fluxo minimo OK (oss): lint limpo e 1 teste(s) passando ==` |
| Lint do RTL (`verilator --lint-only -Wall`) | 0 erros, 0 avisos ([`lint/reports/lint_verilator.log`](../../lint/reports/lint_verilator.log)) |
| `tb_aes_sbox` | 3 valores do padrão + 256 entradas, 0 erros |
| Teste negativo (um byte da S-box alterado de propósito, `S(53) = ee`) | o testbench acusa `TEST FAILED` e o `make` termina com erro, como esperado |
| `make ref` | Ap. B, C.1, C.2 e C.3 do FIPS-197: todos passam (cifra e decifra) |
| Comparação do modelo com a biblioteca `cryptography` | 300 vetores aleatórios (128/192/256), 0 divergências |

## Problemas encontrados

| Problema | Impacto | Encaminhamento |
| --- | --- | --- |
| O acesso SSH ao servidor `microeletronica3` foi recusado (`Permission denied (publickey)`) | O caminho `TOOLS=synopsys` do Makefile (`vlogan`/`vcs`) **ainda não foi executado**. Os comandos e as opções são os mesmos já validados no servidor no projeto anterior (Vending Machine). | Regularizar a chave e rodar `make` no servidor; registrar o resultado e o `lint/reports/lint_vlogan.log` |
| A especificação funcional e a Figura 1 ainda não foram recebidas | Bloqueia o fechamento das interfaces na semana 2 | As dúvidas estão listadas no relatório de estudo (§7), para levar ao instrutor |
| O verificador parceiro não está definido | Ponto de contato da semana 2 | Confirmar com o instrutor |

## Próximos passos (semana 2)

- Obter a especificação, a Figura 1 e as interfaces do RTL de referência da trilha DV (risco R-3 do backlog).
- Escrever o documento de arquitetura v1.0 (itens B02-1 a B02-8): diagrama de blocos, interfaces de topo e internas, modelos do PLL e da memória, mapa de registradores, estratégia de clock e reset e microarquitetura do AES.
- Decidir a forma de leitura via SPI e a estratégia de reconfiguração do PLL, os dois pontos críticos levantados no estudo.
- Rodar o fluxo no servidor assim que o acesso for restabelecido.

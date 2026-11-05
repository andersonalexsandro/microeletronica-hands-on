# AES Top-Level System (MiniSoC AES) — trilha RTL Design

Projeto integrador da trilha **RTL Design** da Residência em Microeletrônica CI-Expert. O objetivo é um IP digital com **datapath AES-128** (FIPS-197), configurado por **SPI**, que lê e devolve dados por uma **interface de memória**, com blocos de **reset** e **geração de clock** (PLL). O projeto percorre o fluxo completo: RTL → síntese → equivalência formal → intenção de potência (UPF) → técnicas de baixo consumo.

A especificação funcional é o **Block Guide MiniSoC AES v1.0.0**, o mesmo da trilha de *Design Verification*. O IP será verificado em simulação por um verificador parceiro, a partir das tags `rtl-v1.0` (semana 7), `rtl-v1.1` (semana 10) e `rtl-v2.0` (semana 12).

| | |
| --- | --- |
| **Semana atual** | 2 — desafio SubBytes e ShiftRows |
| **Situação** | S-box, SubBytes e ShiftRows (e as inversas) prontos e testados contra o FIPS-197 |
| **Especificação** | [`docs/spec/`](docs/spec/) — Block Guide MiniSoC AES v1.0.0 |
| **Backlog** | [`docs/backlog.md`](docs/backlog.md) |
| **Relatórios semanais** | [`docs/reports/`](docs/reports/) |

---

## Como rodar

```bash
git clone <url-do-repositorio> aes_top_system
cd aes_top_system
make
```

`make` roda o fluxo mínimo: lint do RTL e todos os testbenches de `tb/`. Termina com `== fluxo minimo OK ... ==` ou para no primeiro erro.

O conjunto de ferramentas é escolhido automaticamente:

| Ambiente | Detectado por | Lint | Simulação | Ondas |
| --- | --- | --- | --- | --- |
| Servidor da residência (`TOOLS=synopsys`) | existe `/Tools/synopsys/snps.sh`, carregado pelo próprio Makefile | `vlogan +lint=all` | `vlogan` → `vcs` → `simv` | Verdi (`.fsdb`) |
| Máquina sem Synopsys (`TOOLS=oss`) | ausência do script acima | Verilator `--lint-only -Wall`, um módulo por vez | Icarus Verilog (`iverilog -g2012` + `vvp`) | GTKWave (`.vcd`) |

Para forçar um dos dois: `make TOOLS=oss` ou `make TOOLS=synopsys`. Se o script de setup estiver em outro caminho: `make SNPS_SETUP=/caminho/snps.sh`. Nos dois casos, a unidade de tempo da simulação é 1 ns/1 ps.

### Alvos

| Comando | O que faz |
| --- | --- |
| `make` | fluxo mínimo: lint + todos os testes |
| `make lint` | lint do RTL; o relatório vai para `lint/reports/` |
| `make test` | roda todos os `tb/tb_*.sv` |
| `make sim TB=tb_minisoc_aes_round` | roda um testbench; o log fica em `build/<ferramentas>/<testbench>/sim.log` |
| `make wave TB=tb_minisoc_aes_round` | abre as ondas do último `sim` |
| `make ref` | auto-teste do modelo de referência ([`scripts/aes_ref.py`](scripts/aes_ref.py)) com os vetores do FIPS-197 |
| `make vectors` | regenera os vetores dos testbenches (`tb/vectors/`) a partir do modelo de referência |
| `make clean` | apaga `build/` |

### Pré-requisitos

- `git`, `make` e `bash`; `python3` só para `make ref` e `make vectors`. Os vetores ficam versionados, então o `make` não depende do Python.
- **Servidor:** ambiente Synopsys (VCS, Verdi; nas próximas fases, Design Compiler, Formality e VC LP), com licença configurada pelo `snps.sh`.
- **Local:** Verilator ≥ 5.0, Icarus Verilog ≥ 12 e GTKWave (opcional, só para ver as ondas).

---

## Estrutura

A organização de `rtl/` segue a seção 10 do Block Guide. As pastas marcadas com a semana ainda não existem.

```
.
├── Makefile              # automação do fluxo (ponto de entrada único)
├── docs/
│   ├── spec/             # Block Guide MiniSoC AES v1.0.0 (fornecido)
│   ├── architecture/     # microarquitetura (sem. 3) e arquitetura de energia (sem. 11)
│   ├── reports/          # relatórios semanais (semana_XX.md) e de estudo
│   └── backlog.md        # backlog do projeto
├── rtl/
│   ├── rtl.f             # lista única das fontes RTL, em ordem de compilação
│   ├── minisoc_aes/      # minisoc_aes_top, _dp, _key_exp e submódulos
│   ├── minisoc_spi/      # minisoc_spi (sem. 5)
│   ├── minisoc_pll/      # minisoc_pll_mock, modelo de integração (sem. 5)
│   ├── minisoc_mem/      # minisoc_memory (sem. 6)
│   └── minisoc_top.sv    # topo (sem. 7)
├── tb/                   # testbenches self-checking (tb_*.sv)
│   └── vectors/          # vetores de referência gerados por make vectors
├── lint/                 # relatórios de lint (versionados)
├── syn/                  # SDC, scripts e relatórios de síntese (sem. 8 e 13)
├── formal/               # scripts e relatórios do Formality (sem. 9, 10 e 13)
├── upf/                  # UPF e relatórios power-aware (sem. 11 a 13)
├── scripts/              # modelo de referência do AES
└── build/                # saídas das ferramentas (gerado, ignorado pelo Git)
```

### Conteúdo atual

| Arquivo | Descrição |
| --- | --- |
| [`rtl/minisoc_aes/minisoc_aes_sbox.sv`](rtl/minisoc_aes/minisoc_aes_sbox.sv) | S-box (FIPS-197, Figura 7): tabela de 256 entradas, combinacional |
| [`rtl/minisoc_aes/minisoc_aes_sub_bytes.sv`](rtl/minisoc_aes/minisoc_aes_sub_bytes.sv) | SubBytes: 16 S-boxes, uma por byte do estado |
| [`rtl/minisoc_aes/minisoc_aes_shift_rows.sv`](rtl/minisoc_aes/minisoc_aes_shift_rows.sv) | ShiftRows: a linha `r` gira `r` bytes para a esquerda (só fiação) |
| [`rtl/minisoc_aes/minisoc_aes_inv_sbox.sv`](rtl/minisoc_aes/minisoc_aes_inv_sbox.sv) | S-box inversa (FIPS-197, Figura 14) |
| [`rtl/minisoc_aes/minisoc_aes_inv_sub_bytes.sv`](rtl/minisoc_aes/minisoc_aes_inv_sub_bytes.sv) | InvSubBytes: 16 S-boxes inversas |
| [`rtl/minisoc_aes/minisoc_aes_inv_shift_rows.sv`](rtl/minisoc_aes/minisoc_aes_inv_shift_rows.sv) | InvShiftRows: a linha `r` gira `r` bytes para a direita |
| [`tb/tb_minisoc_aes_sbox.sv`](tb/tb_minisoc_aes_sbox.sv) | S-box e S-box inversa nas 256 entradas, contra as tabelas de referência e `InvS(S(x)) = x` |
| [`tb/tb_minisoc_aes_round.sv`](tb/tb_minisoc_aes_round.sv) | SubBytes → ShiftRows (e inversas) com os estados dos Apêndices B e C.1 e com 1000 estados aleatórios |
| [`scripts/aes_ref.py`](scripts/aes_ref.py) | Modelo de referência do AES-128/192/256 em Python puro: vetores do padrão, estado rodada a rodada, expansão de chave e geração dos vetores dos testbenches |

---

## Convenções

- **Estado do AES:** o byte `n` ocupa `state[127-8n -: 8]` (byte 0 em `[127:120]`, byte 15 em `[7:0]`) e corresponde a `s[r][c]`, com `r = n mod 4` e `c = n div 4` (FIPS-197, seção 3.4). É a ordem do Block Guide (a Word 0 de um bloco é `[127:96]`) e a ordem em que o padrão escreve os vetores em hexadecimal.
- **Entregas semanais:** cada entrega fica numa tag com o número da semana (`w01-setup`, `w02-subbytes-shiftrows`, …, `w07-rtl-v1.0`) e vem com um relatório em `docs/reports/semana_XX.md`.
- **Marcos do IP:** `rtl-v1.0` (semana 7: ECB, CBC e CTR), `rtl-v1.1` (semana 10: os seis modos) e `rtl-v2.0` (semana 12: modos de energia). O verificador parceiro trabalha sempre a partir de uma tag, nunca do estado corrente do repositório.
- **Relatórios de ferramentas** (lint, síntese, formal, UPF) são versionados junto com os scripts que os geraram.
- **Defeitos** encontrados pelo verificador parceiro entram como *issues*, com descrição, cenário de reprodução e evidência (log ou forma de onda). Cada um é classificado como defeito do RTL, do ambiente de verificação ou ambiguidade da especificação.
- **RTL:** SystemVerilog sintetizável (`always_ff`/`always_comb`), um módulo por arquivo com o mesmo nome, sem `` `timescale `` nas fontes (a unidade de tempo é passada pela linha de comando).
- **Testbenches:** imprimem `TEST PASSED` ou `TEST FAILED`, e o Makefile decide o resultado por essa linha. Os valores esperados vêm do texto do FIPS-197 e dos vetores de `tb/vectors/`, gerados pelo modelo de referência.

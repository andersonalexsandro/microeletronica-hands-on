# AES Top-Level System — trilha RTL Design

Projeto integrador da trilha **RTL Design** da Residência em Microeletrônica CI-Expert. O objetivo é um IP digital com **núcleo AES** (FIPS-197), configurado por **SPI**, que lê e devolve dados por uma **interface de memória**, com blocos de **reset** e **geração de clock** (PLL). O projeto percorre o fluxo completo: RTL → síntese → equivalência formal → intenção de potência (UPF) → técnicas de baixo consumo.

A arquitetura de topo é a mesma usada pela trilha de *Design Verification*: o IP será verificado em simulação por um verificador parceiro, a partir das tags `RTL v1.0` e `RTL v2.0`.

| | |
| --- | --- |
| **Semana atual** | 1 — kick-off, estudo e ambiente |
| **Situação** | ambiente e fluxo mínimo prontos; especificação funcional ainda não recebida |
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
| Máquina sem Synopsys (`TOOLS=oss`) | ausência do script acima | Verilator `--lint-only -Wall` | Icarus Verilog (`iverilog -g2012` + `vvp`) | GTKWave (`.vcd`) |

Para forçar um dos dois: `make TOOLS=oss` ou `make TOOLS=synopsys`. Se o script de setup estiver em outro caminho: `make SNPS_SETUP=/caminho/snps.sh`.

### Alvos

| Comando | O que faz |
| --- | --- |
| `make` | fluxo mínimo: lint + todos os testes |
| `make lint` | lint do RTL; o relatório vai para `lint/reports/` |
| `make test` | roda todos os `tb/tb_*.sv` |
| `make sim TB=tb_aes_sbox` | roda um testbench |
| `make wave TB=tb_aes_sbox` | abre as ondas do último `sim` |
| `make ref` | auto-teste do modelo de referência ([`scripts/aes_ref.py`](scripts/aes_ref.py)) com os vetores do FIPS-197 |
| `make clean` | apaga `build/` |

### Pré-requisitos

- `git`, `make`, `bash` e `python3` (este último só para `make ref`).
- **Servidor:** ambiente Synopsys (VCS, Verdi; nas próximas fases, Design Compiler, Formality e VC LP), com licença configurada pelo `snps.sh`.
- **Local:** Verilator ≥ 5.0, Icarus Verilog ≥ 12 e GTKWave (opcional, só para ver as ondas).

---

## Estrutura

```
.
├── Makefile             # automação do fluxo (ponto de entrada único)
├── docs/
│   ├── spec/            # especificação funcional (fornecida pelo instrutor)
│   ├── architecture/    # arquitetura e arquitetura de energia
│   ├── reports/         # relatórios semanais (semana_XX.md) e de estudo
│   └── backlog.md       # backlog do projeto
├── rtl/                 # RTL sintetizável; rtl.f lista as fontes em ordem
├── models/              # modelos comportamentais do PLL e da memória (não sintetizáveis)
├── tb/                  # testbenches self-checking (tb_*.sv)
├── lint/                # relatórios de lint (versionados)
├── syn/                 # SDC, scripts e relatórios de síntese
├── formal/              # scripts e relatórios do Formality
├── upf/                 # UPF e relatórios power-aware
├── scripts/             # utilitários (modelo de referência do AES)
└── build/               # saídas das ferramentas (gerado, ignorado pelo Git)
```

### Conteúdo atual

| Arquivo | Descrição |
| --- | --- |
| [`rtl/aes_pkg.sv`](rtl/aes_pkg.sv) | Package do núcleo AES; por enquanto contém a S-box (FIPS-197, Fig. 7) |
| [`rtl/aes_sbox.sv`](rtl/aes_sbox.sv) | S-box combinacional de 1 byte, exemplo mínimo do fluxo |
| [`tb/tb_aes_sbox.sv`](tb/tb_aes_sbox.sv) | Testbench self-checking: confere as 256 entradas contra a definição matemática da S-box |
| [`scripts/aes_ref.py`](scripts/aes_ref.py) | Modelo de referência do AES-128/192/256 em Python puro: vetores do padrão, estado rodada a rodada e expansão de chave |

---

## Convenções

- **Entregas semanais:** cada entrega fica numa tag com o número da semana (`w01-setup`, `w06-rtl-v1.0`, …) e vem com um relatório em `docs/reports/semana_XX.md`.
- **Marcos do IP:** `RTL v1.0` (semana 6), `RTL v1.1` (semana 9) e `RTL v2.0` (semana 13). O verificador parceiro trabalha sempre a partir de uma tag, nunca do estado corrente do repositório.
- **Relatórios de ferramentas** (lint, síntese, formal, UPF) são versionados junto com os scripts que os geraram.
- **Defeitos** encontrados pelo verificador parceiro entram como *issues*, com descrição, cenário de reprodução e evidência (log ou forma de onda). Cada um é classificado como defeito do RTL, do ambiente de verificação ou ambiguidade da especificação.
- **RTL:** SystemVerilog sintetizável (`always_ff`/`always_comb`), sem `` `timescale `` nas fontes (a unidade de tempo é passada pela linha de comando). Os testbenches imprimem `TEST PASSED` ou `TEST FAILED`, e o Makefile decide o resultado por essa linha.

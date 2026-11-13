# ============================================================================
# AES Top-Level System - automacao do fluxo
# ----------------------------------------------------------------------------
# Um unico comando roda o fluxo minimo (lint do RTL + todos os testbenches):
#
#     make
#
# O conjunto de ferramentas e escolhido pelo ambiente:
#   - servidor da residencia (existe $(SNPS_SETUP)) -> TOOLS=synopsys (vlogan/VCS/Verdi)
#   - maquina sem Synopsys                          -> TOOLS=oss      (Verilator/Icarus/GTKWave)
# Para forcar um deles:  make TOOLS=oss   ou   make TOOLS=synopsys
#
# Tudo que e gerado pelas ferramentas vai para build/ (ignorado pelo Git),
# exceto os relatorios de lint, versionados em lint/reports/.
#
# COMO LER UM MAKEFILE
#   - "VAR := valor" define uma variavel (":=" calcula na hora; "?=" so define
#     se ninguem passou outro valor na linha de comando, ex.: make TB=...).
#   - "alvo: dependencias" seguido de linhas que comecam com TAB e uma regra:
#     as linhas com TAB sao comandos do shell executados para fazer o alvo.
#   - "@" no inicio de um comando esconde o comando (so mostra a saida).
#   - "$$" vira "$" para o shell (o "$" sozinho e do proprio make).
# ============================================================================

# ---------------- shell e caminhos ----------------
# bash com "-e" (para no primeiro erro) e "-o pipefail" (um erro no meio de
# um "a | b" tambem conta como erro). ROOT e a pasta deste Makefile; BUILD e
# onde as ferramentas escrevem.
SHELL       := /bin/bash
.SHELLFLAGS := -eo pipefail -c

ROOT  := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD := $(ROOT)/build

# ---------------- escolha das ferramentas ----------------
# Se o script de ambiente da Synopsys existir, usa as ferramentas do servidor;
# senao, as de codigo aberto (OSS). SNPS_ENV carrega licenca e PATH antes de
# cada comando Synopsys.
SNPS_SETUP ?= /Tools/synopsys/snps.sh
TOOLS      ?= $(if $(wildcard $(SNPS_SETUP)),synopsys,oss)
SNPS_ENV   := source $(SNPS_SETUP) >/dev/null 2>&1 || true;

# ---------------- fontes, testes e vetores ----------------
# RTL_SRCS: le rtl/rtl.f, tira os comentarios (sed) e poe o caminho completo.
# Fontes RTL: lista unica em rtl/rtl.f (linhas com // sao comentario)
RTL_SRCS := $(addprefix $(ROOT)/,$(shell sed -e 's://.*::' $(ROOT)/rtl/rtl.f))
# Lint (Verilator): cada modulo de rtl/rtl.f e verificado como topo, pela
# convencao "um modulo por arquivo, com o mesmo nome". Quando o minisoc_top
# existir (semana 7), basta LINT_TOPS=minisoc_top.
LINT_TOPS ?= $(basename $(notdir $(RTL_SRCS)))

# TESTS: todos os arquivos tb/tb_*.sv, sem caminho e sem extensao, em ordem
# alfabetica. TB: o testbench de "make sim" (o primeiro, se nao for passado).
# Testes: todo tb/tb_*.sv e um testbench self-checking que imprime TEST PASSED/FAILED
TESTS ?= $(sort $(basename $(notdir $(wildcard $(ROOT)/tb/tb_*.sv))))
TB    ?= $(firstword $(TESTS))
# Vetores de referencia lidos pelos testbenches ($readmemh), gerados por make vectors
VEC_DIR := $(ROOT)/tb/vectors

# Pasta de trabalho de cada simulacao e nome do relatorio de lint.
SIM_DIR  = $(BUILD)/$(TOOLS)/$(TB)
LINT_LOG = $(ROOT)/lint/reports/lint_$(if $(filter synopsys,$(TOOLS)),vlogan,verilator).log

# ---------------- alvos principais ----------------
# .PHONY: estes alvos nao sao arquivos, sempre rodam.
# "all" (o padrao de "make") depende de env, lint e test, nessa ordem.
.PHONY: all help env lint test sim wave ref vectors clean
.DEFAULT_GOAL := all

all: env lint test
	@echo "== fluxo minimo OK ($(TOOLS)): lint limpo e $(words $(TESTS)) teste(s) passando =="

help:
	@echo "Alvos:"
	@echo "  make            fluxo minimo: lint + todos os testes (alvo padrao)"
	@echo "  make lint       lint do RTL -> lint/reports/"
	@echo "  make test       roda todos os testbenches de tb/"
	@echo "  make sim TB=x   roda um testbench (padrao: $(TB))"
	@echo "  make wave TB=x  abre as ondas (GTKWave ou Verdi)"
	@echo "  make ref        auto-teste do modelo de referencia (scripts/aes_ref.py)"
	@echo "  make vectors    regenera os vetores dos testbenches (tb/vectors/)"
	@echo "  make clean      apaga build/"
	@echo "Ferramentas em uso: TOOLS=$(TOOLS)  (forcar com TOOLS=oss|synopsys)"

env:
	@echo "== ferramentas: $(TOOLS) | testes: $(TESTS) =="

# ---------------- lint ----------------
# Servidor: vlogan +lint=all em todas as fontes.
# Local: Verilator --lint-only -Wall, um modulo de cada vez como topo. O
# relatorio comeca com a versao da ferramenta e termina com o resultado.
# Como o Verilator sai com erro ao achar qualquer aviso (e o shell tem -e e
# pipefail), um unico aviso para o make.
# ---------------------------------------------------------------- lint ----
lint:
	@mkdir -p $(BUILD)/lint $(dir $(LINT_LOG))
ifeq ($(TOOLS),synopsys)
	cd $(BUILD)/lint && $(SNPS_ENV) vlogan -full64 -sverilog -timescale=1ns/1ps +lint=all \
	    $(RTL_SRCS) 2>&1 | tee $(LINT_LOG)
else
	@{ echo "// $$(verilator --version)"; \
	   echo "// verilator --lint-only -Wall --top-module <modulo> <fontes de rtl/rtl.f>"; } > $(LINT_LOG)
	@for top in $(LINT_TOPS); do \
	    echo "verilator --lint-only -Wall --top-module $$top"; \
	    echo "// $$top" >> $(LINT_LOG); \
	    verilator --lint-only -Wall --top-module $$top $(RTL_SRCS) 2>&1 | tee -a $(LINT_LOG); \
	done
	@echo "// resultado: nenhum erro ou aviso em $(words $(LINT_TOPS)) modulo(s)" >> $(LINT_LOG)
endif
	@echo "[LINT OK] relatorio em $(patsubst $(ROOT)/%,%,$(LINT_LOG))"

# ---------------- simulacao ----------------
# test: chama "make sim" para cada testbench; para no primeiro que falhar.
# sim: 1) apaga e recria a pasta da simulacao;
#      2) compila RTL + testbench (VCS no servidor; Icarus localmente, com a
#         mesma unidade de tempo 1 ns/1 ps do VCS);
#      3) roda, passando +VEC_DIR (o diretorio dos vetores) ao testbench;
#      4) decide pelo log: "TEST PASSED" -> [PASS] com a linha de resumo;
#         senao, mostra o log inteiro e falha.
# ---------------------------------------------------------- simulacao ----
test:
	@for t in $(TESTS); do $(MAKE) --no-print-directory sim TB=$$t || exit 1; done

sim:
	@rm -rf $(SIM_DIR) && mkdir -p $(SIM_DIR)
ifeq ($(TOOLS),synopsys)
	@cd $(SIM_DIR) && $(SNPS_ENV) { \
	    vlogan -full64 -sverilog -kdb -timescale=1ns/1ps +define+FSDB \
	        $(RTL_SRCS) $(ROOT)/tb/$(TB).sv && \
	    vcs -full64 -debug_access+all -kdb $(TB) -o simv; } > compile.log 2>&1 \
	    || { cat compile.log; echo "[FAIL] $(TB): erro de compilacao"; exit 1; }
	@cd $(SIM_DIR) && $(SNPS_ENV) ./simv +VEC_DIR=$(VEC_DIR) -l sim.log > /dev/null
else
	@cd $(SIM_DIR) && echo "+timescale+1ns/1ps" > timescale.f && \
	    iverilog -g2012 -Wall -c timescale.f -s $(TB) -o $(TB).vvp \
	    $(RTL_SRCS) $(ROOT)/tb/$(TB).sv > compile.log 2>&1 \
	    || { cat compile.log; echo "[FAIL] $(TB): erro de compilacao"; exit 1; }
	@cd $(SIM_DIR) && vvp -n $(TB).vvp +VEC_DIR=$(VEC_DIR) > sim.log
endif
	@if grep -q "TEST PASSED" $(SIM_DIR)/sim.log; then \
	    echo "[PASS] $$(grep -m1 '^$(TB):' $(SIM_DIR)/sim.log || echo $(TB))"; \
	 else \
	    cat $(SIM_DIR)/sim.log; echo "[FAIL] $(TB) - log em $(SIM_DIR)/sim.log"; exit 1; \
	 fi

# ---------------- formas de onda ----------------
# Abre as ondas do ultimo "make sim TB=..." (Verdi no servidor, GTKWave aqui).
wave:
ifeq ($(TOOLS),synopsys)
	cd $(SIM_DIR) && $(SNPS_ENV) verdi -nologo -ssf waves.fsdb &
else
	gtkwave $(SIM_DIR)/waves.vcd &
endif

# ---------------- modelo de referencia ----------------
# ref: auto-teste do modelo em Python (vetores e valores intermediarios dos
# padroes). vectors: regenera os arquivos de tb/vectors/.
# -------------------------------------------------- modelo de referencia ----
ref:
	python3 $(ROOT)/scripts/aes_ref.py

# Os vetores ficam versionados em tb/vectors/, para que o make nao dependa do
# Python. Depois de mudar o modelo, rode make vectors e confira o git diff.
vectors:
	python3 -B $(ROOT)/scripts/aes_ref.py --vectors $(VEC_DIR)

# ---------------- limpeza ----------------
clean:
	rm -rf $(BUILD)

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
# ============================================================================

SHELL       := /bin/bash
.SHELLFLAGS := -eo pipefail -c

ROOT  := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD := $(ROOT)/build

SNPS_SETUP ?= /Tools/synopsys/snps.sh
TOOLS      ?= $(if $(wildcard $(SNPS_SETUP)),synopsys,oss)
SNPS_ENV   := source $(SNPS_SETUP) >/dev/null 2>&1 || true;

# Fontes RTL: lista unica em rtl/rtl.f (linhas com // sao comentario)
RTL_SRCS := $(addprefix $(ROOT)/,$(shell sed -e 's://.*::' $(ROOT)/rtl/rtl.f))
LINT_TOP ?= aes_sbox

# Testes: todo tb/tb_*.sv e um testbench self-checking que imprime TEST PASSED/FAILED
TESTS ?= $(sort $(basename $(notdir $(wildcard $(ROOT)/tb/tb_*.sv))))
TB    ?= $(firstword $(TESTS))

SIM_DIR  = $(BUILD)/$(TOOLS)/$(TB)
LINT_LOG = $(ROOT)/lint/reports/lint_$(if $(filter synopsys,$(TOOLS)),vlogan,verilator).log

.PHONY: all help env lint test sim wave ref clean
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
	@echo "  make clean      apaga build/"
	@echo "Ferramentas em uso: TOOLS=$(TOOLS)  (forcar com TOOLS=oss|synopsys)"

env:
	@echo "== ferramentas: $(TOOLS) | testes: $(TESTS) =="

# ---------------------------------------------------------------- lint ----
lint:
	@mkdir -p $(BUILD)/lint $(dir $(LINT_LOG))
ifeq ($(TOOLS),synopsys)
	cd $(BUILD)/lint && $(SNPS_ENV) vlogan -full64 -sverilog -timescale=1ns/1ps +lint=all \
	    $(RTL_SRCS) 2>&1 | tee $(LINT_LOG)
else
	@{ echo "// $$(verilator --version)"; \
	   echo "// verilator --lint-only -Wall --top-module $(LINT_TOP) <fontes de rtl/rtl.f>"; } > $(LINT_LOG)
	verilator --lint-only -Wall --top-module $(LINT_TOP) $(RTL_SRCS) 2>&1 | tee -a $(LINT_LOG)
	@echo "// resultado: nenhum erro ou aviso" >> $(LINT_LOG)
endif
	@echo "[LINT OK] relatorio em $(patsubst $(ROOT)/%,%,$(LINT_LOG))"

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
	@cd $(SIM_DIR) && $(SNPS_ENV) ./simv -l sim.log > /dev/null
else
	@cd $(SIM_DIR) && iverilog -g2012 -Wall -s $(TB) -o $(TB).vvp \
	    $(RTL_SRCS) $(ROOT)/tb/$(TB).sv > compile.log 2>&1 \
	    || { cat compile.log; echo "[FAIL] $(TB): erro de compilacao"; exit 1; }
	@cd $(SIM_DIR) && vvp -n $(TB).vvp > sim.log
endif
	@if grep -q "TEST PASSED" $(SIM_DIR)/sim.log; then \
	    echo "[PASS] $$(grep -m1 '^$(TB):' $(SIM_DIR)/sim.log || echo $(TB))"; \
	 else \
	    cat $(SIM_DIR)/sim.log; echo "[FAIL] $(TB) - log em $(SIM_DIR)/sim.log"; exit 1; \
	 fi

wave:
ifeq ($(TOOLS),synopsys)
	cd $(SIM_DIR) && $(SNPS_ENV) verdi -nologo -ssf waves.fsdb &
else
	gtkwave $(SIM_DIR)/waves.vcd &
endif

# -------------------------------------------------- modelo de referencia ----
ref:
	python3 $(ROOT)/scripts/aes_ref.py

clean:
	rm -rf $(BUILD)

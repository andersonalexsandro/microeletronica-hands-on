# Síntese lógica (Design Compiler)

Semana 8 (baseline do RTL v1.0) e semana 13 (low power, RTL v2.0 com UPF e clock gating). Aqui ficam o SDC, os scripts `dc_shell` e os relatórios de área, timing e potência. A netlist e os arquivos temporários vão para `build/`. A biblioteca do PDK é licenciada e **nunca** é versionada.

**Relação com o projeto:** a síntese transforma o RTL em portas lógicas da biblioteca do PDK e mede área, timing e potência. É ela que responde se o datapath, com uma rodada por ciclo, fecha na frequência-alvo (risco R-6 do [backlog](../docs/backlog.md)).

**Estado:** vazia até a semana 8; depende do acesso ao servidor Synopsys (risco R-2).

# Verificação formal de equivalência (Formality)

Semana 9 (RTL v1.0 × netlist do baseline), semana 10 (RTL v1.1 × nova netlist) e semana 13 (RTL v2.0 × netlist low power, com UPF e clock gating). Aqui ficam os scripts `fm_shell` e os relatórios de *match*, *verify*, pontos não casados e não equivalências. O fluxo usa o SVF gerado pela síntese e trata o PLL mock e a memória como caixas-pretas, como na síntese.

**Relação com o projeto:** a equivalência formal prova matematicamente que a netlist gerada pela síntese faz o mesmo que o RTL, sem simular vetores. Assim, tudo o que os testbenches provaram no RTL continua valendo para o circuito sintetizado.

**Estado:** vazia até a semana 9.

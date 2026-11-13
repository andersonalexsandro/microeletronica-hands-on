# Lint

Relatórios de lint do RTL sintetizável (`rtl/rtl.f`), gerados por `make lint`:

| Ambiente | Ferramenta | Relatório |
| --- | --- | --- |
| Servidor (Synopsys) | `vlogan +lint=all` | `reports/lint_vlogan.log` |
| Local (open-source) | `verilator --lint-only -Wall` | `reports/lint_verilator.log` |

Regra do projeto: nenhum erro, e todo aviso remanescente justificado no relatório da semana.

**Relação com o projeto:** o lint encontra erros de RTL sem simular (larguras de sinal diferentes, laços combinacionais, sinais não usados). Roda em toda entrega, como primeiro passo do `make`. O log versionado é o da última entrega.

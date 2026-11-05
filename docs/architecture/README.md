# Arquitetura

| Documento | Semana | Estado |
| --- | --- | --- |
| Microarquitetura v1.0: diagrama de blocos interno, microarquitetura do AES, FSM do `minisoc_aes_top`, CDC entre `spi_sclk` e `clk` (sincronização por toggle) e sequência de reset do domínio do sistema | 3 | a fazer |
| Arquitetura de energia: modos de operação, domínios de potência, tabela de estados, isolamento, retenção e sequências de desligamento e religamento | 11 | a fazer |

As interfaces de topo, os módulos, o mapa de registradores e o protocolo SPI já estão fixados pelo Block Guide ([`../spec/`](../spec/)). Estes documentos descrevem **como** eles são implementados.

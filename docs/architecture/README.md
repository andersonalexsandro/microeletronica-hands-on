# Arquitetura

| Documento | Semana | Estado |
| --- | --- | --- |
| [Microarquitetura v1.0](microarquitetura_v1.0.md): diagrama de blocos interno, microarquitetura do AES (iterativa, chaves pré-computadas), FSM do `minisoc_aes_top`, os seis modos sobre o datapath, CDC (toggle entre `spi_sclk` e `clk`, handshake de status) e sequência de reset | 3 | v1.0 |
| Arquitetura de energia: modos de operação, domínios de potência, tabela de estados, isolamento, retenção e sequências de desligamento e religamento | 11 | a fazer |

As interfaces de topo, os módulos, o mapa de registradores e o protocolo SPI já estão fixados pelo Block Guide ([`../spec/`](../spec/)). Estes documentos descrevem **como** eles são implementados.

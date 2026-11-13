# Especificação funcional

**Block Guide – MiniSoC AES, v1.0.0** (`DV_BlockGuide_MiniSoCAES_v1.0.0.pdf`), fornecido pelo instrutor. É o mesmo documento da trilha de Design Verification. Esta pasta guarda o arquivo original, sem alterações.

O Block Guide fixa as interfaces de topo, os nomes de módulos e arquivos, o mapa de registradores, o protocolo SPI e o modelo de programação. As referências a seções nos relatórios e no backlog (por exemplo, "seção 6") remetem a ele. Divergências e ambiguidades são registradas como *issues* e levadas ao instrutor; a lista inicial de dúvidas está em [`../reports/semana_02.md`](../reports/semana_02.md#dúvidas-sobre-o-block-guide-seções-1-a-3-e-8).

## Relação com o projeto

Tudo o que o sistema faz vem daqui. A microarquitetura ([`../architecture/`](../architecture/)) decide como implementar, o RTL ([`../../rtl/`](../../rtl/)) implementa e os testbenches ([`../../tb/`](../../tb/)) conferem. O verificador parceiro da trilha de Design Verification usa o mesmo documento, por isso nomes de módulos, portas e registradores seguem o Block Guide à risca.

**Estado:** o PDF original ainda precisa ser copiado para esta pasta.

# Modelos comportamentais (não sintetizáveis)

Modelos simples, usados nos testes iniciais:

- **PLL** (semana 5): sai do reset com a configuração padrão, gera o clock do sistema, ativa `locked` e responde à reconfiguração.
- **Memória** (semana 6): *mock* da MEMORY DATA IF.

A interface (nome do módulo, portas, larguras e bits de configuração) é definida na semana 2 e deve ser **idêntica** à dos modelos da trilha de verificação. Na segunda etapa da verificação, estes modelos são trocados pelos dela. Na síntese e no Formality eles entram como caixas-pretas.

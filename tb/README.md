# Testbenches

Cada testbench é *self-checking*: aplica entradas ao módulo testado (o DUT, Device Under Test), compara cada saída com o valor esperado e termina imprimindo `TEST PASSED` ou `TEST FAILED`. O `Makefile` decide o resultado por essa linha, então `make` só passa se todos passarem.

| Testbench | O que testa | Checagens | Semana |
| --- | --- | --- | --- |
| [`tb_minisoc_aes_sbox.sv`](tb_minisoc_aes_sbox.sv) | S-box e S-box inversa nas 256 entradas e `InvS(S(x)) = x` | 772 | 2 |
| [`tb_minisoc_aes_round.sv`](tb_minisoc_aes_round.sv) | as 7 transformações de rodada, cada uma com a sua própria entrada | 5425 | 2 e 3 |
| [`tb_minisoc_aes_key_exp.sv`](tb_minisoc_aes_key_exp.sv) | expansão de chave, latência de 11 ciclos e reset | 301 | 4 |
| [`tb_minisoc_aes_dp.sv`](tb_minisoc_aes_dp.sv) | datapath completo nos dois sentidos e o protocolo `start`/`done` | 2327 | 4 |

Os valores esperados vêm de fontes independentes do RTL: valores impressos nos padrões (FIPS-197 e NIST SP 800-38A), escritos no próprio testbench, e os arquivos de [`vectors/`](vectors/), gerados por [`../scripts/aes_ref.py`](../scripts/aes_ref.py) com `make vectors`. Os arquivos `.hex` não devem ser editados à mão.

Para rodar um só: `make sim TB=tb_minisoc_aes_dp`; para ver as ondas depois: `make wave TB=tb_minisoc_aes_dp`.

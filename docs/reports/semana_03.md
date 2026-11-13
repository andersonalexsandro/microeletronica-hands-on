# Relatório — Semana 3: microarquitetura e transformações de rodada

**Tag:** `w03-microarquitetura` · **Backlog:** itens B03-1 a B03-5 ([`../backlog.md`](../backlog.md)) · **Especificação:** Block Guide MiniSoC AES v1.0.0

## Entregável e critério de aceite

| Entregável da semana | Onde está | Situação |
| --- | --- | --- |
| Documento de microarquitetura v1.0 | [`docs/architecture/microarquitetura_v1.0.md`](../architecture/microarquitetura_v1.0.md) | feito |
| RTL de todas as transformações de rodada, diretas e inversas | [`rtl/minisoc_aes/`](../../rtl/minisoc_aes/) | feito |
| Testes unitários com os valores intermediários do FIPS-197 (Ap. B e C.1) | [`tb/tb_minisoc_aes_round.sv`](../../tb/tb_minisoc_aes_round.sv) | feito |
| Defesa curta e apresentação ao verificador parceiro | — | pendente: depende da defesa com o instrutor e da definição do parceiro (risco R-4) |

**Critério de aceite:** *microarquitetura aprovada pelo instrutor na defesa curta; transformações conferem com os valores de referência; lint sem erros.* As transformações conferem e o lint está limpo (ver [Resultados](#resultados)); a aprovação depende da defesa.

## O que foi feito

1. **Microarquitetura v1.0.** As decisões principais:
   - **AES iterativo, uma rodada por ciclo**, com estado de 128 bits: 11 ciclos por bloco, nos dois sentidos. A rodada da cifra e a da cifra inversa são caminhos combinacionais paralelos que escrevem no mesmo registrador.
   - **Chaves de rodada pré-computadas** uma vez por operação (11 ciclos) e lidas por índice: rk1 a rk10 na cifra, rk9 a rk0 na inversa. Como o engine usa a mesma chave em até 256 blocos (seção 8.3), a expansão roda uma vez, e não uma vez por bloco. O custo, 1408 flip-flops, está quantificado junto com a alternativa sob demanda.
   - **FSM do `minisoc_aes_top`** (IDLE, CHECK, KEY, READ, CRYPT, WRITE, NEXT, FINISH) e uma tabela que mostra como os seis modos da seção 8.2 usam o mesmo datapath: só ECB, CBC e PCBC usam a cifra inversa.
   - **CDC:** toggle de frame entre `spi_sclk` e `clk` (seção 5.3), leitura SPI em duas transações com `rd_data` estável, START por toggle, configuração capturada no START e status por handshake entre `sys_clk` e `clk`.
   - **Reset:** síncrono na saída, por domínio; o domínio do sistema fica em reset até o lock do PLL e mais 4 bordas de `sys_clk` (seção 4.2). Como o banco de registradores fica no `clk` always-on, reconfigurar o PLL não apaga a configuração.

   As decisões que dependem de pontos abertos do Block Guide estão marcadas como premissas e remetem às dúvidas do [relatório da semana 2](semana_02.md#dúvidas-sobre-o-block-guide-seções-1-a-3-e-8).

2. **RTL.** Novos módulos, todos combinacionais:

   | Módulo | Função | Implementação |
   | --- | --- | --- |
   | `minisoc_aes_mix_columns` | multiplica cada coluna pela matriz `02 03 01 01` | rede de XORs com `xtime`; `{03}·a = xtime(a) ⊕ a` |
   | `minisoc_aes_inv_mix_columns` | multiplica cada coluna pela matriz `0e 0b 0d 09` | `{09}`, `{0b}`, `{0d}` e `{0e}` a partir de `x2`, `x4` e `x8` |
   | `minisoc_aes_add_round_key` | XOR do estado com a chave da rodada | 128 XORs; serve aos dois sentidos |

   InvSubBytes e InvShiftRows já tinham sido entregues na semana 2. Com eles, todas as transformações diretas e inversas estão prontas.

3. **Modelo de referência.** A cifra inversa passou a ser rastreável no formato do Apêndice C.1 (`--trace --decrypt`: `istart`, `is_row`, `is_box`, `ik_sch`, `ik_add`). O auto-teste (`make ref`) agora confere também valores intermediários citados nos padrões, como `round[1].ik_add` do C.1 e o primeiro bloco ECB da SP 800-38A. Assim, todo valor copiado de um padrão para um testbench é conferido antes. O `make vectors` gera os novos arquivos `fips197_cipher_rounds.hex`, `fips197_invcipher_rounds.hex` e `mixcolumns_basis.hex`.

4. **Testes unitários.** O `tb_minisoc_aes_round` passou a dar a cada transformação a sua própria entrada, tirada do vetor. Uma falha aponta exatamente o bloco culpado. São seis partes:
   1. valores copiados do FIPS-197: rodadas 1 e 10 do Apêndice B (cifra) e rodada 1 do Apêndice C.1 (cifra inversa);
   2. cifra: as 10 rodadas dos Apêndices B e C.1;
   3. cifra inversa: as 10 rodadas de C.1 e de B;
   4. ShiftRows e InvShiftRows com os bytes numerados;
   5. MixColumns e InvMixColumns nos 128 estados com um único bit em 1;
   6. em 1000 estados aleatórios: cada inversa desfaz a sua transformação, e MixColumns e InvMixColumns são lineares (`f(x ⊕ y) = f(x) ⊕ f(y)`).

   As partes 5 e 6 juntas cobrem o espaço inteiro de MixColumns, que não pode ser testado exaustivamente (2¹²⁸ estados). Uma função linear fica totalmente determinada pelos valores nos vetores de base, e a parte 6 confere, por amostragem, que o RTL é linear.

## Resultados

Ambiente local: Verilator 5.020, Icarus Verilog 12.0, GNU Make 4.3 e Python 3.12 (`TOOLS=oss`).

```
$ make
== ferramentas: oss | testes: tb_minisoc_aes_round tb_minisoc_aes_sbox ==
verilator --lint-only -Wall --top-module minisoc_aes_sbox
(... os 9 módulos, um por vez ...)
[LINT OK] relatorio em lint/reports/lint_verilator.log
[PASS] tb_minisoc_aes_round: 3 rodadas do padrao + 40 rodadas do modelo + base de MixColumns + 1000 aleatorios, 5425 checagens, 0 erro(s)
[PASS] tb_minisoc_aes_sbox: 4 valores do padrao + 256 entradas (S, InvS e InvS(S(x)) = x), 772 checagens, 0 erro(s)
== fluxo minimo OK (oss): lint limpo e 2 teste(s) passando ==
```

| Verificação | Resultado |
| --- | --- |
| Lint dos 9 módulos (`verilator --lint-only -Wall`) | 0 erros e 0 avisos |
| Compilação no Icarus (`-Wall`) | sem avisos |
| `tb_minisoc_aes_round` | 5425 checagens, 0 erros |
| `tb_minisoc_aes_sbox` | 772 checagens, 0 erros |
| `make ref` | `SELFTEST PASSED`, incluindo os valores intermediários dos padrões |

Trecho do log com os valores copiados do padrão (estado de entrada → estado no fim da rodada, lidos das saídas do RTL):

```
FIPS-197 B   r01  193de3bea0f4e22b9ac68d2ae9f84808 -> a49c7ff2689f352b6b5bea43026a5049  ok
FIPS-197 B   r10  eb40f21e592e38848ba113e71bc342d2 -> 3925841d02dc09fbdc118597196a0b32  ok
FIPS-197 C.1 i01  7ad5fda789ef4e272bca100b3d9ff59f -> 54d990a16ba09ab596bbf40ea111702f  ok
```

### Teste negativo

Um defeito por vez, numa cópia do repositório:

| Defeito injetado | Primeiro erro no `tb_minisoc_aes_round` | `make` |
| --- | --- | --- |
| MixColumns com `{02}` no lugar de `{03}` num termo | `FIPS-197 B r01 MixColumns` (1051 erros) | falha |
| InvMixColumns com `{0b}` e `{0d}` trocados numa linha | `FIPS-197 C.1 i01 InvMixColumns` (1083 erros) | falha |
| AddRoundKey com o bit 0 da chave preso em 0 | `FIPS-197 B r01 AddRoundKey` (21 erros) | falha |

## Problemas encontrados

| Problema | Impacto | Encaminhamento |
| --- | --- | --- |
| A defesa curta e a apresentação ao verificador parceiro ainda não aconteceram | Critério de aceite da semana depende da aprovação do instrutor | Levar o documento ao ponto de acompanhamento; o parceiro ainda não foi definido (R-4) |
| O acesso SSH ao servidor continua recusado | Fluxo Synopsys não executado | Igual à semana 2 (R-2): resolver antes da semana 8 |
| O Block Guide fala em `clk` de 2 GHz e `sys_clk` de até 2 GHz | Uma rodada por ciclo dificilmente fecha nessas frequências | Microarquitetura já prevê dividir a rodada em 2 estágios se for preciso; confirmar o alvo com o instrutor (R-6) |

## Próximos passos (semana 4, entrega 13/11)

- `minisoc_aes_key_exp`: as 11 chaves de rodada, pré-computadas como definido na seção 5.3 da microarquitetura.
- `minisoc_aes_dp`: cifra e cifra inversa de um bloco, com a interface `start`/`done` da seção 6.2.
- Testbench com os vetores do FIPS-197 nos dois sentidos.

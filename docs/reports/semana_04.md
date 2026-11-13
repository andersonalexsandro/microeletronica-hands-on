# Relatório — Semana 4: expansão de chave e datapath AES-128

**Tag:** `w04-datapath-aes128` · **Backlog:** itens B04-1 a B04-3 ([`../backlog.md`](../backlog.md)) · **Especificação:** Block Guide MiniSoC AES v1.0.0

## Entregável e critério de aceite

| Entregável da semana | Onde está | Situação |
| --- | --- | --- |
| RTL de `minisoc_aes_key_exp` | [`rtl/minisoc_aes/minisoc_aes_key_exp.sv`](../../rtl/minisoc_aes/minisoc_aes_key_exp.sv) | feito |
| RTL de `minisoc_aes_dp` | [`rtl/minisoc_aes/minisoc_aes_dp.sv`](../../rtl/minisoc_aes/minisoc_aes_dp.sv) | feito |
| Testbench com os vetores do padrão, nos dois sentidos | [`tb/tb_minisoc_aes_dp.sv`](../../tb/tb_minisoc_aes_dp.sv) e [`tb/tb_minisoc_aes_key_exp.sv`](../../tb/tb_minisoc_aes_key_exp.sv) | feito |

**Critério de aceite:** *cifragem e decriptação conferem com os vetores de referência; lint sem erros.* Os dois vetores do enunciado (FIPS-197, Apêndices C.1 e B) conferem nos dois sentidos, e o lint dos 11 módulos está limpo (ver [Resultados](#resultados)).

## O que foi feito

1. **`minisoc_aes_key_exp`: chaves pré-computadas.** Ao receber a chave (`load_i`), o bloco calcula uma chave de rodada por ciclo e guarda as 11 numa tabela de registradores; `ready_o` sobe 11 ciclos depois. Cada nova chave sai da anterior pela recorrência da seção 5.2 do FIPS-197: `temp = SubWord(RotWord(w3)) ⊕ Rcon[i]` e uma cadeia de XORs entre as palavras. O SubWord reaproveita 4 instâncias da `minisoc_aes_sbox` da semana 2. A justificativa da escolha (pré-computada × sob demanda) está na [microarquitetura, seção 5.3](../architecture/microarquitetura_v1.0.md#53-expansão-de-chave-pré-computada):
   - o engine usa a mesma chave em até 256 blocos (seção 8.3 do Block Guide), então a expansão roda uma vez por operação;
   - a decriptação consome as chaves em ordem inversa só mudando o índice da leitura (rk10 … rk0), sem lógica de expansão inversa;
   - o custo é área: 1408 flip-flops e um mux de leitura 11:1 de 128 bits, a reavaliar com os números da síntese (semana 8).

2. **`minisoc_aes_dp`: datapath iterativo.** O datapath tem um registrador de estado de 128 bits e o hardware de uma rodada da cifra e de uma rodada da inversa, que trabalham em paralelo e são escolhidas por um mux. O bloco leva 11 ciclos do `start_i` ao `done_o`: 1 da AddRoundKey inicial e 10 rodadas. Na rodada 10, um mux pula o MixColumns (ou o InvMixColumns). A expansão de chave é instanciada dentro do dp, que assim é a cifra de bloco completa que o `minisoc_aes_top` vai usar na semana 6. O protocolo é o da seção 6.2 da microarquitetura:
   - `start_i` só é aceito com `busy_o = 0` e `key_ready_o = 1`;
   - `key_load_i` tem prioridade sobre `start_i` no mesmo ciclo e é ignorado durante `busy_o`;
   - `done_o` é um pulso de 1 ciclo, e `block_o` fica estável até o próximo start.

   Os registradores de dados (estado e tabela de chaves) não têm reset e só são escritos com *enable*, o que reduz área e permite clock gating na síntese. O controle tem reset assíncrono.

3. **Testbenches.**
   - `tb_minisoc_aes_key_exp`: rk1 e rk10 do Apêndice A.1 e rk9 e rk10 do Apêndice C.1, copiados do padrão; as 11 chaves de rodada de 22 chaves (A.1, C.1 e 20 aleatórias) contra o modelo; latência de 11 ciclos; `ready_o` em 0 durante a expansão e depois de um reset no meio dela. São 301 checagens.
   - `tb_minisoc_aes_dp`: blocos completos nos dois sentidos, com valores esperados de quatro fontes:

     | Fonte | O que entra |
     | --- | --- |
     | FIPS-197 (vetores do enunciado) | Apêndices C.1 e B, cifra e cifra inversa |
     | NIST SP 800-38A, F.1.1 e F.1.2 | 4 blocos ECB-AES128 seguidos com a mesma chave, como o engine vai usar o dp |
     | NIST AESAVS | chave zero com dois textos claros (*known answer*) |
     | modelo de referência | 202 trios (chave, texto claro, texto cifrado), conferidos também com a biblioteca `cryptography` (OpenSSL), sem divergências |

     Também confere o protocolo: latência de 11 ciclos em cada bloco e em cada carga de chave, `done_o` de 1 ciclo, `block_o` estável, start ignorado sem chave e durante `busy_o`, `key_load_i` ignorado durante `busy_o` (a chave antiga continua valendo) e a prioridade do `key_load_i` sobre o `start_i`. São 2327 checagens.

4. **Modelo de referência.** O `make vectors` gera também `aes128_key_exp.hex` e `aes128_vectors.hex`, com semente fixa (`make vectors` seguido de `git diff` não mostra diferença).

## Resultados

Ambiente local: Verilator 5.020, Icarus Verilog 12.0, GNU Make 4.3 e Python 3.12 (`TOOLS=oss`).

```
$ make
== ferramentas: oss | testes: tb_minisoc_aes_dp tb_minisoc_aes_key_exp tb_minisoc_aes_round tb_minisoc_aes_sbox ==
verilator --lint-only -Wall --top-module minisoc_aes_sbox
(... os 11 módulos, um por vez ...)
[LINT OK] relatorio em lint/reports/lint_verilator.log
[PASS] tb_minisoc_aes_dp: FIPS-197 + SP 800-38A + AESAVS + 202 trios do modelo, nos dois sentidos, + protocolo, 2327 checagens, 0 erro(s)
[PASS] tb_minisoc_aes_key_exp: valores do padrao + 22 chaves x 11 chaves de rodada + latencia e reset, 301 checagens, 0 erro(s)
[PASS] tb_minisoc_aes_round: 3 rodadas do padrao + 40 rodadas do modelo + base de MixColumns + 1000 aleatorios, 5425 checagens, 0 erro(s)
[PASS] tb_minisoc_aes_sbox: 4 valores do padrao + 256 entradas (S, InvS e InvS(S(x)) = x), 772 checagens, 0 erro(s)
== fluxo minimo OK (oss): lint limpo e 4 teste(s) passando ==
```

| Verificação | Resultado |
| --- | --- |
| Lint dos 11 módulos (`verilator --lint-only -Wall`) | 0 erros e 0 avisos ([`lint_verilator.log`](../../lint/reports/lint_verilator.log)) |
| Compilação no Icarus (`-Wall`) | sem avisos |
| Total de checagens nos 4 testbenches | 8825, 0 erros |
| Vetores do enunciado (C.1 e B), cifra e decifra | conferem |
| Latência medida | 11 ciclos por bloco e 11 ciclos por carga de chave |
| `aes128_vectors.hex` contra a `cryptography` (OpenSSL) | 202 trios, 0 divergências |

Trecho do log do `tb_minisoc_aes_dp` (vetor do Apêndice C.1, cifra e depois cifra inversa, lidos das saídas do RTL):

```
C.1: 00112233445566778899aabbccddeeff -> 69c4e0d86a7b0430d8cdb78070b4c55a -> 00112233445566778899aabbccddeeff
```

### Teste negativo

Um defeito por vez, numa cópia do repositório. O `make test` falhou nos 7 casos; a tabela mostra o primeiro erro do teste mais específico.

| Defeito injetado | Primeiro erro | `make` |
| --- | --- | --- |
| Rcon[10] = `6c` (o certo é `36`) | `tb_minisoc_aes_key_exp`: `Ap. A.1 rk10` | falha |
| RotWord ausente na expansão | `tb_minisoc_aes_key_exp`: `Ap. A.1 rk1` | falha |
| Índice da chave na inversa deslocado (`11 − r` no lugar de `10 − r`) | `tb_minisoc_aes_dp`: `FIPS-197 C.1 inversa` | falha |
| Rodada 10 da cifra sem pular o MixColumns | `tb_minisoc_aes_dp`: `FIPS-197 C.1 cifra` | falha |
| Os 3 defeitos da semana 3 (MixColumns, InvMixColumns, AddRoundKey) | `tb_minisoc_aes_dp`, além do teste unitário | falha |

## Problemas encontrados

| Problema | Impacto | Encaminhamento |
| --- | --- | --- |
| O Verilator acusou `UNOPTFLAT` na primeira versão da expansão de chave: cada fatia de `next_key` dependia de outra fatia do mesmo vetor | Não era um laço real, mas o lint precisa sair limpo | As quatro palavras da chave nova viraram sinais separados (`n0` a `n3`); lint limpo |
| O acesso SSH ao servidor continua recusado | Fluxo Synopsys não executado | R-2: resolver antes da semana 8 |
| Frequências de 2 GHz no Block Guide | Pode exigir a rodada em 2 estágios | R-6: confirmar o alvo com o instrutor |

## Próximos passos (semana 5, entrega 20/11)

- `minisoc_spi`: SPI Mode 0, MSB-first, frame de 40 bits, escrita em uma transação e leitura em duas (seção 5), com o toggle de frame da seção 3.1 da microarquitetura.
- Banco de registradores da seção 6 no domínio `clk`.
- `minisoc_pll_mock` (seção 4.1): enable, PLL_DIV_SEL e lock após atraso pseudoaleatório.
- Testbench dirigido: todos os registradores via SPI e o PLL travando nos quatro divisores.

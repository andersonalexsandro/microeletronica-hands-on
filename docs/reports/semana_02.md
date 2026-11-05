# Relatório — Semana 2: desafio SubBytes e ShiftRows

**Tag:** `w02-subbytes-shiftrows` · **Backlog:** itens B02-1 a B02-8 ([`../backlog.md`](../backlog.md)) · **Especificação:** Block Guide MiniSoC AES v1.0.0

## Entregável e critério de aceite

| Entregável da semana | Onde está | Situação |
| --- | --- | --- |
| RTL de `minisoc_aes_sbox`, `minisoc_aes_sub_bytes` e `minisoc_aes_shift_rows` | [`rtl/minisoc_aes/`](../../rtl/minisoc_aes/) | feito |
| Testbench autoverificável | [`tb/tb_minisoc_aes_sbox.sv`](../../tb/tb_minisoc_aes_sbox.sv) e [`tb/tb_minisoc_aes_round.sv`](../../tb/tb_minisoc_aes_round.sv) | feito |
| Resultado dos testes e lista de dúvidas sobre o Block Guide | este relatório | feito |
| Opcional: InvSubBytes e InvShiftRows, testadas como inversas | [`rtl/minisoc_aes/`](../../rtl/minisoc_aes/) | feito |

**Critério de aceite:** *testbench executado por um único comando, com PASS nas 256 entradas da S-box e nos vetores do Apêndice B; lint sem erros.* O comando é `make`, que roda o lint dos seis módulos e os dois testbenches. A saída está em [Resultados](#resultados).

## O que foi feito

1. **Repositório reorganizado conforme a seção 10 do Block Guide.** O RTL do AES fica em `rtl/minisoc_aes/` e os módulos usam o prefixo `minisoc_`. A S-box da semana 1 (`aes_pkg` + `aes_sbox`) virou a `minisoc_aes_sbox`: a tabela é a mesma, conferida entrada a entrada. A pasta `models/` saiu, porque no plano revisado o PLL mock e a memória ficam em `rtl/minisoc_pll/` e `rtl/minisoc_mem/` (semanas 5 e 6).

2. **Convenção do estado.** O byte `n` ocupa `state[127-8n -: 8]`, ou seja, o byte 0 fica em `[127:120]` e o byte 15 em `[7:0]`. O byte `n` é o elemento `s[r][c]` da matriz, com `r = n mod 4` e `c = n div 4` (FIPS-197, seção 3.4). É a ordem em que o padrão escreve os vetores em hexadecimal, a mesma do modelo de referência e do Block Guide (a Word 0 de um bloco é `[127:96]`).

3. **RTL.** Os seis módulos são puramente combinacionais, sem clock e sem reset:

   | Módulo | Função | Implementação |
   | --- | --- | --- |
   | `minisoc_aes_sbox` | S(x), 8 → 8 bits | `case` com as 256 entradas da Figura 7 do FIPS-197 |
   | `minisoc_aes_sub_bytes` | S-box aplicada a cada byte do estado | 16 instâncias da `minisoc_aes_sbox`, geradas por um `for` com `genvar` |
   | `minisoc_aes_shift_rows` | a linha `r` gira `r` posições para a esquerda | só fiação: `s'[r][c] = s[r][(c + r) mod 4]` |
   | `minisoc_aes_inv_sbox` (opcional) | InvS(x) | `case` com as 256 entradas da Figura 14 |
   | `minisoc_aes_inv_sub_bytes` (opcional) | S-box inversa em cada byte | 16 instâncias da `minisoc_aes_inv_sbox` |
   | `minisoc_aes_inv_shift_rows` (opcional) | a linha `r` gira `r` posições para a direita | só fiação: `s'[r][c] = s[r][(c − r) mod 4]` |

   A S-box foi feita por tabela, e não pelo cálculo em GF(2⁸), por ser a forma mais simples de ler e de conferir: a ferramenta de síntese reduz a tabela a uma função lógica de 8 entradas. A alternativa de área menor (inverso em campo composto, relatório de estudo §1.3) fica registrada para quando houver números de síntese (semana 8).

4. **Testbenches autoverificáveis.** Cada um imprime `TEST PASSED` ou `TEST FAILED`, e o `make` decide pelo log.
   - [`tb_minisoc_aes_sbox`](../../tb/tb_minisoc_aes_sbox.sv): confere os valores citados no padrão (`S(00) = 63`, `S(53) = ed`, `InvS(63) = 00` e `InvS(ed) = 53`), as 256 entradas da S-box contra a tabela de referência, as 256 entradas da S-box inversa contra a tabela inversa e a propriedade `InvS(S(x)) = x` para todo `x`. São 772 checagens.
   - [`tb_minisoc_aes_round`](../../tb/tb_minisoc_aes_round.sv): encadeia `start → SubBytes → ShiftRows`, com as inversas ligadas às saídas, e confere: (1) as rodadas 1 e 10 do Apêndice B, com os valores copiados do padrão; (2) as rodadas 1 a 10 dos Apêndices B e C.1, a partir do modelo de referência; (3) ShiftRows e InvShiftRows de um estado com os bytes numerados de `00` a `0f`; (4) `InvSubBytes(SubBytes(x)) = x` e `InvShiftRows(ShiftRows(x)) = x` em 1000 estados aleatórios. São 2090 checagens.

5. **Vetores gerados pelo modelo de referência.** `scripts/aes_ref.py --vectors` (alvo `make vectors`) escreve em `tb/vectors/` as tabelas `sbox.hex` e `inv_sbox.hex` e os estados por rodada `fips197_rounds.hex`. Os testbenches os leem com `$readmemh`, e o diretório chega por *plusarg* (`+VEC_DIR`). Os vetores ficam versionados para que o `make` não dependa do Python. Os testes usam, de propósito, duas fontes independentes: os valores copiados do texto do FIPS-197 e os valores calculados pelo modelo.

6. **Makefile.** O lint passou a verificar cada módulo de `rtl/rtl.f` como topo; antes havia um único topo fixo. O simulador recebe `+VEC_DIR`, e há o alvo `make vectors`. O Icarus agora usa a mesma unidade de tempo do VCS (1 ns/1 ps), por meio de `+timescale+` num arquivo de comandos.

## Resultados

Ambiente local: Verilator 5.020, Icarus Verilog 12.0, GNU Make 4.3 e Python 3.12 (`TOOLS=oss`).

```
$ make
== ferramentas: oss | testes: tb_minisoc_aes_round tb_minisoc_aes_sbox ==
verilator --lint-only -Wall --top-module minisoc_aes_sbox
verilator --lint-only -Wall --top-module minisoc_aes_sub_bytes
verilator --lint-only -Wall --top-module minisoc_aes_shift_rows
verilator --lint-only -Wall --top-module minisoc_aes_inv_sbox
verilator --lint-only -Wall --top-module minisoc_aes_inv_sub_bytes
verilator --lint-only -Wall --top-module minisoc_aes_inv_shift_rows
[LINT OK] relatorio em lint/reports/lint_verilator.log
[PASS] tb_minisoc_aes_round: 22 rodadas do FIPS-197 + bytes numerados + 1000 estados aleatorios, 2090 checagens, 0 erro(s)
[PASS] tb_minisoc_aes_sbox: 4 valores do padrao + 256 entradas (S, InvS e InvS(S(x)) = x), 772 checagens, 0 erro(s)
== fluxo minimo OK (oss): lint limpo e 2 teste(s) passando ==
```

| Verificação | Resultado |
| --- | --- |
| `make` num clone limpo | fluxo mínimo OK, com os 2 testes passando |
| Lint dos 6 módulos (`verilator --lint-only -Wall`) | 0 erros e 0 avisos ([`lint_verilator.log`](../../lint/reports/lint_verilator.log)) |
| Compilação no Icarus (`-Wall`) | sem avisos |
| `tb_minisoc_aes_sbox` | 772 checagens, 0 erros |
| `tb_minisoc_aes_round` | 2090 checagens, 0 erros |
| `make ref` (auto-teste do modelo) | `SELFTEST PASSED` |
| `make vectors` seguido de `git diff tb/vectors` | sem diferenças: os vetores versionados são os do modelo |

Trecho do log de `tb_minisoc_aes_round` com os vetores do enunciado (rodada 1) e a rodada 10. As colunas são o estado no início da rodada, depois do SubBytes e depois do ShiftRows, todos lidos das saídas do RTL:

```
FIPS-197 B r01  193de3bea0f4e22b9ac68d2ae9f84808 -> d42711aee0bf98f1b8b45de51e415230 -> d4bf5d30e0b452aeb84111f11e2798e5  ok
FIPS-197 B r10  eb40f21e592e38848ba113e71bc342d2 -> e9098972cb31075f3d327d94af2e2cb5 -> e9317db5cb322c723d2e895faf090794  ok
ShiftRows   (000102030405060708090a0b0c0d0e0f) = 00050a0f04090e03080d02070c01060b
InvShiftRows(000102030405060708090a0b0c0d0e0f) = 000d0a0704010e0b0805020f0c090603
```

O log completo fica em `build/oss/tb_minisoc_aes_round/sim.log` depois do `make` e lista as 20 rodadas dos Apêndices B e C.1.

### Teste negativo

Para confirmar que os testes de fato reprovam um RTL errado, um defeito foi injetado de cada vez numa cópia do repositório:

| Defeito injetado | Quem detectou | Resultado do `make` |
| --- | --- | --- |
| `S(53) = ee` (o correto é `ed`) | `tb_minisoc_aes_sbox`: valor do padrão, tabela e `InvS(S(x))`; `tb_minisoc_aes_round`: só nos estados aleatórios | falha |
| ShiftRows girando para a direita | `tb_minisoc_aes_round`, já na rodada 1 do Apêndice B (1045 erros) | falha |
| `InvS(ff) = 00` (o correto é `7d`) | `tb_minisoc_aes_sbox` (tabela e `InvS(S(x))`); `tb_minisoc_aes_round` (rodada 7 do Ap. B e estados aleatórios) | falha |
| Diretório de vetores inexistente | os dois testbenches avisam que o arquivo não foi encontrado e contam erro | falha (não passa em silêncio) |

O defeito em `S(53)` mostra por que a varredura exaustiva é necessária: os estados das rodadas dos Apêndices B e C.1 só passam por **186 dos 256** valores de entrada da S-box, e o byte `53` não aparece em nenhum deles. Só os vetores do padrão não bastariam para validar a tabela.

## Problemas encontrados

| Problema | Impacto | Encaminhamento |
| --- | --- | --- |
| O acesso SSH ao servidor `microeletronica3` continua recusado | O caminho `TOOLS=synopsys` (`vlogan +lint=all`, VCS) não foi executado nesta semana. O RTL e os testbenches usam só SystemVerilog padrão, sem recursos específicos do Icarus ou do Verilator. | As semanas 2 a 7 seguem com Verilator e Icarus. A síntese (semana 8), o Formality (semana 9) e o UPF (semanas 11 a 13) dependem do servidor: o acesso precisa voltar antes de 11/12 (risco R-2 do backlog). |

## Dúvidas sobre o Block Guide (seções 1 a 3 e 8)

Pontos a confirmar com o instrutor e com o verificador parceiro antes de fechar a microarquitetura da semana 3.

**Visão geral, arquitetura e interfaces de topo (seções 1 a 3)**

1. **Ordem dos bytes da chave e do IV.** A Word 0 de um bloco é `[127:96]` e o byte 0 fica em `[127:120]`. A mesma regra vale para KEY0–KEY3 e IV0–IV3, ou seja, KEY0 traz os bytes 0 a 3 da chave, com o byte 0 em `KEY0[31:24]`? Uma inversão aqui faz todos os vetores do FIPS-197 falharem no topo, mesmo com o datapath correto.
2. **Domínios de clock.** `clk` (always-on), `sys_clk` (PLL), `spi_sclk` e `mem_clk` são todos assíncronos entre si? Os campos de configuração (KEY, IV, COUNTER, MODE, NUM_BLOCKS) cruzam de `clk` para `sys_clk` como dados estáveis, capturados no START, sem sincronizador bit a bit? Isso define a análise de CDC da semana 7 e os grupos assíncronos do SDC.
3. **Reset de topo.** Qual a polaridade do RESET e ele é assíncrono? Quantos ciclos o domínio do sistema fica em reset depois do PLL_LOCKED (os "ciclos suficientes" da seção 4.2), e em qual clock são contados?
4. **Troca de ownership da memória.** Quando MEM_SEL_AES muda, o clock da memória passa de `mem_clk` para `sys_clk`. A troca pode acontecer com os dois clocks ativos, o que exigiria um mux de clock sem *glitch*, ou o modelo de programação garante que ela só ocorre com a memória ociosa?
5. **MISO fora de transação.** Com o *chip select* inativo, o MISO fica em alta impedância, em 0 ou mantém o último bit?

**AES engine (seção 8)**

6. **Bloco de contador no CTR.** COUNTER_HI/COUNTER_LO somam 64 bits. Como se forma o bloco de 128 bits cifrado: `{IV[127:64], COUNTER}`, `IV ⊕ COUNTER` ou outro arranjo? O incremento é de 64 bits, com volta a zero em 2⁶⁴, ou de 128 bits? O primeiro bloco usa COUNTER ou COUNTER + 1?
7. **DECRYPT nos modos CTR, CFB e OFB.** Nesses modos a decriptação usa a cifra direta. Confirmar que o DECRYPT só muda a realimentação (no CFB, o texto cifrado de entrada) e que a cifra inversa nunca é usada neles. O CFB é o CFB-128, com segmento do tamanho do bloco?
8. **PCBC.** A definição adotada é `C_i = E_K(P_i ⊕ P_{i−1} ⊕ C_{i−1})`, com o IV no papel de `P_0 ⊕ C_0`?
9. **Endereço dos blocos.** O processamento começa sempre no endereço 0, com o bloco `i` nas palavras `4i` a `4i+3` e a Word 0 (`[127:96]`) no endereço mais baixo? Com NUM_BLOCKS = 256, a memória inteira (1024 palavras) é processada?
10. **START fora de hora.** Um START com BUSY = 1 é ignorado, gera ERROR ou fica pendente? E um START com MEM_SEL_AES ainda apontando para a interface externa?
11. **DONE, ERROR e BLOCKS_DONE.** Numa configuração inválida, DONE também sobe (fim sem processamento) ou só ERROR? ERROR é *sticky* como o DONE e é limpo pelo próximo START aceito? BLOCKS_DONE é zerado no START e atualizado a cada bloco escrito?
12. **IV e COUNTER depois da operação.** Os registradores do banco mantêm o valor programado, e o engine trabalha com as cópias capturadas no START? Ou eles são atualizados com o último valor de encadeamento, para continuar uma mensagem numa segunda operação?

## Próximos passos (semana 3, entrega 06/11)

- Documento de microarquitetura v1.0 em `docs/architecture/`: diagrama de blocos interno, AES iterativo com uma rodada por ciclo, FSM do `minisoc_aes_top`, CDC por toggle entre `spi_sclk` e `clk` (seção 5.3) e sequência de reset (seção 4.2).
- MixColumns, AddRoundKey e InvMixColumns. InvSubBytes e InvShiftRows já foram entregues nesta semana.
- Estender o `tb_minisoc_aes_round` com MixColumns e AddRoundKey (Apêndice B) e com a cifra inversa do Apêndice C.1.
- Levar as dúvidas acima ao ponto de acompanhamento e apresentar a microarquitetura ao verificador parceiro.

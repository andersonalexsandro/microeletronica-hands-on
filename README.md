# AES Top-Level System (MiniSoC AES) — trilha RTL Design

Projeto integrador da trilha **RTL Design** da Residência em Microeletrônica CI-Expert. O objetivo é um IP digital com **datapath AES-128** (FIPS-197), configurado por **SPI**, que lê e devolve dados por uma **interface de memória**, com blocos de **reset** e **geração de clock** (PLL). O projeto percorre o fluxo completo: RTL → síntese → equivalência formal → intenção de potência (UPF) → técnicas de baixo consumo.

A especificação funcional é o **Block Guide MiniSoC AES v1.0.0**, o mesmo da trilha de *Design Verification*. O IP será verificado em simulação por um verificador parceiro, a partir das tags `rtl-v1.0` (semana 7), `rtl-v1.1` (semana 10) e `rtl-v2.0` (semana 12).

| | |
| --- | --- |
| **Semana atual** | 4 — expansão de chave e datapath AES-128 |
| **Situação** | datapath AES-128 completo (cifra e cifra inversa, 11 ciclos por bloco) e microarquitetura v1.0 do sistema; 4 testbenches, 8825 checagens |
| **Especificação** | [`docs/spec/`](docs/spec/) — Block Guide MiniSoC AES v1.0.0 |
| **Microarquitetura** | [`docs/architecture/microarquitetura_v1.0.md`](docs/architecture/microarquitetura_v1.0.md) |
| **Backlog** | [`docs/backlog.md`](docs/backlog.md) |
| **Relatórios semanais** | [`docs/reports/`](docs/reports/) |

---

## Como rodar

```bash
git clone <url-do-repositorio> aes_top_system
cd aes_top_system
make
```

`make` roda o fluxo mínimo: lint do RTL e todos os testbenches de `tb/`. Termina com `== fluxo minimo OK ... ==` ou para no primeiro erro.

O conjunto de ferramentas é escolhido automaticamente:

| Ambiente | Detectado por | Lint | Simulação | Ondas |
| --- | --- | --- | --- | --- |
| Servidor da residência (`TOOLS=synopsys`) | existe `/Tools/synopsys/snps.sh`, carregado pelo próprio Makefile | `vlogan +lint=all` | `vlogan` → `vcs` → `simv` | Verdi (`.fsdb`) |
| Máquina sem Synopsys (`TOOLS=oss`) | ausência do script acima | Verilator `--lint-only -Wall`, um módulo por vez | Icarus Verilog (`iverilog -g2012` + `vvp`) | GTKWave (`.vcd`) |

Para forçar um dos dois: `make TOOLS=oss` ou `make TOOLS=synopsys`. Se o script de setup estiver em outro caminho: `make SNPS_SETUP=/caminho/snps.sh`. Nos dois casos, a unidade de tempo da simulação é 1 ns/1 ps.

### Alvos

| Comando | O que faz |
| --- | --- |
| `make` | fluxo mínimo: lint + todos os testes |
| `make lint` | lint do RTL; o relatório vai para `lint/reports/` |
| `make test` | roda todos os `tb/tb_*.sv` |
| `make sim TB=tb_minisoc_aes_round` | roda um testbench; o log fica em `build/<ferramentas>/<testbench>/sim.log` |
| `make wave TB=tb_minisoc_aes_round` | abre as ondas do último `sim` |
| `make ref` | auto-teste do modelo de referência ([`scripts/aes_ref.py`](scripts/aes_ref.py)) com os vetores do FIPS-197 |
| `make vectors` | regenera os vetores dos testbenches (`tb/vectors/`) a partir do modelo de referência |
| `make clean` | apaga `build/` |

### Pré-requisitos

- `git`, `make` e `bash`; `python3` só para `make ref` e `make vectors`. Os vetores ficam versionados, então o `make` não depende do Python.
- **Servidor:** ambiente Synopsys (VCS, Verdi; nas próximas fases, Design Compiler, Formality e VC LP), com licença configurada pelo `snps.sh`.
- **Local:** Verilator ≥ 5.0, Icarus Verilog ≥ 12 e GTKWave (opcional, só para ver as ondas).

---

## Estrutura

A organização de `rtl/` segue a seção 10 do Block Guide. As pastas marcadas com a semana ainda não existem.

```
.
├── Makefile              # automação do fluxo (ponto de entrada único)
├── docs/
│   ├── spec/             # Block Guide MiniSoC AES v1.0.0 (fornecido)
│   ├── architecture/     # microarquitetura (sem. 3) e arquitetura de energia (sem. 11)
│   ├── reports/          # relatórios semanais (semana_XX.md) e de estudo
│   └── backlog.md        # backlog do projeto
├── rtl/
│   ├── rtl.f             # lista única das fontes RTL, em ordem de compilação
│   ├── minisoc_aes/      # minisoc_aes_top, _dp, _key_exp e submódulos
│   ├── minisoc_spi/      # minisoc_spi (sem. 5)
│   ├── minisoc_pll/      # minisoc_pll_mock, modelo de integração (sem. 5)
│   ├── minisoc_mem/      # minisoc_memory (sem. 6)
│   └── minisoc_top.sv    # topo (sem. 7)
├── tb/                   # testbenches self-checking (tb_*.sv)
│   └── vectors/          # vetores de referência gerados por make vectors
├── lint/                 # relatórios de lint (versionados)
├── syn/                  # SDC, scripts e relatórios de síntese (sem. 8 e 13)
├── formal/               # scripts e relatórios do Formality (sem. 9, 10 e 13)
├── upf/                  # UPF e relatórios power-aware (sem. 11 a 13)
├── scripts/              # modelo de referência do AES
└── build/                # saídas das ferramentas (gerado, ignorado pelo Git)
```

### Onde cada bloco entra no sistema

Hierarquia de instâncias do datapath, com os nomes usados no código. Os dois níveis de cima são projetados (semanas 6 e 7); o resto está implementado.

```
minisoc_top                         semana 7: topo do chip
└── minisoc_aes_top                 semana 6: FSM e modos de operação
    └── minisoc_aes_dp              semana 4: datapath, 11 ciclos por bloco
        ├── u_key_exp   minisoc_aes_key_exp          11 chaves de rodada
        │   └── 4 × minisoc_aes_sbox                 SubWord
        │   rodada da cifra
        ├── u_sb        minisoc_aes_sub_bytes
        │   └── 16 × minisoc_aes_sbox
        ├── u_sr        minisoc_aes_shift_rows
        ├── u_mc        minisoc_aes_mix_columns
        ├── u_ark_enc   minisoc_aes_add_round_key
        │   rodada da cifra inversa
        ├── u_isr       minisoc_aes_inv_shift_rows
        ├── u_isb       minisoc_aes_inv_sub_bytes
        │   └── 16 × minisoc_aes_inv_sbox
        ├── u_ark_dec   minisoc_aes_add_round_key
        ├── u_imc       minisoc_aes_inv_mix_columns
        │   só na borda do start
        └── u_ark_init  minisoc_aes_add_round_key
```

### A S-box em poucas palavras

- **O que é.** S-box quer dizer *Substitution box*, caixa de substituição: uma tabela fixa de 256 entradas que troca 1 byte por outro. Exemplo do FIPS-197: S(53) = ed.
- **Para que serve.** É a única parte **não linear** do AES. Todo o resto (ShiftRows, MixColumns, AddRoundKey) é feito de XORs e trocas de posição. Sem a S-box, a cifra inteira seria um sistema de equações lineares, e a chave poderia ser descoberta com álgebra. Ela também é usada na expansão de chave, para que cada chave de rodada dependa da anterior de forma não linear.
- **Como a tabela nasce.** S(x) = afim(x⁻¹): primeiro o inverso de x em GF(2⁸), o corpo de 256 elementos do AES (53⁻¹ = ca); depois uma transformação afim, que soma (XOR) o byte com ele mesmo girado 1, 2, 3 e 4 bits e com a constante 63 (afim(ca) = ed). O hardware não faz essa conta: guarda a tabela pronta. Quem faz a conta é o modelo de referência, que gera a tabela e a confere.
- **Onde está no sistema.** `rtl/minisoc_aes/minisoc_aes_sbox.sv`, usada 16 vezes no SubBytes (primeira fase de cada rodada da cifra) e 4 vezes no SubWord da expansão de chave. A inversa, `minisoc_aes_inv_sbox.sv`, é usada 16 vezes no InvSubBytes da cifra inversa. São 36 tabelas no datapath, a peça de lógica combinacional mais cara da rodada.
- **Onde é testada.** `tb/tb_minisoc_aes_sbox.sv` confere as 256 entradas das duas tabelas; `tb/tb_minisoc_aes_round.sv` confere o SubBytes e o InvSubBytes dentro das rodadas do FIPS-197.

### Mapa dos arquivos

Para cada arquivo: para que serve e como se relaciona com o resto do projeto. Todo arquivo de código também explica o seu papel no cabeçalho.

**Raiz**

| Arquivo | Para que serve | Relação com o projeto |
| --- | --- | --- |
| [`README.md`](README.md) | Porta de entrada: objetivo do projeto, como rodar, estrutura, convenções e este mapa. | É o primeiro arquivo que o instrutor e o verificador parceiro leem em cada tag. |
| [`Makefile`](Makefile) | Automação do fluxo: lint, testes, ondas, modelo de referência e vetores. Escolhe sozinho entre Synopsys e ferramentas open-source. | Um único `make` comprova cada entrega. Nas semanas 8 a 13 ganha os alvos de síntese, Formality e UPF. |
| [`.gitignore`](.gitignore) | Diz ao Git o que não guardar: saídas das ferramentas e bibliotecas do PDK. | Mantém no repositório só o que é fonte. O PDK é licenciado e nunca pode ser versionado. |

**RTL: o hardware (rtl/)**

| Arquivo | Para que serve | Relação com o projeto |
| --- | --- | --- |
| [`rtl/rtl.f`](rtl/rtl.f) | Lista única das fontes RTL, na ordem de compilação: submódulos antes de quem os usa. | Lida pelo lint e pela simulação; na semana 8, também pela síntese. Todo módulo novo entra aqui. |
| [`rtl/minisoc_aes/minisoc_aes_sbox.sv`](rtl/minisoc_aes/minisoc_aes_sbox.sv) | S-box: troca 1 byte por outro numa tabela fixa de 256 entradas. É a única parte não linear do AES. | Semana 2. 16 cópias no SubBytes e 4 no SubWord da expansão de chave. |
| [`rtl/minisoc_aes/minisoc_aes_sub_bytes.sv`](rtl/minisoc_aes/minisoc_aes_sub_bytes.sv) | SubBytes: passa os 16 bytes do estado pela S-box, em paralelo. | Semana 2. Primeira fase da rodada da cifra, dentro do datapath (`u_sb`). |
| [`rtl/minisoc_aes/minisoc_aes_shift_rows.sv`](rtl/minisoc_aes/minisoc_aes_shift_rows.sv) | ShiftRows: a linha r do estado gira r bytes para a esquerda. Só fios. | Semana 2. Segunda fase da rodada da cifra (`u_sr`). |
| [`rtl/minisoc_aes/minisoc_aes_mix_columns.sv`](rtl/minisoc_aes/minisoc_aes_mix_columns.sv) | MixColumns: cada coluna vezes a matriz 02 03 01 01 em GF(2⁸). Rede de XORs. | Semana 3. Terceira fase da rodada da cifra (`u_mc`), pulada na rodada 10. |
| [`rtl/minisoc_aes/minisoc_aes_add_round_key.sv`](rtl/minisoc_aes/minisoc_aes_add_round_key.sv) | AddRoundKey: XOR do estado com a chave da rodada. | Semana 3. Três cópias no datapath: a inicial (`u_ark_init`), a da cifra (`u_ark_enc`) e a da inversa (`u_ark_dec`). |
| [`rtl/minisoc_aes/minisoc_aes_inv_sbox.sv`](rtl/minisoc_aes/minisoc_aes_inv_sbox.sv) | S-box inversa: desfaz a S-box, InvS(S(x)) = x. | Semana 3. 16 cópias no InvSubBytes, usado só para decifrar. |
| [`rtl/minisoc_aes/minisoc_aes_inv_sub_bytes.sv`](rtl/minisoc_aes/minisoc_aes_inv_sub_bytes.sv) | InvSubBytes: passa os 16 bytes pela S-box inversa. | Semana 3. Segunda fase da rodada da cifra inversa (`u_isb`). |
| [`rtl/minisoc_aes/minisoc_aes_inv_shift_rows.sv`](rtl/minisoc_aes/minisoc_aes_inv_shift_rows.sv) | InvShiftRows: a linha r gira r bytes para a direita. Só fios. | Semana 3. Primeira fase da rodada da cifra inversa (`u_isr`). |
| [`rtl/minisoc_aes/minisoc_aes_inv_mix_columns.sv`](rtl/minisoc_aes/minisoc_aes_inv_mix_columns.sv) | InvMixColumns: cada coluna vezes a matriz 0e 0b 0d 09. | Semana 3. Última fase da rodada da inversa (`u_imc`); deve ser o caminho crítico do datapath. |
| [`rtl/minisoc_aes/minisoc_aes_key_exp.sv`](rtl/minisoc_aes/minisoc_aes_key_exp.sv) | Expansão de chave: calcula as 11 chaves de rodada, uma por ciclo, e as guarda numa tabela. | Semana 4. Fica dentro do datapath (`u_key_exp`). A chave virá dos registradores KEY0 a KEY3 (semanas 5 e 6). |
| [`rtl/minisoc_aes/minisoc_aes_dp.sv`](rtl/minisoc_aes/minisoc_aes_dp.sv) | Datapath AES-128: registrador de estado mais uma rodada da cifra e uma da inversa; cifra ou decifra um bloco em 11 ciclos. | Semana 4. É o núcleo que o `minisoc_aes_top` (semana 6) vai comandar bloco a bloco nos seis modos de operação. |

**Testbenches (tb/)**

| Arquivo | Para que serve | Relação com o projeto |
| --- | --- | --- |
| [`tb/tb_minisoc_aes_sbox.sv`](tb/tb_minisoc_aes_sbox.sv) | Confere a S-box e a inversa nas 256 entradas e a propriedade InvS(S(x)) = x (772 checagens). | Prova da entrega da semana 2. |
| [`tb/tb_minisoc_aes_round.sv`](tb/tb_minisoc_aes_round.sv) | Teste unitário das 7 transformações, com as rodadas do FIPS-197 e estados aleatórios (5425 checagens). | Semanas 2 e 3. Quando algo falha, aponta exatamente o bloco culpado. |
| [`tb/tb_minisoc_aes_key_exp.sv`](tb/tb_minisoc_aes_key_exp.sv) | Expansão de chave: chaves do FIPS-197 e do modelo, latência de 11 ciclos e reset (301 checagens). | Prova da entrega da semana 4. |
| [`tb/tb_minisoc_aes_dp.sv`](tb/tb_minisoc_aes_dp.sv) | Datapath completo nos dois sentidos, com vetores de 5 fontes e o protocolo start/done (2327 checagens). | Semana 4. Base do teste de ponta a ponta da semana 7. |
| `tb/vectors/*.hex` | Valores esperados (S-box, rodadas, chaves, blocos completos), um por linha. | Gerados pelo modelo de referência (`make vectors`) e lidos pelos testbenches com `$readmemh`. Não editar à mão. |
| [`tb/README.md`](tb/README.md) | Como os testbenches funcionam e o que cada um testa. | Guia para rodar e entender os testes. |

**Modelo de referência (scripts/)**

| Arquivo | Para que serve | Relação com o projeto |
| --- | --- | --- |
| [`scripts/aes_ref.py`](scripts/aes_ref.py) | Modelo do AES em Python, escrito a partir do FIPS-197: cifra, inversa, expansão de chave, traço rodada a rodada e geração dos vetores. | Fonte independente dos valores esperados dos testbenches. Nas semanas 6 e 10 ganha os seis modos de operação. |

**Documentação (docs/)**

| Arquivo | Para que serve | Relação com o projeto |
| --- | --- | --- |
| [`docs/spec/`](docs/spec/) | Block Guide MiniSoC AES v1.0.0: a especificação funcional. | Define o que o sistema faz; toda referência a "seção X" no projeto aponta para ele. |
| [`docs/architecture/microarquitetura_v1.0.md`](docs/architecture/microarquitetura_v1.0.md) | Como o Block Guide é implementado: diagrama interno, datapath, FSM, modos, CDC e reset. | Entrega da semana 3; guia o RTL das semanas 4 a 7. |
| [`docs/architecture/README.md`](docs/architecture/README.md) | Índice dos documentos de arquitetura. | Ganha a arquitetura de energia na semana 11. |
| [`docs/reports/semana_XX.md`](docs/reports/semana_XX.md) | Relatório de cada entrega: o que foi feito, resultados, problemas e próximos passos. | Exigido em toda semana, junto com a tag. O índice está em `docs/reports/README.md`. |
| [`docs/reports/estudo_aes_spi.md`](docs/reports/estudo_aes_spi.md) | Estudo de AES e SPI feito na semana 1. | Base teórica das semanas 2 a 5. |
| [`docs/backlog.md`](docs/backlog.md) | Tarefas por semana, riscos e pendências. | Atualizado no início de cada semana; os identificadores Bxx-n aparecem nos commits. |

**Fases seguintes**

| Arquivo | Para que serve | Relação com o projeto |
| --- | --- | --- |
| [`lint/`](lint/) | Relatórios de lint, gerados por `make lint`. | Toda entrega: nenhum erro e avisos justificados. |
| [`syn/`](syn/) | Síntese lógica (Design Compiler). | Semanas 8 e 13. Hoje só tem o README. |
| [`formal/`](formal/) | Equivalência formal (Formality). | Semanas 9, 10 e 13. Hoje só tem o README. |
| [`upf/`](upf/) | Intenção de potência (UPF). | Semanas 11 a 13. Hoje só tem o README. |
| `build/` | Saídas das ferramentas: simulações, logs e ondas. | Gerada pelo Makefile e ignorada pelo Git. |

---

## Convenções

- **Estado do AES:** o byte `n` ocupa `state[127-8n -: 8]` (byte 0 em `[127:120]`, byte 15 em `[7:0]`) e corresponde a `s[r][c]`, com `r = n mod 4` e `c = n div 4` (FIPS-197, seção 3.4). É a ordem do Block Guide (a Word 0 de um bloco é `[127:96]`) e a ordem em que o padrão escreve os vetores em hexadecimal.
- **Entregas semanais:** cada entrega fica numa tag com o número da semana (`w01-setup`, `w02-subbytes-shiftrows`, …, `w07-rtl-v1.0`) e vem com um relatório em `docs/reports/semana_XX.md`.
- **Marcos do IP:** `rtl-v1.0` (semana 7: ECB, CBC e CTR), `rtl-v1.1` (semana 10: os seis modos) e `rtl-v2.0` (semana 12: modos de energia). O verificador parceiro trabalha sempre a partir de uma tag, nunca do estado corrente do repositório.
- **Relatórios de ferramentas** (lint, síntese, formal, UPF) são versionados junto com os scripts que os geraram.
- **Defeitos** encontrados pelo verificador parceiro entram como *issues*, com descrição, cenário de reprodução e evidência (log ou forma de onda). Cada um é classificado como defeito do RTL, do ambiente de verificação ou ambiguidade da especificação.
- **RTL:** SystemVerilog sintetizável (`always_ff`/`always_comb`), um módulo por arquivo com o mesmo nome, sem `` `timescale `` nas fontes (a unidade de tempo é passada pela linha de comando).
- **Testbenches:** imprimem `TEST PASSED` ou `TEST FAILED`, e o Makefile decide o resultado por essa linha. Os valores esperados vêm do texto do FIPS-197 e dos vetores de `tb/vectors/`, gerados pelo modelo de referência.

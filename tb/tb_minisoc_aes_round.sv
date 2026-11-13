// ============================================================================
// tb_minisoc_aes_round - testes unitarios das transformacoes de rodada
// ----------------------------------------------------------------------------
// TESTE UNITARIO
//   Cada transformacao e um DUT com a sua propria entrada, tirada direto do
//   vetor de referencia. Assim uma falha aponta exatamente o bloco culpado:
//   se o MixColumns estiver errado, so as checagens de MixColumns falham.
//
//   Cifra (FIPS-197 5.1):          SubBytes, ShiftRows, MixColumns, AddRoundKey
//   Cifra inversa (FIPS-197 5.3):  InvShiftRows, InvSubBytes, AddRoundKey,
//                                  InvMixColumns
//
// O QUE CONFERE
//   1. valores copiados do FIPS-197: rodadas 1 e 10 do Apendice B (cifra) e
//      rodada 1 do Apendice C.1 (cifra inversa), independentes do modelo;
//   2. cifra: rodadas 1 a 10 dos Apendices B e C.1 (fips197_cipher_rounds.hex);
//   3. cifra inversa: rodadas 1 a 10 de C.1 e B (fips197_invcipher_rounds.hex);
//   4. ShiftRows e InvShiftRows com os bytes numerados 00..0f;
//   5. MixColumns e InvMixColumns nos 128 estados com um unico bit em 1
//      (mixcolumns_basis.hex);
//   6. propriedades em 1000 estados aleatorios: cada inversa desfaz a sua
//      transformacao, e MixColumns e InvMixColumns sao lineares
//      (f(x ^ y) = f(x) ^ f(y)).
//   Total: 5425 checagens.
//
// POR QUE 5 E 6 JUNTOS BASTAM
//   MixColumns e InvMixColumns sao lineares sobre GF(2). Todo estado e o XOR
//   de estados com um unico bit em 1, entao um bloco linear que acerta os 128
//   vetores de base acerta todos os 2^128 estados. A parte 6 confere, por
//   amostragem, que o RTL e de fato linear.
//
// Os vetores vem do modelo scripts/aes_ref.py (make vectors); o diretorio
// chega pelo plusarg +VEC_DIR=<dir>.
// Saida: imprime "TEST PASSED" ou "TEST FAILED"; o Makefile decide pelo log.
// ============================================================================
module tb_minisoc_aes_round;

    // ---------------- parametros ----------------
    localparam int N_ROUNDS = 20;     // 10 rodadas x 2 exemplos, em cada sentido
    localparam int N_BASIS  = 128;    // estados com um unico bit em 1
    localparam int N_RANDOM = 1000;

    // ---------------- unidades sob teste ----------------
    // Um par de sinais (entrada _i, saida _o) por transformacao. Todos os
    // DUTs sao combinacionais: nao ha clock neste testbench.
    logic [127:0] sb_i,  sb_o;     // SubBytes
    logic [127:0] sr_i,  sr_o;     // ShiftRows
    logic [127:0] mc_i,  mc_o;     // MixColumns
    logic [127:0] ark_i, ark_k, ark_o;   // AddRoundKey (serve aos dois sentidos)
    logic [127:0] isr_i, isr_o;    // InvShiftRows
    logic [127:0] isb_i, isb_o;    // InvSubBytes
    logic [127:0] imc_i, imc_o;    // InvMixColumns

    minisoc_aes_sub_bytes       u_sb  (.state_i(sb_i),  .state_o(sb_o));
    minisoc_aes_shift_rows      u_sr  (.state_i(sr_i),  .state_o(sr_o));
    minisoc_aes_mix_columns     u_mc  (.state_i(mc_i),  .state_o(mc_o));
    minisoc_aes_add_round_key   u_ark (.state_i(ark_i), .round_key_i(ark_k), .state_o(ark_o));
    minisoc_aes_inv_shift_rows  u_isr (.state_i(isr_i), .state_o(isr_o));
    minisoc_aes_inv_sub_bytes   u_isb (.state_i(isb_i), .state_o(isb_o));
    minisoc_aes_inv_mix_columns u_imc (.state_i(imc_i), .state_o(imc_o));

    // ---------------- vetores de referencia ----------------
    // Cada linha dos arquivos tem 6 valores de 128 bits por rodada; o
    // $readmemh coloca um valor por posicao do array, em sequencia.
    logic [127:0] cv [0:6*N_ROUNDS-1];   // start s_box s_row m_col k_sch fim
    logic [127:0] iv [0:6*N_ROUNDS-1];   // istart is_row is_box ik_sch ik_add fim
    logic [127:0] bv [0:3*N_BASIS-1];    // x  MixColumns(x)  InvMixColumns(x)

    string vec_dir;
    int    checks = 0;
    int    errors = 0;

    // ---------------- tarefa de comparacao ----------------
    // Compara com !== (e nao !=): assim um X ou Z na saida tambem conta como erro
    task automatic check(input string what, input logic [127:0] got, input logic [127:0] expected);
        checks++;
        if (got !== expected) begin
            errors++;
            $display("ERRO: %s\n      obtido   %032h\n      esperado %032h", what, got, expected);
        end
    endtask

    // ---------------- uma rodada da cifra ----------------
    // Cada DUT recebe a entrada ESPERADA da sua etapa (vinda do vetor), e nao a
    // saida do DUT anterior: e isso que torna o teste unitario.
    //   SubBytes(start) = s_box;  ShiftRows(s_box) = s_row;
    //   MixColumns(s_row) = m_col (so ate a rodada 9);
    //   AddRoundKey(m_col, k_sch) = fim da rodada.
    // Na rodada 10 o vetor traz m_col = s_row (sem MixColumns), entao a
    // checagem da AddRoundKey continua valendo.
    // Uma rodada da cifra: cada DUT recebe a entrada esperada da sua etapa
    task automatic cipher_round(input string tag,
                                input logic [127:0] st, input logic [127:0] s_box,
                                input logic [127:0] s_row, input logic [127:0] m_col,
                                input logic [127:0] k_sch, input logic [127:0] fim,
                                input logic last);
        int    errors_before;
        string verdict;
        errors_before = errors;
        sb_i = st; sr_i = s_box; mc_i = s_row; ark_i = m_col; ark_k = k_sch;
        #1;  // logica combinacional: basta deixar o valor propagar
        check({tag, " SubBytes"},    sb_o,  s_box);
        check({tag, " ShiftRows"},   sr_o,  s_row);
        if (!last) check({tag, " MixColumns"}, mc_o, m_col);   // rodada 10: sem MixColumns
        check({tag, " AddRoundKey"}, ark_o, fim);
        if (errors == errors_before) verdict = "ok";
        else                         verdict = "FALHOU";
        $display("%s  %032h -> %032h  %s", tag, st, fim, verdict);
    endtask

    // ---------------- uma rodada da cifra inversa ----------------
    // Mesma ideia, na ordem do FIPS-197 5.3 e na nomenclatura do Apendice C.1:
    //   InvShiftRows(istart) = is_row;  InvSubBytes(is_row) = is_box;
    //   AddRoundKey(is_box, ik_sch) = ik_add;
    //   InvMixColumns(ik_add) = inicio da proxima rodada (menos na ultima).
    // Uma rodada da cifra inversa, na ordem do FIPS-197 5.3
    task automatic inv_round(input string tag,
                             input logic [127:0] istart, input logic [127:0] is_row,
                             input logic [127:0] is_box, input logic [127:0] ik_sch,
                             input logic [127:0] ik_add, input logic [127:0] fim,
                             input logic last);
        int    errors_before;
        string verdict;
        errors_before = errors;
        isr_i = istart; isb_i = is_row; ark_i = is_box; ark_k = ik_sch; imc_i = ik_add;
        #1;
        check({tag, " InvShiftRows"},  isr_o, is_row);
        check({tag, " InvSubBytes"},   isb_o, is_box);
        check({tag, " AddRoundKey"},   ark_o, ik_add);
        if (!last) check({tag, " InvMixColumns"}, imc_o, fim);  // ultima: sem InvMixColumns
        if (errors == errors_before) verdict = "ok";
        else                         verdict = "FALHOU";
        $display("%s  %032h -> %032h  %s", tag, istart, fim, verdict);
    endtask

    logic [127:0] x, y, fx, fy;   // estados das propriedades (parte 6)

    // ---------------- parte 1: valores copiados do FIPS-197 ----------------
    initial begin
`ifdef FSDB
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_minisoc_aes_round);
`else
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_minisoc_aes_round);
`endif

        // 1. valores copiados do FIPS-197
        // Os numeros abaixo estao impressos nos Apendices B e C.1 do padrao;
        // nao dependem do modelo em Python.
        $display("-- 1. valores do padrao: Ap. B rodadas 1 e 10 (cifra), Ap. C.1 rodada 1 (cifra inversa)");
        cipher_round("FIPS-197 B   r01",
                     128'h193de3bea0f4e22b9ac68d2ae9f84808,     // start
                     128'hd42711aee0bf98f1b8b45de51e415230,     // s_box
                     128'hd4bf5d30e0b452aeb84111f11e2798e5,     // s_row
                     128'h046681e5e0cb199a48f8d37a2806264c,     // m_col
                     128'ha0fafe1788542cb123a339392a6c7605,     // k_sch
                     128'ha49c7ff2689f352b6b5bea43026a5049,     // start da rodada 2
                     1'b0);
        cipher_round("FIPS-197 B   r10",
                     128'heb40f21e592e38848ba113e71bc342d2,
                     128'he9098972cb31075f3d327d94af2e2cb5,
                     128'he9317db5cb322c723d2e895faf090794,
                     128'he9317db5cb322c723d2e895faf090794,     // sem MixColumns
                     128'hd014f9a8c9ee2589e13f0cc8b6630ca6,
                     128'h3925841d02dc09fbdc118597196a0b32,     // texto cifrado
                     1'b1);
        inv_round("FIPS-197 C.1 i01",
                  128'h7ad5fda789ef4e272bca100b3d9ff59f,        // istart
                  128'h7a9f102789d5f50b2beffd9f3dca4ea7,        // is_row
                  128'hbd6e7c3df2b5779e0b61216e8b10b689,        // is_box
                  128'h549932d1f08557681093ed9cbe2c974e,        // ik_sch
                  128'he9f74eec023020f61bf2ccf2353c21c7,        // ik_add
                  128'h54d990a16ba09ab596bbf40ea111702f,        // istart da rodada 2
                  1'b0);

        // ---------------- partes 2 e 3: todas as rodadas do modelo ----------------
        // 2 e 3. todas as rodadas, a partir do modelo de referencia
        if (!$value$plusargs("VEC_DIR=%s", vec_dir)) vec_dir = "tb/vectors";
        $readmemh({vec_dir, "/fips197_cipher_rounds.hex"}, cv);
        $readmemh({vec_dir, "/fips197_invcipher_rounds.hex"}, iv);
        $readmemh({vec_dir, "/mixcolumns_basis.hex"}, bv);
        if (cv[6*N_ROUNDS-1] === 128'hx || iv[6*N_ROUNDS-1] === 128'hx || bv[3*N_BASIS-1] === 128'hx) begin
            errors++;
            $display("ERRO: arquivos de vetores incompletos ou nao encontrados em %s", vec_dir);
        end

        // 6*i e o inicio da rodada i no array; (i % 10) == 9 marca a rodada 10.
        $display("-- 2. cifra: Ap. B e C.1, rodadas 1 a 10 (modelo de referencia)");
        for (int i = 0; i < N_ROUNDS; i++)
            cipher_round($sformatf("cifra %s r%02d", (i < 10) ? "B  " : "C.1", i % 10 + 1),
                         cv[6*i], cv[6*i+1], cv[6*i+2], cv[6*i+3], cv[6*i+4], cv[6*i+5],
                         (i % 10) == 9);

        $display("-- 3. cifra inversa: Ap. C.1 e B, rodadas 1 a 10 (modelo de referencia)");
        for (int i = 0; i < N_ROUNDS; i++)
            inv_round($sformatf("inv   %s r%02d", (i < 10) ? "C.1" : "B  ", i % 10 + 1),
                      iv[6*i], iv[6*i+1], iv[6*i+2], iv[6*i+3], iv[6*i+4], iv[6*i+5],
                      (i % 10) == 9);

        // ---------------- parte 4: bytes numerados ----------------
        // 4. bytes numerados: o byte n vale n, entao a saida mostra de onde veio cada byte
        // Ex.: ShiftRows(00 01 02 ... 0f) = 00 05 0a 0f ...: o byte de saida 1
        // veio da posicao 5 da entrada.
        $display("-- 4. ShiftRows e InvShiftRows com os bytes numerados");
        sr_i  = 128'h000102030405060708090a0b0c0d0e0f;
        isr_i = 128'h000102030405060708090a0b0c0d0e0f;
        #1;
        check("ShiftRows(00..0f)",    sr_o,  128'h00050a0f04090e03080d02070c01060b);
        check("InvShiftRows(00..0f)", isr_o, 128'h000d0a0704010e0b0805020f0c090603);
        $display("ShiftRows   (00..0f) = %032h", sr_o);
        $display("InvShiftRows(00..0f) = %032h", isr_o);

        // ---------------- parte 5: vetores de base do MixColumns ----------------
        // 5. vetores de base de MixColumns e InvMixColumns
        // Linha i do arquivo: estado com so o bit i em 1, MC dele e IMC dele.
        $display("-- 5. MixColumns e InvMixColumns nos %0d estados com um unico bit em 1", N_BASIS);
        for (int i = 0; i < N_BASIS; i++) begin
            mc_i  = bv[3*i];
            imc_i = bv[3*i];
            #1;
            check($sformatf("MixColumns(bit %0d)", i),    mc_o,  bv[3*i+1]);
            check($sformatf("InvMixColumns(bit %0d)", i), imc_o, bv[3*i+2]);
        end
        $display("%0d vetores de base conferidos", N_BASIS);

        // ---------------- parte 6: propriedades em estados aleatorios ----------------
        // 6. propriedades em estados aleatorios
        // $urandom devolve 32 bits aleatorios; 4 deles concatenados formam um
        // estado de 128 bits. Aqui os DUTs sao usados em sequencia: primeiro
        // a transformacao, depois a inversa sobre o resultado.
        $display("-- 6. inversas e linearidade em %0d estados aleatorios", N_RANDOM);
        for (int i = 0; i < N_RANDOM; i++) begin
            x = {$urandom, $urandom, $urandom, $urandom};
            y = {$urandom, $urandom, $urandom, $urandom};
            // cada inversa desfaz a sua transformacao
            sb_i = x; sr_i = x; mc_i = x;
            #1;
            isb_i = sb_o; isr_i = sr_o; imc_i = mc_o;
            #1;
            check("InvSubBytes(SubBytes(x))",       isb_o, x);
            check("InvShiftRows(ShiftRows(x))",     isr_o, x);
            check("InvMixColumns(MixColumns(x))",   imc_o, x);
            // linearidade: f(x ^ y) = f(x) ^ f(y)
            // Calcula f(x), depois f(y), soma (XOR) e compara com f(x ^ y).
            mc_i = x; imc_i = x;
            #1;
            fx = mc_o; fy = imc_o;               // fx = MC(x), fy = IMC(x)
            mc_i = y; imc_i = y;
            #1;
            fx = fx ^ mc_o; fy = fy ^ imc_o;     // MC(x)^MC(y) e IMC(x)^IMC(y)
            mc_i = x ^ y; imc_i = x ^ y;
            #1;
            check("MixColumns(x^y) = MixColumns(x)^MixColumns(y)",          mc_o,  fx);
            check("InvMixColumns(x^y) = InvMixColumns(x)^InvMixColumns(y)", imc_o, fy);
        end
        $display("inversas e linearidade conferidas em %0d estados", N_RANDOM);

        $display("tb_minisoc_aes_round: 3 rodadas do padrao + 40 rodadas do modelo + base de MixColumns + %0d aleatorios, %0d checagens, %0d erro(s)",
                 N_RANDOM, checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

endmodule : tb_minisoc_aes_round

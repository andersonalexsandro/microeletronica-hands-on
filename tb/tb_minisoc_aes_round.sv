// ============================================================================
// tb_minisoc_aes_round - testbench self-checking do SubBytes e do ShiftRows
// ----------------------------------------------------------------------------
// Encadeia os DUTs como no exemplo de cifragem do FIPS-197:
//
//   start --SubBytes--> after_sb --ShiftRows--> after_sr
//                          |                       |
//                          +--InvSubBytes-->  back_sb   (tem que ser start)
//                                                  +--InvShiftRows--> back_sr
//                                                           (tem que ser after_sb)
// Confere:
//   1. rodadas 1 e 10 do Apendice B, com os valores copiados do padrao
//      (independentes do modelo de referencia);
//   2. as rodadas 1 a 10 dos Apendices B e C.1, lidas de fips197_rounds.hex,
//      gerado pelo modelo scripts/aes_ref.py (make vectors);
//   3. ShiftRows e InvShiftRows de um estado com os bytes numerados
//      (00, 01, ..., 0f), que deixa a permutacao visivel no log;
//   4. (opcional da semana 2) as inversas em 1000 estados aleatorios:
//      InvSubBytes(SubBytes(x)) = x e InvShiftRows(ShiftRows(x)) = x.
//
// Como os blocos estao em cadeia, um defeito no SubBytes tambem derruba as
// checagens seguintes; o primeiro ERRO do log aponta o bloco culpado.
// Saida: imprime "TEST PASSED" ou "TEST FAILED"; o Makefile decide pelo log.
// ============================================================================
module tb_minisoc_aes_round;

    localparam int N_ROUNDS = 20;     // 10 rodadas do Ap. B + 10 do Ap. C.1
    localparam int N_RANDOM = 1000;

    // ---------------- cadeia principal (partes 1, 2 e 4) ----------------
    logic [127:0] start;      // estimulo: estado no inicio da rodada
    logic [127:0] after_sb;   // SubBytes(start)
    logic [127:0] after_sr;   // ShiftRows(after_sb)
    logic [127:0] back_sb;    // InvSubBytes(after_sb)
    logic [127:0] back_sr;    // InvShiftRows(after_sr)

    minisoc_aes_sub_bytes      dut_sb  (.state_i(start),    .state_o(after_sb));
    minisoc_aes_shift_rows     dut_sr  (.state_i(after_sb), .state_o(after_sr));
    minisoc_aes_inv_sub_bytes  dut_isb (.state_i(after_sb), .state_o(back_sb));
    minisoc_aes_inv_shift_rows dut_isr (.state_i(after_sr), .state_o(back_sr));

    // ---------------- instancias avulsas (parte 3) ----------------
    localparam logic [127:0] NUMBERED = 128'h000102030405060708090a0b0c0d0e0f;
    logic [127:0] sr_numbered, isr_numbered;

    minisoc_aes_shift_rows     dut_sr_num  (.state_i(NUMBERED), .state_o(sr_numbered));
    minisoc_aes_inv_shift_rows dut_isr_num (.state_i(NUMBERED), .state_o(isr_numbered));

    // 3 valores por rodada: start, after SubBytes, after ShiftRows
    logic [127:0] vec [3*N_ROUNDS];

    string vec_dir;
    int    checks = 0;
    int    errors = 0;

    // Compara com !== (e nao !=): assim um X ou Z na saida tambem conta como erro
    task automatic check(input string what, input logic [127:0] got, input logic [127:0] expected);
        checks++;
        if (got !== expected) begin
            errors++;
            $display("ERRO: %s\n      obtido   %032h\n      esperado %032h", what, got, expected);
        end
    endtask

    // Aplica o estado de inicio de uma rodada e confere as quatro saidas
    task automatic check_round(input string tag, input logic [127:0] st,
                               input logic [127:0] exp_sb, input logic [127:0] exp_sr);
        int    errors_before;
        string verdict;
        errors_before = errors;
        start = st;
        #1;  // a logica e combinacional: basta deixar o valor propagar
        check({tag, " SubBytes"},     after_sb, exp_sb);
        check({tag, " ShiftRows"},    after_sr, exp_sr);
        check({tag, " InvSubBytes"},  back_sb,  st);
        check({tag, " InvShiftRows"}, back_sr,  exp_sb);
        if (errors == errors_before) verdict = "ok";
        else                         verdict = "FALHOU";
        $display("%s  %032h -> %032h -> %032h  %s", tag, start, after_sb, after_sr, verdict);
    endtask

    initial begin
`ifdef FSDB
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_minisoc_aes_round);
`else
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_minisoc_aes_round);
`endif

        // 1. valores copiados do FIPS-197, Apendice B
        $display("-- 1. Apendice B, rodadas 1 e 10 (valores do padrao): start -> SubBytes -> ShiftRows");
        check_round("FIPS-197 B r01",
                    128'h193de3bea0f4e22b9ac68d2ae9f84808,
                    128'hd42711aee0bf98f1b8b45de51e415230,
                    128'hd4bf5d30e0b452aeb84111f11e2798e5);
        check_round("FIPS-197 B r10",
                    128'heb40f21e592e38848ba113e71bc342d2,
                    128'he9098972cb31075f3d327d94af2e2cb5,
                    128'he9317db5cb322c723d2e895faf090794);

        // 2. todas as rodadas, a partir do modelo de referencia
        $display("-- 2. Apendices B e C.1, rodadas 1 a 10 (modelo de referencia)");
        if (!$value$plusargs("VEC_DIR=%s", vec_dir)) vec_dir = "tb/vectors";
        $readmemh({vec_dir, "/fips197_rounds.hex"}, vec);
        if (vec[3*N_ROUNDS-1] === 128'hx) begin
            errors++;
            $display("ERRO: fips197_rounds.hex incompleto ou nao encontrado em %s", vec_dir);
        end
        for (int i = 0; i < N_ROUNDS; i++)
            check_round($sformatf("%s r%02d", (i < 10) ? "Ap.B  " : "Ap.C.1", i % 10 + 1),
                        vec[3*i], vec[3*i+1], vec[3*i+2]);

        // 3. bytes numerados: o byte n vale n, entao a saida mostra de onde veio cada byte
        $display("-- 3. bytes numerados (o valor de cada byte e a sua posicao n)");
        check("ShiftRows(00..0f)",    sr_numbered,  128'h00050a0f04090e03080d02070c01060b);
        check("InvShiftRows(00..0f)", isr_numbered, 128'h000d0a0704010e0b0805020f0c090603);
        $display("ShiftRows   (%032h) = %032h", NUMBERED, sr_numbered);
        $display("InvShiftRows(%032h) = %032h", NUMBERED, isr_numbered);

        // 4. inversas como propriedade, em estados aleatorios
        $display("-- 4. inversas em %0d estados aleatorios", N_RANDOM);
        for (int i = 0; i < N_RANDOM; i++) begin
            start = {$urandom, $urandom, $urandom, $urandom};
            #1;
            check($sformatf("InvSubBytes(SubBytes(%032h))", start),     back_sb, start);
            check($sformatf("InvShiftRows(ShiftRows(%032h))", after_sb), back_sr, after_sb);
        end
        $display("InvSubBytes(SubBytes(x)) = x e InvShiftRows(ShiftRows(x)) = x em %0d estados", N_RANDOM);

        $display("tb_minisoc_aes_round: %0d rodadas do FIPS-197 + bytes numerados + %0d estados aleatorios, %0d checagens, %0d erro(s)",
                 N_ROUNDS + 2, N_RANDOM, checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

endmodule : tb_minisoc_aes_round

// ============================================================================
// tb_minisoc_aes_dp - testbench self-checking do datapath AES-128
// ----------------------------------------------------------------------------
// Cifra e cifra inversa de blocos completos, nos dois sentidos:
//   1. protocolo depois do reset: start sem chave carregada e ignorado;
//   2. vetores do enunciado (FIPS-197, Apendices C.1 e B): cifra pt -> ct e
//      cifra inversa ct -> pt;
//   3. NIST SP 800-38A, F.1.1 e F.1.2 (ECB-AES128): 4 blocos seguidos com a
//      mesma chave, como o engine vai usar o datapath;
//   4. NIST AESAVS (known answer): chave zero com dois textos claros;
//   5. 202 trios (chave, texto claro, texto cifrado) do modelo de referencia,
//      conferidos tambem com a biblioteca cryptography (OpenSSL), nos dois
//      sentidos (aes128_vectors.hex);
//   6. protocolo: latencia de 11 ciclos, done de 1 ciclo, block_o estavel,
//      start durante busy ignorado, key_load durante busy ignorado e
//      key_load com prioridade sobre start no mesmo ciclo.
//
// Estimulos mudam na borda de descida; o DUT amostra na de subida.
// Saida: imprime "TEST PASSED" ou "TEST FAILED"; o Makefile decide pelo log.
// ============================================================================
module tb_minisoc_aes_dp;

    localparam int N_VEC   = 202;
    localparam int LATENCY = 11;   // ciclos do start ao done (e do key_load ao key_ready)

    logic         clk = 1'b0;
    logic         rst_n = 1'b0;
    logic         key_load = 1'b0;
    logic [127:0] key = 128'h0;
    logic         key_ready;
    logic         start = 1'b0;
    logic         decrypt = 1'b0;
    logic [127:0] blk = 128'h0;
    logic         busy, done;
    logic [127:0] blk_o;

    minisoc_aes_dp dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .key_load_i  (key_load),
        .key_i       (key),
        .key_ready_o (key_ready),
        .start_i     (start),
        .decrypt_i   (decrypt),
        .block_i     (blk),
        .busy_o      (busy),
        .done_o      (done),
        .block_o     (blk_o)
    );

    always #5 clk = ~clk;   // 100 MHz na simulacao (timescale 1 ns)

    int done_count = 0;     // quantos pulsos de done ja aconteceram
    always @(posedge clk) if (done) done_count++;

    logic [127:0] vec [0:3*N_VEC-1];   // key | plaintext | ciphertext

    string vec_dir;
    int    checks = 0;
    int    errors = 0;

    task automatic check(input string what, input logic [127:0] got, input logic [127:0] expected);
        checks++;
        if (got !== expected) begin
            errors++;
            $display("ERRO: %s\n      obtido   %032h\n      esperado %032h", what, got, expected);
        end
    endtask

    task automatic check_int(input string what, input int got, input int expected);
        checks++;
        if (got !== expected) begin
            errors++;
            $display("ERRO: %s = %0d, esperado %0d", what, got, expected);
        end
    endtask

    // Carrega uma chave e espera key_ready, conferindo a latencia
    task automatic load_key(input logic [127:0] k);
        int lat;
        @(negedge clk);
        key_load = 1'b1;
        key      = k;
        @(negedge clk);
        key_load = 1'b0;
        lat      = 1;
        while (!key_ready && lat < 50) begin
            @(negedge clk);
            lat++;
        end
        check_int("latencia do key_load ao key_ready (ciclos)", lat, LATENCY);
    endtask

    // Processa um bloco e confere o protocolo: busy, latencia, done de 1 ciclo
    // e block_o estavel depois do done
    task automatic run(input string tag, input logic [127:0] in, input logic dec,
                       output logic [127:0] out);
        int lat;
        @(negedge clk);
        start   = 1'b1;
        decrypt = dec;
        blk     = in;
        @(negedge clk);
        start = 1'b0;
        lat   = 1;
        check_int({tag, ": busy logo apos o start"}, int'(busy), 1);
        while (!done && lat < 50) begin
            @(negedge clk);
            lat++;
        end
        check_int({tag, ": latencia do start ao done (ciclos)"}, lat, LATENCY);
        out = blk_o;
        @(negedge clk);
        check_int({tag, ": done dura 1 ciclo"}, int'(done), 0);
        check({tag, ": block_o estavel apos o done"}, blk_o, out);
    endtask

    // Cifra e decifra um trio conhecido
    task automatic both_ways(input string tag, input logic [127:0] k,
                             input logic [127:0] pt, input logic [127:0] ct);
        logic [127:0] got;
        load_key(k);
        run({tag, " cifra"}, pt, 1'b0, got);
        check({tag, " cifra"}, got, ct);
        run({tag, " inversa"}, ct, 1'b1, got);
        check({tag, " inversa"}, got, pt);
    endtask

    localparam logic [127:0] KEY_B  = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    localparam logic [127:0] PT_B   = 128'h3243f6a8885a308d313198a2e0370734;
    localparam logic [127:0] CT_B   = 128'h3925841d02dc09fbdc118597196a0b32;
    localparam logic [127:0] KEY_C1 = 128'h000102030405060708090a0b0c0d0e0f;
    localparam logic [127:0] PT_C1  = 128'h00112233445566778899aabbccddeeff;
    localparam logic [127:0] CT_C1  = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

    // NIST SP 800-38A, F.1.1 e F.1.2: ECB-AES128, chave do Apendice B
    logic [127:0] sp_pt [0:3];
    logic [127:0] sp_ct [0:3];

    logic [127:0] got;
    int           done_before;

    initial begin
`ifdef FSDB
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_minisoc_aes_dp);
`else
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_minisoc_aes_dp);
`endif
        sp_pt[0] = 128'h6bc1bee22e409f96e93d7e117393172a;  sp_ct[0] = 128'h3ad77bb40d7a3660a89ecaf32466ef97;
        sp_pt[1] = 128'hae2d8a571e03ac9c9eb76fac45af8e51;  sp_ct[1] = 128'hf5d3d58503b9699de785895a96fdbaaf;
        sp_pt[2] = 128'h30c81c46a35ce411e5fbc1191a0a52ef;  sp_ct[2] = 128'h43b1cd7f598ece23881b00e3ed030688;
        sp_pt[3] = 128'hf69f2445df4f9b17ad2b417be66c3710;  sp_ct[3] = 128'h7b0c785e27e8ad3f8223207104725dd4;

        // 1. protocolo depois do reset
        $display("-- 1. reset: sem chave carregada, o start e ignorado");
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        check_int("key_ready apos o reset", int'(key_ready), 0);
        @(negedge clk);
        start = 1'b1;
        blk   = PT_B;
        @(negedge clk);
        start = 1'b0;
        check_int("busy com start sem chave", int'(busy), 0);

        // 2. vetores do enunciado (FIPS-197)
        $display("-- 2. FIPS-197 Apendices C.1 e B, nos dois sentidos");
        both_ways("FIPS-197 C.1", KEY_C1, PT_C1, CT_C1);
        both_ways("FIPS-197 B",   KEY_B,  PT_B,  CT_B);
        $display("C.1: %032h -> %032h -> %032h", PT_C1, CT_C1, PT_C1);

        // 3. NIST SP 800-38A: uma chave, varios blocos seguidos
        $display("-- 3. NIST SP 800-38A F.1.1 e F.1.2 (ECB-AES128): 4 blocos com a mesma chave");
        load_key(KEY_B);
        for (int i = 0; i < 4; i++) begin
            run($sformatf("SP 800-38A bloco %0d cifra", i + 1), sp_pt[i], 1'b0, got);
            check($sformatf("SP 800-38A bloco %0d cifra", i + 1), got, sp_ct[i]);
        end
        for (int i = 0; i < 4; i++) begin
            run($sformatf("SP 800-38A bloco %0d inversa", i + 1), sp_ct[i], 1'b1, got);
            check($sformatf("SP 800-38A bloco %0d inversa", i + 1), got, sp_pt[i]);
        end

        // 4. NIST AESAVS: known answer com chave zero
        $display("-- 4. NIST AESAVS: chave zero");
        both_ways("AESAVS pt=00..00", 128'h0, 128'h0, 128'h66e94bd4ef8a2c3b884cfa59ca342b2e);
        both_ways("AESAVS pt=80..00", 128'h0, 128'h80000000000000000000000000000000,
                  128'h3ad78e726c1ec02b7ebfe92b23d9ec34);

        // 5. 202 trios do modelo de referencia
        $display("-- 5. %0d trios do modelo de referencia, nos dois sentidos", N_VEC);
        if (!$value$plusargs("VEC_DIR=%s", vec_dir)) vec_dir = "tb/vectors";
        $readmemh({vec_dir, "/aes128_vectors.hex"}, vec);
        if (vec[3*N_VEC-1] === 128'hx) begin
            errors++;
            $display("ERRO: aes128_vectors.hex incompleto ou nao encontrado em %s", vec_dir);
        end
        for (int i = 0; i < N_VEC; i++)
            both_ways($sformatf("trio %0d", i), vec[3*i], vec[3*i+1], vec[3*i+2]);
        $display("%0d trios conferidos", N_VEC);

        // 6. protocolo
        $display("-- 6. protocolo: start e key_load fora de hora");
        load_key(KEY_B);
        // start durante busy: ignorado, um unico done, resultado do primeiro bloco
        done_before = done_count;
        @(negedge clk); start = 1'b1; decrypt = 1'b0; blk = PT_B;
        @(negedge clk); start = 1'b0;
        repeat (3) @(negedge clk);
        start = 1'b1; blk = PT_C1;                       // segundo start, com busy = 1
        @(negedge clk); start = 1'b0;
        while (!done) @(negedge clk);
        check("start durante busy: resultado do primeiro bloco", blk_o, CT_B);
        repeat (15) @(negedge clk);
        check_int("start durante busy: pulsos de done", done_count - done_before, 1);
        check_int("start durante busy: busy no fim", int'(busy), 0);
        // key_load durante busy: ignorado, a tabela de chaves nao muda
        @(negedge clk); start = 1'b1; blk = PT_B;
        @(negedge clk); start = 1'b0;
        repeat (3) @(negedge clk);
        key_load = 1'b1; key = KEY_C1;                   // carga de chave com busy = 1
        @(negedge clk); key_load = 1'b0;
        while (!done) @(negedge clk);
        check("key_load durante busy: resultado com a chave antiga", blk_o, CT_B);
        check_int("key_load durante busy: key_ready continua 1", int'(key_ready), 1);
        run("chave preservada", PT_B, 1'b0, got);
        check("key_load durante busy: chave preservada", got, CT_B);
        // start e key_load no mesmo ciclo: a carga de chave vence
        @(negedge clk); start = 1'b1; key_load = 1'b1; key = KEY_C1; blk = PT_C1;
        @(negedge clk); start = 1'b0; key_load = 1'b0;
        check_int("start + key_load: start ignorado (busy)", int'(busy), 0);
        check_int("start + key_load: key_ready cai", int'(key_ready), 0);
        while (!key_ready) @(negedge clk);
        run("depois da nova chave", PT_C1, 1'b0, got);
        check("start + key_load: nova chave em uso", got, CT_C1);

        $display("tb_minisoc_aes_dp: FIPS-197 + SP 800-38A + AESAVS + %0d trios do modelo, nos dois sentidos, + protocolo, %0d checagens, %0d erro(s)",
                 N_VEC, checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

    initial begin   // guarda contra travamento
        #5_000_000;   // 5 ms
        $display("ERRO: tempo esgotado");
        $display("TEST FAILED");
        $finish;
    end

endmodule : tb_minisoc_aes_dp

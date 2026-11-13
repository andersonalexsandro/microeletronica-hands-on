// ============================================================================
// tb_minisoc_aes_key_exp - testbench self-checking da expansao de chave
// ----------------------------------------------------------------------------
// O QUE CONFERE
//   1. depois do reset, ready_o = 0;
//   2. valores copiados do FIPS-197: chave do Apendice A.1 (a mesma do
//      Apendice B), rk1 = a0fafe17... e rk10 = d014f9a8...; chave do Apendice
//      C.1, rk9 e rk10 (a primeira chave usada pela cifra inversa);
//   3. as 11 chaves de rodada de 22 chaves (A.1, C.1 e 20 aleatorias),
//      contra aes128_key_exp.hex, gerado pelo modelo scripts/aes_ref.py;
//   4. latencia: ready_o sobe 11 ciclos depois do load_i (rk0 + 10 chaves) e
//      fica em 0 durante a expansao, inclusive numa recarga;
//   5. reset no meio da expansao derruba ready_o.
//   Total: 301 checagens.
//
// DIFERENCA PARA OS TESTBENCHES DAS SEMANAS 2 E 3
//   O minisoc_aes_key_exp e SEQUENCIAL (tem clock e registradores). Por isso
//   este testbench gera um clock e muda os estimulos na borda de DESCIDA,
//   enquanto o DUT amostra na de SUBIDA: assim nunca ha disputa entre o
//   testbench escrever e o DUT ler no mesmo instante.
//
// Saida: imprime "TEST PASSED" ou "TEST FAILED"; o Makefile decide pelo log.
// ============================================================================
module tb_minisoc_aes_key_exp;

    // ---------------- parametros, DUT e clock ----------------
    // localparam = constante do testbench.
    localparam int N_KEYS  = 22;
    localparam int LATENCY = 11;   // ciclos do load_i ao ready_o

    // Sinais dirigidos pelo testbench, com valor inicial (reset ativo: 0).
    logic         clk = 1'b0;
    logic         rst_n = 1'b0;
    logic         load = 1'b0;
    logic [127:0] key = 128'h0;
    logic         ready;
    logic [3:0]   rnd = 4'h0;
    logic [127:0] rk;

    minisoc_aes_key_exp dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .load_i      (load),
        .key_i       (key),
        .ready_o     (ready),
        .round_i     (rnd),
        .round_key_o (rk)
    );

    // Gerador de clock: inverte clk a cada 5 ns -> periodo de 10 ns.
    always #5 clk = ~clk;   // 100 MHz na simulacao (timescale 1 ns)

    // Vetores do modelo: 11 chaves de rodada por chave, uma apos a outra.
    logic [127:0] kv [0:11*N_KEYS-1];   // linha i: rk0 ... rk10 da chave i

    string vec_dir;
    int    checks = 0;
    int    errors = 0;

    // ---------------- tarefas de comparacao ----------------
    // check: compara valores de 128 bits (chaves); check_int: compara numeros
    // inteiros (latencia, ready). As duas contam checagens e erros.
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

    // ---------------- tarefas de estimulo ----------------
    // expand: da um pulso de 1 ciclo em load e conta os ciclos ate ready.
    //   @(negedge clk) espera a proxima borda de descida.
    //   O DUT ve load = 1 na borda de subida entre as duas descidas.
    //   Esperado: ready continua 0 durante a expansao e sobe depois de 11
    //   ciclos (rk0 + 10 chaves). "lat < 50" evita laco infinito.
    // Pulsa load_i e espera ready_o, conferindo a latencia e o ready em 0
    task automatic expand(input string tag, input logic [127:0] k);
        int lat;
        @(negedge clk);
        load = 1'b1;
        key  = k;
        @(negedge clk);
        load = 1'b0;
        lat  = 1;
        check_int({tag, ": ready em 0 durante a expansao"}, int'(ready), 0);
        while (!ready && lat < 50) begin
            @(negedge clk);
            lat++;
        end
        check_int({tag, ": latencia do load ao ready (ciclos)"}, lat, LATENCY);
    endtask

    // read_rk: poe o indice r na porta round_i e le a chave. A leitura do DUT
    // e combinacional, entao basta esperar 1 ns.
    // Le a chave de rodada r (a leitura e combinacional)
    task automatic read_rk(input int r, output logic [127:0] value);
        rnd = r[3:0];
        #1;
        value = rk;
    endtask

    logic [127:0] got;

    // ---------------- sequencia de teste ----------------
    initial begin
`ifdef FSDB
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_minisoc_aes_key_exp);
`else
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_minisoc_aes_key_exp);
`endif

        // 1. reset: com rst_n = 0, ready tem que estar em 0; depois solta.
        repeat (2) @(negedge clk);
        check_int("ready depois do reset", int'(ready), 0);
        rst_n = 1'b1;

        // 2. valores copiados do FIPS-197
        // A.1: rk1 = w4..w7 e rk10 = w40..w43 do Apendice A.1.
        // C.1: rk9 e rk10 aparecem na listagem da cifra inversa do C.1.
        $display("-- 2. valores do padrao (Apendices A.1 e C.1)");
        expand("Ap. A.1", 128'h2b7e151628aed2a6abf7158809cf4f3c);
        read_rk(0,  got); check("Ap. A.1 rk0 (a propria chave)", got, 128'h2b7e151628aed2a6abf7158809cf4f3c);
        read_rk(1,  got); check("Ap. A.1 rk1 (w4..w7)",          got, 128'ha0fafe1788542cb123a339392a6c7605);
        read_rk(10, got); check("Ap. A.1 rk10 (w40..w43)",       got, 128'hd014f9a8c9ee2589e13f0cc8b6630ca6);
        expand("Ap. C.1", 128'h000102030405060708090a0b0c0d0e0f);
        read_rk(9,  got); check("Ap. C.1 rk9",  got, 128'h549932d1f08557681093ed9cbe2c974e);
        read_rk(10, got); check("Ap. C.1 rk10", got, 128'h13111d7fe3944a17f307a78b4d2b30c5);

        // 3. 22 chaves completas, a partir do modelo de referencia
        // Para cada chave: expande e confere as 11 chaves de rodada.
        $display("-- 3. %0d chaves x 11 chaves de rodada (modelo de referencia)", N_KEYS);
        if (!$value$plusargs("VEC_DIR=%s", vec_dir)) vec_dir = "tb/vectors";
        $readmemh({vec_dir, "/aes128_key_exp.hex"}, kv);
        if (kv[11*N_KEYS-1] === 128'hx) begin
            errors++;
            $display("ERRO: aes128_key_exp.hex incompleto ou nao encontrado em %s", vec_dir);
        end
        for (int k = 0; k < N_KEYS; k++) begin
            expand($sformatf("chave %0d", k), kv[11*k]);   // kv[11k] = rk0 = a chave
            for (int r = 0; r <= 10; r++) begin
                read_rk(r, got);
                check($sformatf("chave %0d rk%0d", k, r), got, kv[11*k+r]);
            end
        end
        $display("%0d chaves conferidas", N_KEYS);

        // 4 e 5. recarga e reset no meio da expansao
        // Comeca uma expansao, aplica reset 3 ciclos depois e confere que
        // ready fica em 0 (e continua em 0 sem nova carga). Depois recarrega.
        $display("-- 4/5. recarga e reset durante a expansao");
        @(negedge clk);
        load = 1'b1;
        key  = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        @(negedge clk);
        load = 1'b0;
        repeat (3) @(negedge clk);
        rst_n = 1'b0;                       // reset no meio da expansao
        @(negedge clk);
        check_int("ready durante o reset", int'(ready), 0);
        rst_n = 1'b1;
        repeat (15) @(negedge clk);
        check_int("ready continua em 0 sem nova carga", int'(ready), 0);
        expand("recarga apos reset", 128'h2b7e151628aed2a6abf7158809cf4f3c);
        read_rk(10, got); check("recarga: rk10", got, 128'hd014f9a8c9ee2589e13f0cc8b6630ca6);

        $display("tb_minisoc_aes_key_exp: valores do padrao + %0d chaves x 11 chaves de rodada + latencia e reset, %0d checagens, %0d erro(s)",
                 N_KEYS, checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

    // ---------------- guarda contra travamento ----------------
    // Se algo prender a simulacao (ex.: ready nunca sobe), este bloco encerra
    // tudo em 1 ms de tempo simulado e marca o teste como falho.
    initial begin   // guarda contra travamento
        #1_000_000;   // 1 ms
        $display("ERRO: tempo esgotado");
        $display("TEST FAILED");
        $finish;
    end

endmodule : tb_minisoc_aes_key_exp

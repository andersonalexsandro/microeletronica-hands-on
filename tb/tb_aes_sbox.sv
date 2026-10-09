// ============================================================================
// tb_aes_sbox - testbench self-checking do exemplo minimo (aes_sbox)
// ----------------------------------------------------------------------------
// Varre as 256 entradas e compara a saida do DUT com a S-box calculada aqui
// pela definicao do FIPS-197 (5.1.1): inverso multiplicativo em GF(2^8)
// seguido da transformacao afim. Assim a tabela do RTL e conferida contra a
// matematica, e nao contra uma copia de si mesma. Confere tambem os valores
// citados no texto do padrao.
//
// Saida: imprime "TEST PASSED" ou "TEST FAILED"; o Makefile decide pelo log.
// ============================================================================
module tb_aes_sbox;

    logic [7:0] data_i;
    logic [7:0] data_o;
    int         errors = 0;

    aes_sbox dut (
        .data_i (data_i),
        .data_o (data_o)
    );

    // ---------------- modelo de referencia (GF(2^8), m(x) = 0x11B) ----------
    function automatic logic [7:0] xtime(input logic [7:0] b);
        return {b[6:0], 1'b0} ^ (b[7] ? 8'h1b : 8'h00);
    endfunction

    function automatic logic [7:0] gmul(input logic [7:0] a, input logic [7:0] b);
        logic [7:0] p;
        p = 8'h00;
        for (int i = 0; i < 8; i++) begin
            if (b[i]) p = p ^ a;
            a = xtime(a);
        end
        return p;
    endfunction

    // b^254 = b^-1 (b^255 = 1); para b = 0 o resultado ja sai 0, como define o padrao
    function automatic logic [7:0] ginv(input logic [7:0] b);
        logic [7:0] r;
        r = 8'h01;
        for (int i = 0; i < 254; i++) r = gmul(r, b);
        return r;
    endfunction

    function automatic logic [7:0] rotl(input logic [7:0] b, input int n);
        return (b << n) | (b >> (8 - n));
    endfunction

    function automatic logic [7:0] ref_sbox(input logic [7:0] x);
        logic [7:0] b;
        b = ginv(x);
        return b ^ rotl(b, 1) ^ rotl(b, 2) ^ rotl(b, 3) ^ rotl(b, 4) ^ 8'h63;
    endfunction

    task automatic check(input logic [7:0] x, input logic [7:0] expected);
        data_i = x;
        #1;
        if (data_o !== expected) begin
            errors++;
            $display("ERRO: S(%02h) = %02h, esperado %02h", x, data_o, expected);
        end
    endtask

    initial begin
`ifdef FSDB
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_aes_sbox);
`else
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_aes_sbox);
`endif

        // valores citados no FIPS-197 (5.1.1 e Figura 7)
        check(8'h00, 8'h63);
        check(8'h53, 8'hed);
        check(8'hff, 8'h16);

        // varredura exaustiva contra a definicao matematica
        for (int x = 0; x < 256; x++) check(x[7:0], ref_sbox(x[7:0]));

        $display("tb_aes_sbox: 3 valores do padrao + 256 entradas verificadas, %0d erro(s)", errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

endmodule : tb_aes_sbox

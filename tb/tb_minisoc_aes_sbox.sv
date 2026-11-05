// ============================================================================
// tb_minisoc_aes_sbox - testbench self-checking da S-box e da S-box inversa
// ----------------------------------------------------------------------------
// Confere:
//   1. os valores citados no FIPS-197: S(00) = 63 e S(53) = ed, e os
//      correspondentes da inversa, InvS(63) = 00 e InvS(ed) = 53;
//   2. as 256 entradas da S-box contra a tabela de referencia sbox.hex;
//   3. (opcional da semana 2) as 256 entradas da S-box inversa contra
//      inv_sbox.hex e a propriedade InvS(S(x)) = x para todo x.
//
// As tabelas de referencia sao geradas pelo modelo scripts/aes_ref.py
// (make vectors), que calcula a S-box pela definicao matematica. O diretorio
// delas vem do plusarg +VEC_DIR=<dir>, que o Makefile passa ao simulador.
//
// Saida: imprime "TEST PASSED" ou "TEST FAILED"; o Makefile decide pelo log.
// ============================================================================
module tb_minisoc_aes_sbox;

    logic [7:0] x;          // estimulo, comum aos dois DUTs
    logic [7:0] s;          // S(x)
    logic [7:0] inv_s;      // InvS(x)
    logic [7:0] inv_of_s;   // InvS(S(x)): tem que voltar a ser x

    minisoc_aes_sbox     dut_sbox     (.data_i(x), .data_o(s));
    minisoc_aes_inv_sbox dut_inv_sbox (.data_i(x), .data_o(inv_s));
    minisoc_aes_inv_sbox dut_inv_of_s (.data_i(s), .data_o(inv_of_s));

    logic [7:0] sbox_ref     [256];   // linha x do arquivo = valor esperado para x
    logic [7:0] inv_sbox_ref [256];

    string vec_dir;
    int    checks = 0;
    int    errors = 0;

    // Compara com !== (e nao !=): assim um X ou Z na saida tambem conta como erro
    task automatic check(input string what, input logic [7:0] got, input logic [7:0] expected);
        checks++;
        if (got !== expected) begin
            errors++;
            $display("ERRO: %s = %02h, esperado %02h", what, got, expected);
        end
    endtask

    initial begin
`ifdef FSDB
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_minisoc_aes_sbox);
`else
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_minisoc_aes_sbox);
`endif

        if (!$value$plusargs("VEC_DIR=%s", vec_dir)) vec_dir = "tb/vectors";
        $readmemh({vec_dir, "/sbox.hex"}, sbox_ref);
        $readmemh({vec_dir, "/inv_sbox.hex"}, inv_sbox_ref);
        if (sbox_ref[255] === 8'hxx || inv_sbox_ref[255] === 8'hxx) begin
            errors++;
            $display("ERRO: tabelas de referencia incompletas ou nao encontradas em %s", vec_dir);
        end

        // 1. valores citados no texto do padrao (independentes do modelo)
        x = 8'h00; #1; check("S(00)",    s,     8'h63);
        x = 8'h53; #1; check("S(53)",    s,     8'hed);
        x = 8'h63; #1; check("InvS(63)", inv_s, 8'h00);
        x = 8'hed; #1; check("InvS(ed)", inv_s, 8'h53);

        // 2 e 3. varredura exaustiva: as 256 entradas possiveis de um byte
        for (int i = 0; i < 256; i++) begin
            x = i[7:0];
            #1;  // a logica e combinacional: basta deixar o valor propagar
            check($sformatf("S(%02h)", x),       s,        sbox_ref[i]);
            check($sformatf("InvS(%02h)", x),    inv_s,    inv_sbox_ref[i]);
            check($sformatf("InvS(S(%02h))", x), inv_of_s, x);
        end

        $display("tb_minisoc_aes_sbox: 4 valores do padrao + 256 entradas (S, InvS e InvS(S(x)) = x), %0d checagens, %0d erro(s)",
                 checks, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $display("TEST FAILED");
        $finish;
    end

endmodule : tb_minisoc_aes_sbox

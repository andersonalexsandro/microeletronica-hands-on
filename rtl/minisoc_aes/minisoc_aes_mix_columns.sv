// ============================================================================
// minisoc_aes_mix_columns - transformacao MixColumns (FIPS-197, secao 5.1.3)
// ----------------------------------------------------------------------------
// Cada coluna (a0, a1, a2, a3) do estado e multiplicada, em GF(2^8), pela
// matriz fixa
//
//   | b0 |   | 02 03 01 01 |   | a0 |
//   | b1 | = | 01 02 03 01 | . | a1 |
//   | b2 |   | 01 01 02 03 |   | a2 |
//   | b3 |   | 03 01 01 02 |   | a3 |
//
// Em GF(2^8) a soma e XOR, {02}.a e o xtime(a) e {03}.a = xtime(a) ^ a.
// O bloco inteiro e uma rede de XORs: nao ha multiplicador. Combinacional.
//
// Convencao do estado: a coluna c e a palavra state[127-32c -: 32], com a
// linha 0 nos bits mais altos (byte n = r + 4c em state[127-8n -: 8]).
// ============================================================================
module minisoc_aes_mix_columns (
    input  logic [127:0] state_i,   // estado de entrada
    output logic [127:0] state_o    // estado com as colunas misturadas
);

    // {02}.b: desloca 1 bit a esquerda; se o bit 7 era 1, reduz com 0x1B
    function automatic logic [7:0] xtime(input logic [7:0] b);
        return {b[6:0], 1'b0} ^ (b[7] ? 8'h1b : 8'h00);
    endfunction

    for (genvar c = 0; c < 4; c++) begin : g_col
        logic [7:0] a0, a1, a2, a3;   // linhas 0 a 3 da coluna c
        assign {a0, a1, a2, a3} = state_i[127-32*c -: 32];

        assign state_o[127-32*c -: 32] = {
            xtime(a0) ^ (xtime(a1) ^ a1) ^ a2 ^ a3,     // 02.a0 ^ 03.a1 ^ a2 ^ a3
            a0 ^ xtime(a1) ^ (xtime(a2) ^ a2) ^ a3,     // a0 ^ 02.a1 ^ 03.a2 ^ a3
            a0 ^ a1 ^ xtime(a2) ^ (xtime(a3) ^ a3),     // a0 ^ a1 ^ 02.a2 ^ 03.a3
            (xtime(a0) ^ a0) ^ a1 ^ a2 ^ xtime(a3)      // 03.a0 ^ a1 ^ a2 ^ 02.a3
        };
    end

endmodule : minisoc_aes_mix_columns

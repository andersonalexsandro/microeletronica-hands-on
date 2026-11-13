// ============================================================================
// minisoc_aes_inv_mix_columns - transformacao InvMixColumns (FIPS-197, 5.3.3)
// ----------------------------------------------------------------------------
// Inversa do MixColumns: cada coluna e multiplicada pela matriz
//
//   | 0e 0b 0d 09 |
//   | 09 0e 0b 0d |
//   | 0d 09 0e 0b |
//   | 0b 0d 09 0e |
//
// Os coeficientes saem de potencias de {02}: com x2 = xtime(a), x4 = xtime(x2)
// e x8 = xtime(x4),
//   {09}.a = x8 ^ a        {0b}.a = x8 ^ x2 ^ a
//   {0d}.a = x8 ^ x4 ^ a   {0e}.a = x8 ^ x4 ^ x2
// A rede de XORs e mais profunda que a do MixColumns: por isso o caminho da
// decifragem tende a ser o caminho critico do datapath. Combinacional.
// Mesma convencao do estado do minisoc_aes_mix_columns.
// ============================================================================
module minisoc_aes_inv_mix_columns (
    input  logic [127:0] state_i,   // estado de entrada
    output logic [127:0] state_o    // estado com as colunas desmisturadas
);

    function automatic logic [7:0] xtime(input logic [7:0] b);
        return {b[6:0], 1'b0} ^ (b[7] ? 8'h1b : 8'h00);
    endfunction

    function automatic logic [7:0] mul_09(input logic [7:0] b);
        return xtime(xtime(xtime(b))) ^ b;
    endfunction

    function automatic logic [7:0] mul_0b(input logic [7:0] b);
        return xtime(xtime(xtime(b))) ^ xtime(b) ^ b;
    endfunction

    function automatic logic [7:0] mul_0d(input logic [7:0] b);
        return xtime(xtime(xtime(b))) ^ xtime(xtime(b)) ^ b;
    endfunction

    function automatic logic [7:0] mul_0e(input logic [7:0] b);
        return xtime(xtime(xtime(b))) ^ xtime(xtime(b)) ^ xtime(b);
    endfunction

    for (genvar c = 0; c < 4; c++) begin : g_col
        logic [7:0] a0, a1, a2, a3;   // linhas 0 a 3 da coluna c
        assign {a0, a1, a2, a3} = state_i[127-32*c -: 32];

        assign state_o[127-32*c -: 32] = {
            mul_0e(a0) ^ mul_0b(a1) ^ mul_0d(a2) ^ mul_09(a3),
            mul_09(a0) ^ mul_0e(a1) ^ mul_0b(a2) ^ mul_0d(a3),
            mul_0d(a0) ^ mul_09(a1) ^ mul_0e(a2) ^ mul_0b(a3),
            mul_0b(a0) ^ mul_0d(a1) ^ mul_09(a2) ^ mul_0e(a3)
        };
    end

endmodule : minisoc_aes_inv_mix_columns

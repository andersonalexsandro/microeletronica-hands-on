// ============================================================================
// minisoc_aes_mix_columns - MixColumns do AES
// ============================================================================
// O QUE E
//   Mistura os 4 bytes de cada coluna: cada byte de saida depende dos
//   4 bytes da sua coluna. Para a coluna a0 a1 a2 a3:
//     b0 = 2.a0 ^ 3.a1 ^   a2 ^   a3
//     b1 =   a0 ^ 2.a1 ^ 3.a2 ^   a3
//     b2 =   a0 ^   a1 ^ 2.a2 ^ 3.a3
//     b3 = 3.a0 ^   a1 ^   a2 ^ 2.a3
//   "^" e XOR. 2.a = desloca 1 bit para a esquerda e, se o bit que saiu
//   era 1, faz XOR com 1b. 3.a = 2.a ^ a. Nao ha multiplicador: so XOR.
//   Ex.: coluna d4 bf 5d 30 -> 04 66 81 e5.
//
// ENTRADAS E SAIDAS
//   state_i [127:0]  entrada  estado em 4 colunas de 32 bits: coluna 0 em
//                             [127:96], coluna 1 em [95:64], coluna 2 em
//                             [63:32], coluna 3 em [31:0]
//   state_o [127:0]  saida    as 4 colunas misturadas, nas mesmas posicoes
// ============================================================================
module minisoc_aes_mix_columns (
    input  logic [127:0] state_i,
    output logic [127:0] state_o
);

    // ---------------- 2.a (xtime) ----------------
    // Desloca 1 bit para a esquerda; se o bit 7 era 1, faz XOR com 1b.
    function automatic logic [7:0] xtime(input logic [7:0] b);
        return {b[6:0], 1'b0} ^ (b[7] ? 8'h1b : 8'h00);
    endfunction

    // ---------------- uma copia por coluna (c = 0 a 3) ----------------
    for (genvar c = 0; c < 4; c++) begin : g_col
        logic [7:0] a0, a1, a2, a3;   // os 4 bytes da coluna c (linhas 0 a 3)

        assign {a0, a1, a2, a3} = state_i[127-32*c -: 32];

        // 3.a aparece como (xtime(a) ^ a)
        assign state_o[127-32*c -: 32] = {
            xtime(a0) ^ (xtime(a1) ^ a1) ^ a2 ^ a3,     // b0
            a0 ^ xtime(a1) ^ (xtime(a2) ^ a2) ^ a3,     // b1
            a0 ^ a1 ^ xtime(a2) ^ (xtime(a3) ^ a3),     // b2
            (xtime(a0) ^ a0) ^ a1 ^ a2 ^ xtime(a3)      // b3
        };
    end

endmodule : minisoc_aes_mix_columns

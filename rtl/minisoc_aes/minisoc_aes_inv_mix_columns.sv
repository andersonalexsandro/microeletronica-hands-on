// ============================================================================
// minisoc_aes_inv_mix_columns - InvMixColumns do AES
// ============================================================================
// O QUE E
//   Desfaz o MixColumns. Mesma ideia, com outros multiplicadores:
//     b0 = e.a0 ^ b.a1 ^ d.a2 ^ 9.a3   (e, b, d, 9 em hexadecimal)
//     b1 = 9.a0 ^ e.a1 ^ b.a2 ^ d.a3
//     b2 = d.a0 ^ 9.a1 ^ e.a2 ^ b.a3
//     b3 = b.a0 ^ d.a1 ^ 9.a2 ^ e.a3
//   Cada multiplicacao e feita com 2.a repetido e XOR:
//     9.a = 8.a ^ a    b.a = 8.a ^ 2.a ^ a
//     d.a = 8.a ^ 4.a ^ a    e.a = 8.a ^ 4.a ^ 2.a
//   onde 4.a = 2.(2.a) e 8.a = 2.(2.(2.a)).
//   Ex.: coluna 04 66 81 e5 -> d4 bf 5d 30.
//
// ENTRADAS E SAIDAS
//   state_i [127:0]  entrada  estado em 4 colunas de 32 bits: coluna 0 em
//                             [127:96], ..., coluna 3 em [31:0]
//   state_o [127:0]  saida    as 4 colunas desmisturadas, nas mesmas posicoes
// ============================================================================
module minisoc_aes_inv_mix_columns (
    input  logic [127:0] state_i,
    output logic [127:0] state_o
);

    // ---------------- 2.a (xtime) e os multiplicadores ----------------
    // 2.a: desloca 1 bit para a esquerda; se o bit 7 era 1, faz XOR com 1b.
    function automatic logic [7:0] xtime(input logic [7:0] b);
        return {b[6:0], 1'b0} ^ (b[7] ? 8'h1b : 8'h00);
    endfunction

    function automatic logic [7:0] mul_09(input logic [7:0] b);   // 9 = 8 + 1
        return xtime(xtime(xtime(b))) ^ b;
    endfunction

    function automatic logic [7:0] mul_0b(input logic [7:0] b);   // b = 8 + 2 + 1
        return xtime(xtime(xtime(b))) ^ xtime(b) ^ b;
    endfunction

    function automatic logic [7:0] mul_0d(input logic [7:0] b);   // d = 8 + 4 + 1
        return xtime(xtime(xtime(b))) ^ xtime(xtime(b)) ^ b;
    endfunction

    function automatic logic [7:0] mul_0e(input logic [7:0] b);   // e = 8 + 4 + 2
        return xtime(xtime(xtime(b))) ^ xtime(xtime(b)) ^ xtime(b);
    endfunction

    // ---------------- uma copia por coluna (c = 0 a 3) ----------------
    for (genvar c = 0; c < 4; c++) begin : g_col
        logic [7:0] a0, a1, a2, a3;   // os 4 bytes da coluna c (linhas 0 a 3)
        assign {a0, a1, a2, a3} = state_i[127-32*c -: 32];

        assign state_o[127-32*c -: 32] = {
            mul_0e(a0) ^ mul_0b(a1) ^ mul_0d(a2) ^ mul_09(a3),   // b0
            mul_09(a0) ^ mul_0e(a1) ^ mul_0b(a2) ^ mul_0d(a3),   // b1
            mul_0d(a0) ^ mul_09(a1) ^ mul_0e(a2) ^ mul_0b(a3),   // b2
            mul_0b(a0) ^ mul_0d(a1) ^ mul_09(a2) ^ mul_0e(a3)    // b3
        };
    end

endmodule : minisoc_aes_inv_mix_columns

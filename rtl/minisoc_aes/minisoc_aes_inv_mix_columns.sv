// ============================================================================
// minisoc_aes_inv_mix_columns - transformacao InvMixColumns (FIPS-197, 5.3.3)
// ----------------------------------------------------------------------------
// O QUE FAZ
//   Desfaz o MixColumns: multiplica cada coluna, em GF(2^8), pela matriz
//   inversa
//
//     | 0e 0b 0d 09 |
//     | 09 0e 0b 0d |
//     | 0d 09 0e 0b |
//     | 0b 0d 09 0e |
//
//   Vale InvMixColumns(MixColumns(x)) = x para qualquer estado x.
//
// COMO OS COEFICIENTES VIRAM XOR
//   Todos saem de potencias de {02}. Com x2 = xtime(a), x4 = xtime(x2) e
//   x8 = xtime(x4) (ou seja, a vezes 2, 4 e 8 em GF(2^8)):
//     {09}.a = x8 ^ a              (8 + 1)
//     {0b}.a = x8 ^ x2 ^ a         (8 + 2 + 1)
//     {0d}.a = x8 ^ x4 ^ a         (8 + 4 + 1)
//     {0e}.a = x8 ^ x4 ^ x2        (8 + 4 + 2)
//   ("+" em GF(2^8) e XOR.)
//
// POR QUE E MAIS LENTO QUE O MIXCOLUMNS
//   O x8 precisa de 3 xtime em cadeia, e depois ainda ha a soma de 4 termos.
//   A rede de XORs e mais profunda, por isso a rodada da cifra inversa deve
//   ser o CAMINHO CRITICO do datapath (o caminho mais lento entre registradores).
//
// ONDE FICA NO PROJETO
//   Semana 3. Usado pelo minisoc_aes_dp nas rodadas da cifra inversa, menos
//   na ultima. Mesma convencao do estado do minisoc_aes_mix_columns.
// ============================================================================
module minisoc_aes_inv_mix_columns (
    input  logic [127:0] state_i,   // estado de entrada
    output logic [127:0] state_o    // estado com as colunas desmisturadas
);

    // ---------------- funcoes de multiplicacao em GF(2^8) ----------------
    // xtime: multiplicar por {02} (desloca 1 bit; reduz com 0x1B se o bit 7
    // era 1). As outras funcoes combinam xtime em cadeia:
    //   xtime(b)               = 2.b
    //   xtime(xtime(b))        = 4.b
    //   xtime(xtime(xtime(b))) = 8.b
    // A sintese reaproveita os resultados comuns (o 8.b de mul_09 e o mesmo
    // de mul_0b), entao escrever assim nao multiplica a area.
    function automatic logic [7:0] xtime(input logic [7:0] b);
        return {b[6:0], 1'b0} ^ (b[7] ? 8'h1b : 8'h00);
    endfunction

    function automatic logic [7:0] mul_09(input logic [7:0] b);   // 9 = 8 + 1
        return xtime(xtime(xtime(b))) ^ b;
    endfunction

    function automatic logic [7:0] mul_0b(input logic [7:0] b);   // 11 = 8 + 2 + 1
        return xtime(xtime(xtime(b))) ^ xtime(b) ^ b;
    endfunction

    function automatic logic [7:0] mul_0d(input logic [7:0] b);   // 13 = 8 + 4 + 1
        return xtime(xtime(xtime(b))) ^ xtime(xtime(b)) ^ b;
    endfunction

    function automatic logic [7:0] mul_0e(input logic [7:0] b);   // 14 = 8 + 4 + 2
        return xtime(xtime(xtime(b))) ^ xtime(xtime(b)) ^ xtime(b);
    endfunction

    // ---------------- uma coluna por vez ----------------
    // Igual ao MixColumns: 4 copias (uma por coluna), cada uma separa os 4
    // bytes da sua coluna e calcula as 4 linhas da matriz inversa.
    for (genvar c = 0; c < 4; c++) begin : g_col
        logic [7:0] a0, a1, a2, a3;   // linhas 0 a 3 da coluna c
        assign {a0, a1, a2, a3} = state_i[127-32*c -: 32];

        // Linha i da saida = soma (XOR) dos 4 bytes multiplicados pela linha
        // i da matriz inversa. b0 fica nos bits mais altos da palavra.
        assign state_o[127-32*c -: 32] = {
            mul_0e(a0) ^ mul_0b(a1) ^ mul_0d(a2) ^ mul_09(a3),   // b0: 0e 0b 0d 09
            mul_09(a0) ^ mul_0e(a1) ^ mul_0b(a2) ^ mul_0d(a3),   // b1: 09 0e 0b 0d
            mul_0d(a0) ^ mul_09(a1) ^ mul_0e(a2) ^ mul_0b(a3),   // b2: 0d 09 0e 0b
            mul_0b(a0) ^ mul_0d(a1) ^ mul_09(a2) ^ mul_0e(a3)    // b3: 0b 0d 09 0e
        };
    end

endmodule : minisoc_aes_inv_mix_columns

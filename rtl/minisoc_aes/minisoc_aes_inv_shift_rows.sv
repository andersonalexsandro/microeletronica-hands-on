// ============================================================================
// minisoc_aes_inv_shift_rows - InvShiftRows do AES
// ============================================================================
// O QUE E
//   Desfaz o ShiftRows: gira cada linha da tabela 4x4 para a DIREITA.
//     linha 0: fica       linha 1: gira 1 casa
//     linha 2: gira 2     linha 3: gira 3
//   Os bytes nao mudam de valor, so de lugar. Em hardware sao so fios.
//
// ENTRADAS E SAIDAS
//   state_i [127:0]  entrada  estado com 16 bytes (byte 0 em [127:120],
//                             byte 15 em [7:0])
//   state_o [127:0]  saida    os mesmos 16 bytes, de volta as posicoes
//                             de antes do ShiftRows
// ============================================================================
module minisoc_aes_inv_shift_rows (
    input  logic [127:0] state_i,
    output logic [127:0] state_o
);

    // Para cada posicao de saida (linha r, coluna c), pega o byte da mesma
    // linha, coluna (c - r) mod 4 da entrada. Soma-se 4 antes do mod para
    // a conta nunca ficar negativa. O byte da linha r, coluna c e o r + 4*c.
    for (genvar c = 0; c < 4; c++) begin : g_col
        for (genvar r = 0; r < 4; r++) begin : g_row
            assign state_o[127-8*(r+4*c) -: 8] = state_i[127-8*(r+4*((c+4-r)%4)) -: 8];
        end
    end

endmodule : minisoc_aes_inv_shift_rows

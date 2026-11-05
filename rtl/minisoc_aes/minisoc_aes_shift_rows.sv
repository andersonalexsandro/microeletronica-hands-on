// ============================================================================
// minisoc_aes_shift_rows - transformacao ShiftRows (FIPS-197, secao 5.1.2)
// ----------------------------------------------------------------------------
// A linha r do estado gira r posicoes para a esquerda (a linha 0 nao muda):
//
//   s'[r][c] = s[r][(c + r) mod 4]
//
// Convencao do estado (Block Guide; FIPS-197, secao 3.4):
//   byte n em state[127-8n -: 8], com n = r + 4c
//
// Mapa resultante (byte de saida <- byte de entrada):
//   saida  :  0  1  2  3 |  4  5  6  7 |  8  9 10 11 | 12 13 14 15
//   entrada:  0  5 10 15 |  4  9 14  3 |  8 13  2  7 | 12  1  6 11
//
// E apenas reordenacao de fios: nao gera nenhuma porta logica.
// ============================================================================
module minisoc_aes_shift_rows (
    input  logic [127:0] state_i,   // estado de entrada
    output logic [127:0] state_o    // estado com as linhas giradas
);

    for (genvar c = 0; c < 4; c++) begin : g_col
        for (genvar r = 0; r < 4; r++) begin : g_row
            // byte de saida (r + 4c) <- byte de entrada (r + 4*((c + r) mod 4))
            assign state_o[127-8*(r+4*c) -: 8] = state_i[127-8*(r+4*((c+r)%4)) -: 8];
        end
    end

endmodule : minisoc_aes_shift_rows

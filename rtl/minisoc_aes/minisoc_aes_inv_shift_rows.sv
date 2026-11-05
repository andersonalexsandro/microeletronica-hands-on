// ============================================================================
// minisoc_aes_inv_shift_rows - transformacao InvShiftRows (FIPS-197, secao 5.3.1)
// ----------------------------------------------------------------------------
// Inversa do ShiftRows: a linha r gira r posicoes para a DIREITA.
//
//   s'[r][c] = s[r][(c - r) mod 4]   (escrito como (c + 4 - r) mod 4)
//
// Mesma convencao do estado do minisoc_aes_shift_rows (byte n = r + 4c).
// Mapa resultante (byte de saida <- byte de entrada):
//   saida  :  0  1  2  3 |  4  5  6  7 |  8  9 10 11 | 12 13 14 15
//   entrada:  0 13 10  7 |  4  1 14 11 |  8  5  2 15 | 12  9  6  3
//
// Apenas reordenacao de fios, como o ShiftRows.
// ============================================================================
module minisoc_aes_inv_shift_rows (
    input  logic [127:0] state_i,   // estado de entrada
    output logic [127:0] state_o    // estado com as linhas desgiradas
);

    for (genvar c = 0; c < 4; c++) begin : g_col
        for (genvar r = 0; r < 4; r++) begin : g_row
            // byte de saida (r + 4c) <- byte de entrada (r + 4*((c + 4 - r) mod 4))
            assign state_o[127-8*(r+4*c) -: 8] = state_i[127-8*(r+4*((c+4-r)%4)) -: 8];
        end
    end

endmodule : minisoc_aes_inv_shift_rows

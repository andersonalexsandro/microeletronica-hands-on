// ============================================================================
// minisoc_aes_sub_bytes - SubBytes do AES
// ============================================================================
// O QUE E
//   Passa cada um dos 16 bytes do estado pela S-box.
//   Cada byte e trocado sozinho e fica na mesma posicao.
//   Ex.: byte 0 = 19 -> sai d4; byte 1 = 3d -> sai 27.
//
// ENTRADAS E SAIDAS
//   state_i [127:0]  entrada  estado com 16 bytes (byte 0 em [127:120],
//                             byte 15 em [7:0])
//   state_o [127:0]  saida    os 16 bytes ja trocados, nas mesmas posicoes
// ============================================================================
module minisoc_aes_sub_bytes (
    input  logic [127:0] state_i,
    output logic [127:0] state_o
);

    // 16 S-boxes, uma por byte (n = 0 a 15).
    // O "for (genvar ...)" cria 16 copias do hardware; nao e um laco no tempo.
    for (genvar n = 0; n < 16; n++) begin : g_sbox
        minisoc_aes_sbox u_sbox (
            .data_i (state_i[127-8*n -: 8]),   // byte n da entrada
            .data_o (state_o[127-8*n -: 8])    // byte n da saida
        );
    end

endmodule : minisoc_aes_sub_bytes

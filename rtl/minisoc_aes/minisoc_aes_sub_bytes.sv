// ============================================================================
// minisoc_aes_sub_bytes - transformacao SubBytes (FIPS-197, secao 5.1.1)
// ----------------------------------------------------------------------------
// Aplica a S-box a cada um dos 16 bytes do estado, de forma independente:
// 16 instancias de minisoc_aes_sbox lado a lado. Puramente combinacional.
//
// Convencao do estado (Block Guide; FIPS-197, secao 3.4):
//   byte n em state[127-8n -: 8]  ->  byte 0 em [127:120], byte 15 em [7:0]
//   byte n = s[r][c], com r = n mod 4 (linha) e c = n div 4 (coluna)
// Como o SubBytes trata cada byte isoladamente, nenhum byte muda de posicao.
// ============================================================================
module minisoc_aes_sub_bytes (
    input  logic [127:0] state_i,   // estado de entrada
    output logic [127:0] state_o    // estado com cada byte substituido
);

    for (genvar n = 0; n < 16; n++) begin : g_sbox
        minisoc_aes_sbox u_sbox (
            .data_i (state_i[127-8*n -: 8]),
            .data_o (state_o[127-8*n -: 8])
        );
    end

endmodule : minisoc_aes_sub_bytes

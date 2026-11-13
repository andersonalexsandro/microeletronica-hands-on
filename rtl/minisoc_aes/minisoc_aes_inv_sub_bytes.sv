// ============================================================================
// minisoc_aes_inv_sub_bytes - transformacao InvSubBytes (FIPS-197, secao 5.3.2)
// ----------------------------------------------------------------------------
// O QUE FAZ
//   E a inversa do SubBytes: troca cada um dos 16 bytes pelo valor da S-box
//   INVERSA. Vale InvSubBytes(SubBytes(x)) = x para qualquer estado x.
//
// ONDE FICA NO PROJETO
//   - Semana 2 (opcional da semana) e semana 3 (transformacoes inversas).
//   - Usado pelo minisoc_aes_dp (semana 4), dentro da rodada da cifra
//     inversa, que so e usada para decifrar nos modos ECB, CBC e PCBC.
//
// NO QUE VIRA EM HARDWARE
//   16 instancias de minisoc_aes_inv_sbox, combinacionais, lado a lado.
//   Mesma estrutura e mesma convencao do estado do minisoc_aes_sub_bytes
//   (byte n em state[127-8n -: 8]).
// ============================================================================
module minisoc_aes_inv_sub_bytes (
    input  logic [127:0] state_i,   // estado de entrada (16 bytes)
    output logic [127:0] state_o    // estado com InvS(byte) em cada posicao
);

    // ---------------- 16 S-boxes inversas, uma por byte ----------------
    // Mesmo generate do SubBytes: 16 copias criadas na elaboracao, com os
    // nomes g_inv_sbox[0].u_inv_sbox ... g_inv_sbox[15].u_inv_sbox.
    for (genvar n = 0; n < 16; n++) begin : g_inv_sbox
        minisoc_aes_inv_sbox u_inv_sbox (
            .data_i (state_i[127-8*n -: 8]),   // byte n da entrada
            .data_o (state_o[127-8*n -: 8])    // byte n da saida = InvS(byte n)
        );
    end

endmodule : minisoc_aes_inv_sub_bytes

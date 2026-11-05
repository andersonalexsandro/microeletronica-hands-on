// ============================================================================
// minisoc_aes_inv_sub_bytes - transformacao InvSubBytes (FIPS-197, secao 5.3.2)
// ----------------------------------------------------------------------------
// Inversa do SubBytes: aplica a S-box inversa a cada um dos 16 bytes do
// estado (16 instancias de minisoc_aes_inv_sbox). Puramente combinacional.
// Mesma convencao do estado do minisoc_aes_sub_bytes.
// ============================================================================
module minisoc_aes_inv_sub_bytes (
    input  logic [127:0] state_i,   // estado de entrada
    output logic [127:0] state_o    // estado com cada byte des-substituido
);

    for (genvar n = 0; n < 16; n++) begin : g_inv_sbox
        minisoc_aes_inv_sbox u_inv_sbox (
            .data_i (state_i[127-8*n -: 8]),
            .data_o (state_o[127-8*n -: 8])
        );
    end

endmodule : minisoc_aes_inv_sub_bytes

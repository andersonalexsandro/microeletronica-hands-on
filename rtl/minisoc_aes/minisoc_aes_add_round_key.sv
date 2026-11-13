// ============================================================================
// minisoc_aes_add_round_key - transformacao AddRoundKey (FIPS-197, 5.1.4)
// ----------------------------------------------------------------------------
// XOR bit a bit do estado com a chave da rodada: 128 portas XOR. E a sua
// propria inversa (x ^ k ^ k = x), por isso serve tanto a cifra quanto a
// cifra inversa (FIPS-197, 5.3.4). Combinacional.
// ============================================================================
module minisoc_aes_add_round_key (
    input  logic [127:0] state_i,       // estado de entrada
    input  logic [127:0] round_key_i,   // chave da rodada
    output logic [127:0] state_o        // state_i ^ round_key_i
);

    assign state_o = state_i ^ round_key_i;

endmodule : minisoc_aes_add_round_key

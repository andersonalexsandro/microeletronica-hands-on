// ============================================================================
// minisoc_aes_add_round_key - transformacao AddRoundKey (FIPS-197, 5.1.4)
// ----------------------------------------------------------------------------
// O QUE FAZ
//   Faz o XOR (ou exclusivo) bit a bit do estado com a chave da rodada.
//   E o UNICO passo do AES em que a chave entra no calculo.
//
// POR QUE SERVE AOS DOIS SENTIDOS
//   O XOR e a sua propria inversa: (x ^ k) ^ k = x. Por isso o mesmo modulo
//   e usado na cifra e na cifra inversa (FIPS-197, secao 5.3.4).
//
// ONDE FICA NO PROJETO
//   Semana 3. O minisoc_aes_dp usa 3 instancias: na carga do bloco
//   (AddRoundKey inicial), na rodada da cifra e na rodada da inversa.
//
// NO QUE VIRA EM HARDWARE
//   128 portas XOR de 2 entradas, uma por bit. Combinacional.
// ============================================================================
module minisoc_aes_add_round_key (
    input  logic [127:0] state_i,       // estado de entrada
    input  logic [127:0] round_key_i,   // chave da rodada (rk0 ... rk10)
    output logic [127:0] state_o        // state_i ^ round_key_i
);

    // ---------------- XOR com a chave ----------------
    // O operador "^" entre dois vetores de 128 bits faz 128 XORs de uma vez:
    // state_o[i] = state_i[i] ^ round_key_i[i], para i = 0 ... 127.
    assign state_o = state_i ^ round_key_i;

endmodule : minisoc_aes_add_round_key

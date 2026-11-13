// ============================================================================
// minisoc_aes_add_round_key - AddRoundKey do AES
// ============================================================================
// O QUE E
//   Junta a chave da rodada ao estado com XOR, bit a bit (128 portas XOR).
//   E a unica etapa que usa a chave. Fazer XOR de novo com a mesma chave
//   desfaz a conta, por isso o mesmo bloco serve para cifrar e decifrar.
//   Ex.: byte 32 com chave 2b -> 32 ^ 2b = 19.
//
// ENTRADAS E SAIDAS
//   state_i     [127:0]  entrada  estado
//   round_key_i [127:0]  entrada  chave da rodada (rk0 a rk10)
//   state_o     [127:0]  saida    state_i ^ round_key_i
// ============================================================================
module minisoc_aes_add_round_key (
    input  logic [127:0] state_i,
    input  logic [127:0] round_key_i,
    output logic [127:0] state_o
);

    assign state_o = state_i ^ round_key_i;

endmodule : minisoc_aes_add_round_key

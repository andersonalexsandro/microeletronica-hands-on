// ============================================================================
// aes_sbox - S-box do AES (SubBytes de 1 byte), puramente combinacional
// ----------------------------------------------------------------------------
// Exemplo minimo da semana 1: exercita o fluxo compilacao -> lint -> simulacao
// com um package e um modulo. Sera reaproveitado no SubBytes (16 instancias)
// e no SubWord da expansao de chave (4 instancias).
// ============================================================================
module aes_sbox
    import aes_pkg::*;
(
    input  logic [7:0] data_i,
    output logic [7:0] data_o
);

    assign data_o = sbox(data_i);

endmodule : aes_sbox

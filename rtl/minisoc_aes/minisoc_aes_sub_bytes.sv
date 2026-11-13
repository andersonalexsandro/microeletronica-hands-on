// ============================================================================
// minisoc_aes_sub_bytes - transformacao SubBytes do AES (FIPS-197, secao 5.1.1)
// ----------------------------------------------------------------------------
// O QUE FAZ
//   Troca cada um dos 16 bytes do estado pelo valor correspondente da S-box.
//   Cada byte e tratado sozinho: o byte 0 da saida so depende do byte 0 da
//   entrada, o byte 1 so do byte 1, e assim por diante. Nenhum byte muda de
//   posicao.
//
// ONDE FICA NO PROJETO
//   - Semana 2 (desafio SubBytes e ShiftRows).
//   - Usado pelo minisoc_aes_dp (semana 4), dentro da rodada da cifra.
//   - A versao inversa e o minisoc_aes_inv_sub_bytes.
//
// NO QUE VIRA EM HARDWARE
//   - 16 copias (instancias) do modulo minisoc_aes_sbox, lado a lado.
//   - Todas funcionam ao mesmo tempo: e logica COMBINACIONAL (sem clock, sem
//     reset, sem memoria). A saida aparece depois do atraso das portas.
//   - E o bloco de maior area do datapath e fica no caminho critico.
//
// CONVENCAO DO ESTADO (Block Guide, secao 7.1; FIPS-197, secao 3.4)
//   - O estado tem 128 bits = 16 bytes.
//   - O byte n ocupa os bits state[127-8n -: 8]:
//       byte 0  -> bits [127:120]  (os mais altos)
//       byte 1  -> bits [119:112]
//       ...
//       byte 15 -> bits [7:0]      (os mais baixos)
//   - O byte n e o elemento s[r][c] da matriz 4x4, com r = n mod 4 (linha) e
//     c = n div 4 (coluna). No SubBytes a posicao nao importa, mas a mesma
//     formula de indice e usada em todos os modulos, para nao haver confusao.
// ============================================================================
module minisoc_aes_sub_bytes (
    input  logic [127:0] state_i,   // estado de entrada (16 bytes)
    output logic [127:0] state_o    // estado de saida: S(byte) em cada posicao
);

    // ---------------- 16 S-boxes, uma por byte ----------------
    // "for (genvar ...)" e um GENERATE, nao um laco que roda na simulacao.
    // Na elaboracao (quando a ferramenta monta o circuito), ele e expandido e
    // cria 16 copias do que esta dentro, com n = 0, 1, ..., 15.
    // O rotulo "g_sbox" da nome as copias: g_sbox[0].u_sbox ... g_sbox[15].u_sbox.
    // Sao esses nomes que aparecem nas formas de onda e nos relatorios de sintese.
    for (genvar n = 0; n < 16; n++) begin : g_sbox
        // Instancia: coloca uma S-box aqui dentro e liga as portas PELO NOME
        // (.porta(sinal)), o que evita trocar portas de lugar sem perceber.
        // state_i[127-8*n -: 8] e um "part-select indexado": 8 bits a partir
        // do bit (127 - 8n), descendo. n = 0 da [127:120]; n = 15 da [7:0].
        // A saida volta para a MESMA posicao em state_o.
        minisoc_aes_sbox u_sbox (
            .data_i (state_i[127-8*n -: 8]),   // byte n da entrada
            .data_o (state_o[127-8*n -: 8])    // byte n da saida = S(byte n)
        );
    end

endmodule : minisoc_aes_sub_bytes

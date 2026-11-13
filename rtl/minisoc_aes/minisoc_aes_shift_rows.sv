// ============================================================================
// minisoc_aes_shift_rows - transformacao ShiftRows do AES (FIPS-197, 5.1.2)
// ----------------------------------------------------------------------------
// O QUE FAZ
//   Gira cada linha da matriz de estado para a esquerda. A linha r gira r
//   posicoes; o que sai pela esquerda entra pela direita:
//     linha 0: nao gira
//     linha 1: gira 1 posicao
//     linha 2: gira 2 posicoes
//     linha 3: gira 3 posicoes
//   Formula do FIPS-197:  s'[r][c] = s[r][(c + r) mod 4]
//   Para que serve: depois do ShiftRows, os 4 bytes de cada coluna vem de 4
//   colunas diferentes. O MixColumns entao mistura cada coluna, e os dois
//   juntos espalham a influencia de cada byte pelo estado inteiro (difusao).
//
// ONDE FICA NO PROJETO
//   - Semana 2. Usado pelo minisoc_aes_dp na rodada da cifra.
//   - A versao inversa e o minisoc_aes_inv_shift_rows.
//
// NO QUE VIRA EM HARDWARE
//   SO FIACAO. A posicao de destino de cada byte e fixa, entao o modulo nao
//   calcula nada: so liga os fios da entrada aos da saida em outra ordem.
//   Zero portas logicas, zero area no relatorio de sintese.
//
// CONVENCAO DO ESTADO
//   byte n em state[127-8n -: 8], com n = r + 4c (r = linha, c = coluna).
//   Mapa resultante (byte de saida <- byte de entrada):
//     saida  :  0  1  2  3 |  4  5  6  7 |  8  9 10 11 | 12 13 14 15
//     entrada:  0  5 10 15 |  4  9 14  3 |  8 13  2  7 | 12  1  6 11
// ============================================================================
module minisoc_aes_shift_rows (
    input  logic [127:0] state_i,   // estado de entrada
    output logic [127:0] state_o    // estado com as linhas giradas
);

    // ---------------- reordenacao dos 16 bytes ----------------
    // Dois generates aninhados percorrem as 16 posicoes de SAIDA:
    // c = coluna (0 a 3) e r = linha (0 a 3).
    // Para a posicao de saida (r, c), a formula diz que o byte vem da linha r,
    // coluna (c + r) mod 4 da entrada. Convertendo (linha, coluna) em indice
    // de byte com n = r + 4c:
    //   byte de saida  : r + 4*c
    //   byte de entrada: r + 4*((c + r) % 4)
    // Como r e c sao genvars (constantes durante a elaboracao), o "%" e as
    // contas sao feitas pela FERRAMENTA, nao pelo chip: cada assign vira so
    // um fio. Nenhum divisor ou somador e sintetizado.
    for (genvar c = 0; c < 4; c++) begin : g_col
        for (genvar r = 0; r < 4; r++) begin : g_row
            // "assign" e uma atribuicao continua: state_o (aquele byte) e
            // sempre igual ao byte escolhido de state_i.
            // Exemplo: r = 1, c = 0  ->  byte de saida 1 <- byte de entrada 5.
            // byte de saida (r + 4c) <- byte de entrada (r + 4*((c + r) mod 4))
            assign state_o[127-8*(r+4*c) -: 8] = state_i[127-8*(r+4*((c+r)%4)) -: 8];
        end
    end

endmodule : minisoc_aes_shift_rows

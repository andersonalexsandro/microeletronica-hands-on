// ============================================================================
// minisoc_aes_mix_columns - transformacao MixColumns do AES (FIPS-197, 5.1.3)
// ----------------------------------------------------------------------------
// O QUE FAZ
//   Trata cada coluna do estado (4 bytes: a0, a1, a2, a3) como um vetor e a
//   multiplica por uma matriz fixa. As contas sao em GF(2^8), o corpo finito
//   de 256 elementos usado pelo AES:
//
//     | b0 |   | 02 03 01 01 |   | a0 |
//     | b1 | = | 01 02 03 01 | . | a1 |
//     | b2 |   | 01 01 02 03 |   | a2 |
//     | b3 |   | 03 01 01 02 |   | a3 |
//
//   Em GF(2^8):
//     - SOMAR e XOR (operador ^);
//     - multiplicar por {01} nao muda nada;
//     - multiplicar por {02} e o xtime (ver a funcao abaixo);
//     - multiplicar por {03} e {02} + {01}, ou seja, xtime(a) ^ a.
//   Por isso a matriz inteira vira uma rede de XORs: NAO ha multiplicador.
//
// PARA QUE SERVE
//   Mistura os 4 bytes de cada coluna: cada byte de saida depende dos 4 bytes
//   de entrada. Junto com o ShiftRows, espalha a influencia de cada byte
//   pelo estado inteiro em duas rodadas (difusao).
//
// ONDE FICA NO PROJETO
//   Semana 3. Usado pelo minisoc_aes_dp nas rodadas 1 a 9 da cifra; na
//   rodada 10 o datapath pula este bloco (a ultima rodada nao tem MixColumns).
//
// CONVENCAO DO ESTADO
//   A coluna c e a palavra state[127-32c -: 32] (Word 0 = [127:96], como na
//   secao 7.1 do Block Guide). Dentro da coluna, a linha 0 fica nos 8 bits
//   mais altos: {a0, a1, a2, a3}.
// ============================================================================
module minisoc_aes_mix_columns (
    input  logic [127:0] state_i,   // estado de entrada
    output logic [127:0] state_o    // estado com as colunas misturadas
);

    // ---------------- funcao xtime: multiplicar por {02} ----------------
    // Em GF(2^8), multiplicar por {02} e deslocar o byte 1 bit para a esquerda.
    // Se o bit 7 era 1, o resultado "estourou" 8 bits e precisa ser reduzido
    // pelo polinomio do AES (0x11B); na pratica, basta um XOR com 0x1B.
    //   {b[6:0], 1'b0}            -> desloca 1 bit para a esquerda
    //   (b[7] ? 8'h1b : 8'h00)    -> reducao, so se o bit 7 era 1
    // "function automatic" cria uma funcao combinacional: cada chamada vira
    // uma copia dessa logica (alguns XORs e fios), sem registrador.
    function automatic logic [7:0] xtime(input logic [7:0] b);
        return {b[6:0], 1'b0} ^ (b[7] ? 8'h1b : 8'h00);
    endfunction

    // ---------------- uma coluna por vez ----------------
    // O generate cria 4 copias da mesma logica, uma para cada coluna c.
    // Os sinais declarados aqui dentro (a0..a3) existem uma vez por coluna:
    // g_col[0].a0, g_col[1].a0, e assim por diante.
    for (genvar c = 0; c < 4; c++) begin : g_col
        logic [7:0] a0, a1, a2, a3;   // linhas 0 a 3 da coluna c

        // Separa a palavra da coluna c nos seus 4 bytes, linha 0 primeiro.
        // {a0, a1, a2, a3} = ... e uma concatenacao do lado esquerdo: a0 recebe
        // os 8 bits mais altos da palavra, a3 os 8 mais baixos.
        assign {a0, a1, a2, a3} = state_i[127-32*c -: 32];

        // Cada linha da matriz vira uma linha de XORs. A concatenacao {...}
        // monta a palavra de saida com b0 nos bits mais altos.
        // Exemplo do FIPS-197 (Ap. B, rodada 1, coluna 0):
        //   a = d4 bf 5d 30  ->  b = 04 66 81 e5
        assign state_o[127-32*c -: 32] = {
            xtime(a0) ^ (xtime(a1) ^ a1) ^ a2 ^ a3,     // b0 = 02.a0 ^ 03.a1 ^ a2 ^ a3
            a0 ^ xtime(a1) ^ (xtime(a2) ^ a2) ^ a3,     // b1 = a0 ^ 02.a1 ^ 03.a2 ^ a3
            a0 ^ a1 ^ xtime(a2) ^ (xtime(a3) ^ a3),     // b2 = a0 ^ a1 ^ 02.a2 ^ 03.a3
            (xtime(a0) ^ a0) ^ a1 ^ a2 ^ xtime(a3)      // b3 = 03.a0 ^ a1 ^ a2 ^ 02.a3
        };
    end

endmodule : minisoc_aes_mix_columns

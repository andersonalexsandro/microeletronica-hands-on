// ============================================================================
// minisoc_aes_sbox - S-box do AES (FIPS-197, secao 5.1.1, Figura 7)
// ----------------------------------------------------------------------------
// O QUE FAZ
//   Troca 1 byte por outro, segundo uma tabela fixa de 256 valores.
//   Exemplos do FIPS-197: S(00) = 63, S(53) = ed, S(ff) = 16.
//
// DE ONDE VEM A TABELA (a matematica, so para entender)
//   S(x) = afim(x^-1), em duas etapas:
//     1. x^-1: o inverso de x em GF(2^8), o corpo finito de 256 elementos do
//        AES (por convencao, o inverso de 00 e 00). Ex.: 53^-1 = ca.
//     2. afim: b ^ rotl(b,1) ^ rotl(b,2) ^ rotl(b,3) ^ rotl(b,4) ^ 63,
//        onde rotl gira os bits a esquerda. Ex.: afim(ca) = ed.
//   E a UNICA etapa nao linear do AES: sem ela, a cifra inteira seria uma
//   sequencia de XORs e permutacoes, que se resolve com algebra.
//
// COMO FOI IMPLEMENTADA
//   Como tabela: um case com as 256 entradas da Figura 7. A tabela foi gerada
//   pelo modelo de referencia (scripts/aes_ref.py), que a calcula pela
//   definicao acima, e e conferida pelo tb_minisoc_aes_sbox contra o arquivo
//   tb/vectors/sbox.hex e contra os valores citados no FIPS-197.
//   Alternativa nao usada: calcular o inverso em hardware (campo composto),
//   com menos area, mas bem mais dificil de ler e de depurar.
//
// PARA QUE SERVE
//   Da ao AES a "confusao": a relacao entre chave, texto claro e texto
//   cifrado deixa de ser linear. E usada em dois lugares: no SubBytes de cada
//   rodada da cifra e no SubWord da expansao de chave.
//
// ONDE FICA NO SISTEMA (semana 2; usada no datapath a partir da semana 4)
//   minisoc_top (sem. 7) > minisoc_aes_top (sem. 6) > minisoc_aes_dp >
//     u_sb (minisoc_aes_sub_bytes) ..... 16 instancias: g_sbox[0..15].u_sbox
//     u_key_exp (minisoc_aes_key_exp) ..  4 instancias: g_subword[0..3].u_sbox
//   A cifra inversa usa a minisoc_aes_inv_sbox (mais 16 instancias). No
//   total o datapath tem 36 tabelas. E puramente combinacional: sem clock e
//   sem reset.
// ============================================================================
module minisoc_aes_sbox (
    input  logic [7:0] data_i,   // byte de entrada
    output logic [7:0] data_o    // S(data_i)
);

    // ---------------- tabela de 256 entradas ----------------
    // always_comb: bloco de logica COMBINACIONAL. O simulador o reavalia toda
    // vez que data_i muda; nao ha clock nem memoria.
    // case (data_i): escolhe a linha pelo valor do byte de entrada. Cada linha
    // "8'hXY: data_o = 8'hZW;" diz: se a entrada vale XY, a saida vale ZW.
    // (8'h53 = literal de 8 bits escrito em hexadecimal.)
    //
    // POR QUE NAO HA "default": as 256 combinacoes possiveis de 8 bits estao
    // listadas, entao o case e COMPLETO: todo valor de entrada cai numa linha
    // e data_o sempre recebe valor. Assim a sintese nao infere LATCH (um
    // elemento de memoria indesejado, que apareceria se algum valor de
    // entrada deixasse data_o sem atribuicao).
    //
    // COMO LER A TABELA: 4 linhas do case por linha de texto, em ordem.
    // Na sintese, a tabela inteira vira uma funcao logica de 8 entradas e 8
    // saidas, minimizada pela ferramenta: nao ha ROM nem memoria no chip.
    // As 256 combinacoes de data_i estao listadas: o case e completo, entao
    // data_o recebe valor em todos os caminhos e a sintese nao infere latch.
    always_comb begin
        case (data_i)
            8'h00: data_o = 8'h63;  8'h01: data_o = 8'h7c;  8'h02: data_o = 8'h77;  8'h03: data_o = 8'h7b;
            8'h04: data_o = 8'hf2;  8'h05: data_o = 8'h6b;  8'h06: data_o = 8'h6f;  8'h07: data_o = 8'hc5;
            8'h08: data_o = 8'h30;  8'h09: data_o = 8'h01;  8'h0a: data_o = 8'h67;  8'h0b: data_o = 8'h2b;
            8'h0c: data_o = 8'hfe;  8'h0d: data_o = 8'hd7;  8'h0e: data_o = 8'hab;  8'h0f: data_o = 8'h76;
            8'h10: data_o = 8'hca;  8'h11: data_o = 8'h82;  8'h12: data_o = 8'hc9;  8'h13: data_o = 8'h7d;
            8'h14: data_o = 8'hfa;  8'h15: data_o = 8'h59;  8'h16: data_o = 8'h47;  8'h17: data_o = 8'hf0;
            8'h18: data_o = 8'had;  8'h19: data_o = 8'hd4;  8'h1a: data_o = 8'ha2;  8'h1b: data_o = 8'haf;
            8'h1c: data_o = 8'h9c;  8'h1d: data_o = 8'ha4;  8'h1e: data_o = 8'h72;  8'h1f: data_o = 8'hc0;
            8'h20: data_o = 8'hb7;  8'h21: data_o = 8'hfd;  8'h22: data_o = 8'h93;  8'h23: data_o = 8'h26;
            8'h24: data_o = 8'h36;  8'h25: data_o = 8'h3f;  8'h26: data_o = 8'hf7;  8'h27: data_o = 8'hcc;
            8'h28: data_o = 8'h34;  8'h29: data_o = 8'ha5;  8'h2a: data_o = 8'he5;  8'h2b: data_o = 8'hf1;
            8'h2c: data_o = 8'h71;  8'h2d: data_o = 8'hd8;  8'h2e: data_o = 8'h31;  8'h2f: data_o = 8'h15;
            8'h30: data_o = 8'h04;  8'h31: data_o = 8'hc7;  8'h32: data_o = 8'h23;  8'h33: data_o = 8'hc3;
            8'h34: data_o = 8'h18;  8'h35: data_o = 8'h96;  8'h36: data_o = 8'h05;  8'h37: data_o = 8'h9a;
            8'h38: data_o = 8'h07;  8'h39: data_o = 8'h12;  8'h3a: data_o = 8'h80;  8'h3b: data_o = 8'he2;
            8'h3c: data_o = 8'heb;  8'h3d: data_o = 8'h27;  8'h3e: data_o = 8'hb2;  8'h3f: data_o = 8'h75;
            8'h40: data_o = 8'h09;  8'h41: data_o = 8'h83;  8'h42: data_o = 8'h2c;  8'h43: data_o = 8'h1a;
            8'h44: data_o = 8'h1b;  8'h45: data_o = 8'h6e;  8'h46: data_o = 8'h5a;  8'h47: data_o = 8'ha0;
            8'h48: data_o = 8'h52;  8'h49: data_o = 8'h3b;  8'h4a: data_o = 8'hd6;  8'h4b: data_o = 8'hb3;
            8'h4c: data_o = 8'h29;  8'h4d: data_o = 8'he3;  8'h4e: data_o = 8'h2f;  8'h4f: data_o = 8'h84;
            8'h50: data_o = 8'h53;  8'h51: data_o = 8'hd1;  8'h52: data_o = 8'h00;  8'h53: data_o = 8'hed;
            8'h54: data_o = 8'h20;  8'h55: data_o = 8'hfc;  8'h56: data_o = 8'hb1;  8'h57: data_o = 8'h5b;
            8'h58: data_o = 8'h6a;  8'h59: data_o = 8'hcb;  8'h5a: data_o = 8'hbe;  8'h5b: data_o = 8'h39;
            8'h5c: data_o = 8'h4a;  8'h5d: data_o = 8'h4c;  8'h5e: data_o = 8'h58;  8'h5f: data_o = 8'hcf;
            8'h60: data_o = 8'hd0;  8'h61: data_o = 8'hef;  8'h62: data_o = 8'haa;  8'h63: data_o = 8'hfb;
            8'h64: data_o = 8'h43;  8'h65: data_o = 8'h4d;  8'h66: data_o = 8'h33;  8'h67: data_o = 8'h85;
            8'h68: data_o = 8'h45;  8'h69: data_o = 8'hf9;  8'h6a: data_o = 8'h02;  8'h6b: data_o = 8'h7f;
            8'h6c: data_o = 8'h50;  8'h6d: data_o = 8'h3c;  8'h6e: data_o = 8'h9f;  8'h6f: data_o = 8'ha8;
            8'h70: data_o = 8'h51;  8'h71: data_o = 8'ha3;  8'h72: data_o = 8'h40;  8'h73: data_o = 8'h8f;
            8'h74: data_o = 8'h92;  8'h75: data_o = 8'h9d;  8'h76: data_o = 8'h38;  8'h77: data_o = 8'hf5;
            8'h78: data_o = 8'hbc;  8'h79: data_o = 8'hb6;  8'h7a: data_o = 8'hda;  8'h7b: data_o = 8'h21;
            8'h7c: data_o = 8'h10;  8'h7d: data_o = 8'hff;  8'h7e: data_o = 8'hf3;  8'h7f: data_o = 8'hd2;
            8'h80: data_o = 8'hcd;  8'h81: data_o = 8'h0c;  8'h82: data_o = 8'h13;  8'h83: data_o = 8'hec;
            8'h84: data_o = 8'h5f;  8'h85: data_o = 8'h97;  8'h86: data_o = 8'h44;  8'h87: data_o = 8'h17;
            8'h88: data_o = 8'hc4;  8'h89: data_o = 8'ha7;  8'h8a: data_o = 8'h7e;  8'h8b: data_o = 8'h3d;
            8'h8c: data_o = 8'h64;  8'h8d: data_o = 8'h5d;  8'h8e: data_o = 8'h19;  8'h8f: data_o = 8'h73;
            8'h90: data_o = 8'h60;  8'h91: data_o = 8'h81;  8'h92: data_o = 8'h4f;  8'h93: data_o = 8'hdc;
            8'h94: data_o = 8'h22;  8'h95: data_o = 8'h2a;  8'h96: data_o = 8'h90;  8'h97: data_o = 8'h88;
            8'h98: data_o = 8'h46;  8'h99: data_o = 8'hee;  8'h9a: data_o = 8'hb8;  8'h9b: data_o = 8'h14;
            8'h9c: data_o = 8'hde;  8'h9d: data_o = 8'h5e;  8'h9e: data_o = 8'h0b;  8'h9f: data_o = 8'hdb;
            8'ha0: data_o = 8'he0;  8'ha1: data_o = 8'h32;  8'ha2: data_o = 8'h3a;  8'ha3: data_o = 8'h0a;
            8'ha4: data_o = 8'h49;  8'ha5: data_o = 8'h06;  8'ha6: data_o = 8'h24;  8'ha7: data_o = 8'h5c;
            8'ha8: data_o = 8'hc2;  8'ha9: data_o = 8'hd3;  8'haa: data_o = 8'hac;  8'hab: data_o = 8'h62;
            8'hac: data_o = 8'h91;  8'had: data_o = 8'h95;  8'hae: data_o = 8'he4;  8'haf: data_o = 8'h79;
            8'hb0: data_o = 8'he7;  8'hb1: data_o = 8'hc8;  8'hb2: data_o = 8'h37;  8'hb3: data_o = 8'h6d;
            8'hb4: data_o = 8'h8d;  8'hb5: data_o = 8'hd5;  8'hb6: data_o = 8'h4e;  8'hb7: data_o = 8'ha9;
            8'hb8: data_o = 8'h6c;  8'hb9: data_o = 8'h56;  8'hba: data_o = 8'hf4;  8'hbb: data_o = 8'hea;
            8'hbc: data_o = 8'h65;  8'hbd: data_o = 8'h7a;  8'hbe: data_o = 8'hae;  8'hbf: data_o = 8'h08;
            8'hc0: data_o = 8'hba;  8'hc1: data_o = 8'h78;  8'hc2: data_o = 8'h25;  8'hc3: data_o = 8'h2e;
            8'hc4: data_o = 8'h1c;  8'hc5: data_o = 8'ha6;  8'hc6: data_o = 8'hb4;  8'hc7: data_o = 8'hc6;
            8'hc8: data_o = 8'he8;  8'hc9: data_o = 8'hdd;  8'hca: data_o = 8'h74;  8'hcb: data_o = 8'h1f;
            8'hcc: data_o = 8'h4b;  8'hcd: data_o = 8'hbd;  8'hce: data_o = 8'h8b;  8'hcf: data_o = 8'h8a;
            8'hd0: data_o = 8'h70;  8'hd1: data_o = 8'h3e;  8'hd2: data_o = 8'hb5;  8'hd3: data_o = 8'h66;
            8'hd4: data_o = 8'h48;  8'hd5: data_o = 8'h03;  8'hd6: data_o = 8'hf6;  8'hd7: data_o = 8'h0e;
            8'hd8: data_o = 8'h61;  8'hd9: data_o = 8'h35;  8'hda: data_o = 8'h57;  8'hdb: data_o = 8'hb9;
            8'hdc: data_o = 8'h86;  8'hdd: data_o = 8'hc1;  8'hde: data_o = 8'h1d;  8'hdf: data_o = 8'h9e;
            8'he0: data_o = 8'he1;  8'he1: data_o = 8'hf8;  8'he2: data_o = 8'h98;  8'he3: data_o = 8'h11;
            8'he4: data_o = 8'h69;  8'he5: data_o = 8'hd9;  8'he6: data_o = 8'h8e;  8'he7: data_o = 8'h94;
            8'he8: data_o = 8'h9b;  8'he9: data_o = 8'h1e;  8'hea: data_o = 8'h87;  8'heb: data_o = 8'he9;
            8'hec: data_o = 8'hce;  8'hed: data_o = 8'h55;  8'hee: data_o = 8'h28;  8'hef: data_o = 8'hdf;
            8'hf0: data_o = 8'h8c;  8'hf1: data_o = 8'ha1;  8'hf2: data_o = 8'h89;  8'hf3: data_o = 8'h0d;
            8'hf4: data_o = 8'hbf;  8'hf5: data_o = 8'he6;  8'hf6: data_o = 8'h42;  8'hf7: data_o = 8'h68;
            8'hf8: data_o = 8'h41;  8'hf9: data_o = 8'h99;  8'hfa: data_o = 8'h2d;  8'hfb: data_o = 8'h0f;
            8'hfc: data_o = 8'hb0;  8'hfd: data_o = 8'h54;  8'hfe: data_o = 8'hbb;  8'hff: data_o = 8'h16;
        endcase
    end

endmodule : minisoc_aes_sbox

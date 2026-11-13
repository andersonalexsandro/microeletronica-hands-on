// ============================================================================
// minisoc_aes_key_exp - expansao de chave do AES-128 (FIPS-197, secao 5.2)
// ----------------------------------------------------------------------------
// O QUE FAZ
//   A partir da chave de 128 bits, gera as 11 CHAVES DE RODADA (round keys):
//     rk0 = a propria chave
//     rk1 ... rk10 = cada uma calculada a partir da anterior
//   e as guarda numa tabela de registradores, de onde o datapath le uma por
//   ciclo.
//
// COMO UMA CHAVE SAI DA ANTERIOR (AES-128)
//   A chave anterior e vista como 4 palavras de 32 bits: w0, w1, w2, w3.
//     temp = SubWord(RotWord(w3)) ^ {Rcon[i], 00, 00, 00}
//     w0'  = w0 ^ temp
//     w1'  = w1 ^ w0'
//     w2'  = w2 ^ w1'
//     w3'  = w3 ^ w2'
//   RotWord gira os 4 bytes da palavra; SubWord aplica a S-box nos 4;
//   Rcon e a constante de rodada. Exemplo do FIPS-197 (Apendice A.1):
//   w3 = 09cf4f3c -> RotWord cf4f3c09 -> SubWord 8a84eb01 -> ^Rcon 8b84eb01
//   -> ^w0 (2b7e1516) = a0fafe17, que e a primeira palavra de rk1.
//
// LINHA DO TEMPO
//   ciclo do load_i : rk0 <= key_i
//   10 ciclos       : rk1 ... rk10, uma por ciclo
//   depois          : ready_o = 1 ate o proximo load_i (latencia: 11 ciclos)
//
// POR QUE PRE-COMPUTAR (microarquitetura v1.0, secao 5.3)
//   - O engine usa a mesma chave em ate 256 blocos: a expansao roda UMA vez
//     por operacao, e nao uma vez por bloco.
//   - A cifra inversa precisa das chaves de tras para frente (rk10 ... rk0):
//     com a tabela pronta, basta mudar o indice da leitura.
//   - Custo: area. 11 x 128 = 1408 flip-flops e um mux de leitura 11:1 de
//     128 bits. A alternativa (calcular sob demanda) esta documentada para
//     comparar com os numeros da sintese (semana 8).
//
// REGRA DE RESET
//   - CONTROLE (contador e flags): reset assincrono, ativo em nivel baixo.
//   - DADOS (tabela e ultima chave): sem reset. So valem com ready_o = 1, e
//     o controle garante isso. Flip-flops sem reset sao menores.
// ============================================================================
module minisoc_aes_key_exp (
    input  logic         clk,
    input  logic         rst_n,          // reset assincrono, ativo em nivel baixo
    input  logic         load_i,         // pulso: comeca a expandir key_i
    input  logic [127:0] key_i,          // chave da cifra (KEY0..KEY3)
    output logic         ready_o,        // 1 = as 11 chaves de rodada estao validas
    input  logic [3:0]   round_i,        // indice da chave lida: 0 a 10
    output logic [127:0] round_key_o     // chave de rodada rk[round_i]
);

    // ---------------- constantes de rodada (Rcon) ----------------
    // Rcon[i] = x^(i-1) em GF(2^8), i = 1..10 (FIPS-197, secao 5.2): sao as
    // potencias de {02}. Depois de 80, o xtime reduz por 1b, e 1b.02 = 36.
    // Funcao combinacional com case: na sintese vira uma tabelinha de 10
    // valores indexada pelo contador cnt_q.
    function automatic logic [7:0] rcon(input logic [3:0] i);
        case (i)
            4'd1:    rcon = 8'h01;
            4'd2:    rcon = 8'h02;
            4'd3:    rcon = 8'h04;
            4'd4:    rcon = 8'h08;
            4'd5:    rcon = 8'h10;
            4'd6:    rcon = 8'h20;
            4'd7:    rcon = 8'h40;
            4'd8:    rcon = 8'h80;
            4'd9:    rcon = 8'h1b;
            4'd10:   rcon = 8'h36;
            default: rcon = 8'h00;   // indices 0 e 11..15 nao sao usados
        endcase
    endfunction

    // ---------------- registradores ----------------
    // rk_q e um ARRAY: 11 registradores de 128 bits, rk_q[0] ... rk_q[10].
    // O indice entre colchetes DEPOIS do nome escolhe a linha da tabela.
    logic [127:0] rk_q [0:10];   // tabela das chaves de rodada
    logic [127:0] last_q;        // ultima chave calculada (entrada da proxima)
    logic [3:0]   cnt_q;         // indice da proxima chave a calcular: 1..10
    logic         busy_q;        // expansao em andamento
    logic         ready_q;       // 1 = tabela completa e valida

    // ---------------- proxima chave (combinacional) ----------------
    // Calcula, a partir de last_q, a chave seguinte. E logica combinacional:
    // o resultado (next_key) fica pronto dentro do ciclo e e gravado na borda.
    logic [31:0]  w0, w1, w2, w3;      // palavras da ultima chave
    logic [31:0]  rot, sub, temp;      // RotWord, SubWord e o termo com Rcon
    logic [31:0]  n0, n1, n2, n3;      // palavras da proxima chave
    logic [127:0] next_key;

    // Separa a ultima chave em 4 palavras (w0 nos bits mais altos).
    assign {w0, w1, w2, w3} = last_q;
    // RotWord: gira 1 byte para a esquerda. So fiacao (uma concatenacao).
    assign rot = {w3[23:0], w3[31:24]};                  // RotWord: [a0 a1 a2 a3] -> [a1 a2 a3 a0]

    // SubWord: aplica a S-box aos 4 bytes de rot. Reaproveita o modulo
    // minisoc_aes_sbox da semana 2 (4 instancias, criadas pelo generate).
    for (genvar b = 0; b < 4; b++) begin : g_subword     // SubWord: 4 S-boxes
        minisoc_aes_sbox u_sbox (
            .data_i (rot[31-8*b -: 8]),
            .data_o (sub[31-8*b -: 8])
        );
    end

    // O Rcon so entra no primeiro byte: {rcon, 00, 00, 00}.
    assign temp = sub ^ {rcon(cnt_q), 24'h000000};
    // Cadeia de XORs. Cada palavra nova usa a palavra nova anterior; por
    // isso sao 4 sinais separados (n0..n3). Escrever tudo em fatias de um
    // vetor so faria o Verilator acusar UNOPTFLAT (falso laco combinacional).
    assign n0 = w0 ^ temp;               // cadeia de XORs: cada palavra usa a anterior
    assign n1 = w1 ^ n0;
    assign n2 = w2 ^ n1;
    assign n3 = w3 ^ n2;
    assign next_key = {n0, n1, n2, n3};

    // ---------------- controle (com reset) ----------------
    // always_ff: flip-flops atualizados na borda de subida do clk.
    // "or negedge rst_n": o reset e ASSINCRONO (age na hora em que rst_n vai
    // a 0, sem esperar o clock). "<=" e a atribuicao nao bloqueante: todos os
    // registradores do bloco mudam juntos, na borda.
    // Funcionamento:
    //   - load_i: comeca uma expansao (cnt = 1, busy = 1, ready = 0);
    //   - busy:   a cada ciclo grava uma chave; ao gravar a rk10 (cnt = 10),
    //             termina (busy = 0, ready = 1).
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_q  <= 1'b0;
            ready_q <= 1'b0;
            cnt_q   <= 4'd0;
        end else if (load_i) begin
            busy_q  <= 1'b1;
            ready_q <= 1'b0;
            cnt_q   <= 4'd1;
        end else if (busy_q) begin
            if (cnt_q == 4'd10) begin
                busy_q  <= 1'b0;
                ready_q <= 1'b1;
            end
            cnt_q <= cnt_q + 4'd1;
        end
    end

    // ---------------- dados (sem reset) ----------------
    // Bloco separado, sem reset, para nao misturar flops com e sem reset no
    // mesmo always_ff.
    //   - load_i: a propria chave vai para rk_q[0] e para last_q;
    //   - busy:   a chave nova vai para rk_q[cnt_q] e para last_q.
    // Fora desses casos, nada e escrito: os registradores MANTEM o valor.
    // Escritos so com enable (load_i ou busy_q): na sintese, candidatos
    // naturais a clock gating, ja que ficam parados durante a operacao.
    always_ff @(posedge clk) begin
        if (load_i) begin
            rk_q[0] <= key_i;
            last_q  <= key_i;
        end else if (busy_q) begin
            rk_q[cnt_q] <= next_key;
            last_q      <= next_key;
        end
    end

    // ---------------- leitura ----------------
    // A leitura e combinacional: o datapath poe o indice em round_i e recebe
    // a chave no mesmo ciclo. Na sintese, rk_q[round_i] vira um multiplexador
    // de 11 entradas de 128 bits. Indices acima de 10 devolvem zero.
    assign ready_o     = ready_q;
    assign round_key_o = (round_i <= 4'd10) ? rk_q[round_i] : 128'h0;

endmodule : minisoc_aes_key_exp

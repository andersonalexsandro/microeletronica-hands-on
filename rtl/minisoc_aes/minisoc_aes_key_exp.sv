// ============================================================================
// minisoc_aes_key_exp - expansao de chave do AES-128 (FIPS-197, secao 5.2)
// ----------------------------------------------------------------------------
// Pre-computa as 11 chaves de rodada (rk0 = a propria chave, rk1 ... rk10)
// e as guarda numa tabela de registradores. Uma chave nova por ciclo:
//
//   ciclo do load_i : rk0 <= key_i
//   10 ciclos       : rk1 ... rk10, cada uma calculada a partir da anterior
//   depois          : ready_o = 1 ate o proximo load_i
//
// Proxima chave a partir da anterior (w0, w1, w2, w3 = palavras de 32 bits):
//   temp = SubWord(RotWord(w3)) ^ {Rcon[i], 00, 00, 00}
//   w0' = w0 ^ temp,  w1' = w1 ^ w0',  w2' = w2 ^ w1',  w3' = w3 ^ w2'
//
// Por que pre-computar (microarquitetura v1.0, secao 6.3): o engine usa a
// mesma chave em ate 256 blocos, entao a expansao roda uma vez por operacao
// e nao uma vez por bloco; e a cifra inversa le as chaves de tras para
// frente (rk10 ... rk0) so mudando o indice da leitura. O custo e a area:
// 11 x 128 = 1408 flip-flops e um mux de leitura 11:1 de 128 bits.
//
// Os registradores de dados (tabela e ultima chave) nao tem reset: so valem
// com ready_o = 1. O controle (contador e flags) tem reset assincrono.
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

    // Rcon[i] = x^(i-1) em GF(2^8), i = 1..10 (FIPS-197, secao 5.2)
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
            default: rcon = 8'h00;
        endcase
    endfunction

    logic [127:0] rk_q [0:10];   // tabela das chaves de rodada
    logic [127:0] last_q;        // ultima chave calculada (entrada da proxima)
    logic [3:0]   cnt_q;         // indice da proxima chave a calcular: 1..10
    logic         busy_q;        // expansao em andamento
    logic         ready_q;

    // ---------------- proxima chave (combinacional) ----------------
    logic [31:0]  w0, w1, w2, w3;      // palavras da ultima chave
    logic [31:0]  rot, sub, temp;      // RotWord, SubWord e o termo com Rcon
    logic [31:0]  n0, n1, n2, n3;      // palavras da proxima chave
    logic [127:0] next_key;

    assign {w0, w1, w2, w3} = last_q;
    assign rot = {w3[23:0], w3[31:24]};                  // RotWord: [a0 a1 a2 a3] -> [a1 a2 a3 a0]

    for (genvar b = 0; b < 4; b++) begin : g_subword     // SubWord: 4 S-boxes
        minisoc_aes_sbox u_sbox (
            .data_i (rot[31-8*b -: 8]),
            .data_o (sub[31-8*b -: 8])
        );
    end

    assign temp = sub ^ {rcon(cnt_q), 24'h000000};
    assign n0 = w0 ^ temp;               // cadeia de XORs: cada palavra usa a anterior
    assign n1 = w1 ^ n0;
    assign n2 = w2 ^ n1;
    assign n3 = w3 ^ n2;
    assign next_key = {n0, n1, n2, n3};

    // ---------------- controle (com reset) ----------------
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
    assign ready_o     = ready_q;
    assign round_key_o = (round_i <= 4'd10) ? rk_q[round_i] : 128'h0;

endmodule : minisoc_aes_key_exp

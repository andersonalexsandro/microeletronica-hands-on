// ============================================================================
// minisoc_aes_key_exp - expansao de chave do AES-128
// ============================================================================
// O QUE E
//   A partir da chave de 128 bits, gera as 11 chaves de rodada (rk0 a rk10)
//   e guarda todas numa tabela. Gera uma chave por ciclo: 11 ciclos.
//   Cada chave nova sai da anterior, palavra por palavra (w0 a w3):
//     temp = S-box nos 4 bytes de w3 girado 1 byte, ^ Rcon
//     n0 = w0 ^ temp   n1 = w1 ^ n0   n2 = w2 ^ n1   n3 = w3 ^ n2
//   Ex.: chave 2b7e1516 28aed2a6 abf71588 09cf4f3c ->
//        rk1 = a0fafe17 88542cb1 23a33939 2a6c7605.
//
// ENTRADAS E SAIDAS
//   clk               entrada  clock
//   rst_n             entrada  reset, ativo em 0
//   load_i            entrada  pulso de 1 ciclo: comeca a expandir key_i
//   key_i     [127:0] entrada  chave da cifra
//   ready_o           saida    1 = as 11 chaves estao prontas na tabela
//   round_i   [3:0]   entrada  qual chave ler (0 a 10)
//   round_key_o [127:0] saida  a chave rk[round_i]
// ============================================================================
module minisoc_aes_key_exp (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         load_i,
    input  logic [127:0] key_i,
    output logic         ready_o,
    input  logic [3:0]   round_i,
    output logic [127:0] round_key_o
);

    // ---------------- Rcon: constante de cada rodada ----------------
    // Uma constante diferente por rodada, para nenhuma chave repetir a outra.
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
            default: rcon = 8'h00;   // 0 e 11 a 15 nao sao usados
        endcase
    endfunction

    // ---------------- registradores ----------------
    logic [127:0] rk_q [0:10];   // tabela com as 11 chaves de rodada
    logic [127:0] last_q;        // ultima chave calculada (base da proxima)
    logic [3:0]   cnt_q;         // qual chave esta sendo calculada (1 a 10)
    logic         busy_q;        // 1 = expandindo
    logic         ready_q;       // 1 = tabela completa

    // ---------------- calculo da proxima chave (combinacional) ----------------
    logic [31:0]  w0, w1, w2, w3;      // as 4 palavras da ultima chave
    logic [31:0]  rot, sub, temp;
    logic [31:0]  n0, n1, n2, n3;      // as 4 palavras da proxima chave
    logic [127:0] next_key;

    assign {w0, w1, w2, w3} = last_q;

    // gira w3 1 byte para a esquerda: [a0 a1 a2 a3] -> [a1 a2 a3 a0]
    assign rot = {w3[23:0], w3[31:24]};

    // passa os 4 bytes de rot por 4 S-boxes
    for (genvar b = 0; b < 4; b++) begin : g_subword
        minisoc_aes_sbox u_sbox (
            .data_i (rot[31-8*b -: 8]),
            .data_o (sub[31-8*b -: 8])
        );
    end

    // XOR do Rcon so no primeiro byte
    assign temp = sub ^ {rcon(cnt_q), 24'h000000};

    // cadeia de XORs: cada palavra nova usa a anterior
    assign n0 = w0 ^ temp;
    assign n1 = w1 ^ n0;
    assign n2 = w2 ^ n1;
    assign n3 = w3 ^ n2;
    assign next_key = {n0, n1, n2, n3};

    // ---------------- controle: conta de 1 a 10 ----------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_q  <= 1'b0;
            ready_q <= 1'b0;
            cnt_q   <= 4'd0;
        end else if (load_i) begin       // chave nova: recomeca
            busy_q  <= 1'b1;
            ready_q <= 1'b0;
            cnt_q   <= 4'd1;
        end else if (busy_q) begin
            if (cnt_q == 4'd10) begin    // ultima chave: tabela pronta
                busy_q  <= 1'b0;
                ready_q <= 1'b1;
            end
            cnt_q <= cnt_q + 4'd1;
        end
    end

    // ---------------- escrita da tabela ----------------
    // Na carga, rk0 = a propria chave. Depois, uma chave nova por ciclo.
    always_ff @(posedge clk) begin
        if (load_i) begin
            rk_q[0] <= key_i;
            last_q  <= key_i;
        end else if (busy_q) begin
            rk_q[cnt_q] <= next_key;
            last_q      <= next_key;
        end
    end

    // ---------------- saidas ----------------
    assign ready_o     = ready_q;
    assign round_key_o = (round_i <= 4'd10) ? rk_q[round_i] : 128'h0;   // le a chave pedida

endmodule : minisoc_aes_key_exp

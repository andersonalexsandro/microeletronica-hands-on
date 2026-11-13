// ============================================================================
// minisoc_aes_dp - datapath AES-128 (cifra e decifra um bloco)
// ============================================================================
// O QUE E
//   Cifra ou decifra um bloco de 128 bits em 11 ciclos de clock.
//   Tem um registrador de estado (state_q) e o hardware de UMA rodada da
//   cifra e de UMA rodada da inversa, usados 10 vezes. A expansao de chave
//   fica aqui dentro.
//     ciclo 1      : state_q = bloco ^ primeira chave
//     ciclos 2 a 11: uma rodada por ciclo (a rodada 10 pula o MixColumns)
//   Ex.: chave 000102...0f, bloco 00112233...ff -> 69c4e0d8...70b4c55a.
//
// ENTRADAS E SAIDAS
//   clk                entrada  clock
//   rst_n              entrada  reset, ativo em 0
//   key_load_i         entrada  pulso: carrega key_i e gera as 11 chaves
//   key_i      [127:0] entrada  chave da cifra
//   key_ready_o        saida    1 = chaves prontas; so entao o start vale
//   start_i            entrada  pulso: processa block_i
//   decrypt_i          entrada  0 = cifrar, 1 = decifrar (lido no start)
//   block_i    [127:0] entrada  bloco a processar
//   busy_o             saida    1 = processando (start e ignorado)
//   done_o             saida    pulso de 1 ciclo: block_o pronto
//   block_o    [127:0] saida    resultado (fica parado ate o proximo start)
// ============================================================================
module minisoc_aes_dp (
    input  logic         clk,
    input  logic         rst_n,

    input  logic         key_load_i,
    input  logic [127:0] key_i,
    output logic         key_ready_o,

    input  logic         start_i,
    input  logic         decrypt_i,
    input  logic [127:0] block_i,
    output logic         busy_o,
    output logic         done_o,
    output logic [127:0] block_o
);

    // ---------------- controle ----------------
    logic       busy_q;       // 1 = processando um bloco
    logic       dec_q;        // sentido guardado no start (1 = decifrar)
    logic       done_q;
    logic [3:0] rnd_q;        // rodada em execucao: 1 a 10
    logic       start_ok;
    logic       last_round;

    // O start so vale parado, com as chaves prontas e sem carga de chave junto.
    assign start_ok   = start_i && !key_load_i && !busy_q && key_ready_o;

    assign last_round = (rnd_q == 4'd10);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_q <= 1'b0;
            dec_q  <= 1'b0;
            done_q <= 1'b0;
            rnd_q  <= 4'd0;
        end else begin
            done_q <= 1'b0;                // done so fica em 1 por um ciclo
            if (start_ok) begin            // comeca: proxima borda faz a rodada 1
                busy_q <= 1'b1;
                dec_q  <= decrypt_i;
                rnd_q  <= 4'd1;
            end else if (busy_q) begin
                if (last_round) begin      // rodada 10 feita: resultado pronto
                    busy_q <= 1'b0;
                    done_q <= 1'b1;
                    rnd_q  <= 4'd0;
                end else begin
                    rnd_q  <= rnd_q + 4'd1;
                end
            end
        end
    end

    // ---------------- chave da rodada ----------------
    // Cifra usa rk0, rk1 ... rk10; decifra usa rk10, rk9 ... rk0.
    // Parado, o indice vem de decrypt_i (dec_q ainda nao foi gravado).
    logic [3:0]   key_idx;
    logic [127:0] round_key;

    always_comb begin
        if (!busy_q) key_idx = decrypt_i ? 4'd10 : 4'd0;
        else         key_idx = dec_q ? (4'd10 - rnd_q) : rnd_q;
    end

    minisoc_aes_key_exp u_key_exp (
        .clk         (clk),
        .rst_n       (rst_n),
        .load_i      (key_load_i && !busy_q),   // carga ignorada durante um bloco
        .key_i       (key_i),
        .ready_o     (key_ready_o),
        .round_i     (key_idx),
        .round_key_o (round_key)
    );

    // ---------------- registrador do estado ----------------
    logic [127:0] state_q;

    // ---------------- rodada da cifra ----------------
    // SubBytes -> ShiftRows -> MixColumns -> AddRoundKey
    logic [127:0] sb, sr, mc, enc_pre, enc_out;
    minisoc_aes_sub_bytes     u_sb  (.state_i(state_q), .state_o(sb));
    minisoc_aes_shift_rows    u_sr  (.state_i(sb),      .state_o(sr));
    minisoc_aes_mix_columns   u_mc  (.state_i(sr),      .state_o(mc));

    assign enc_pre = last_round ? sr : mc;   // rodada 10: pula o MixColumns
    minisoc_aes_add_round_key u_ark_enc (.state_i(enc_pre), .round_key_i(round_key), .state_o(enc_out));

    // ---------------- rodada da inversa ----------------
    // InvShiftRows -> InvSubBytes -> AddRoundKey -> InvMixColumns
    logic [127:0] isr, isb, iark, imc, dec_out;
    minisoc_aes_inv_shift_rows  u_isr (.state_i(state_q), .state_o(isr));
    minisoc_aes_inv_sub_bytes   u_isb (.state_i(isr),     .state_o(isb));
    minisoc_aes_add_round_key   u_ark_dec (.state_i(isb), .round_key_i(round_key), .state_o(iark));
    minisoc_aes_inv_mix_columns u_imc (.state_i(iark),    .state_o(imc));

    assign dec_out = last_round ? iark : imc;   // rodada 10: pula o InvMixColumns

    // ---------------- AddRoundKey inicial (so na borda do start) ----------------
    logic [127:0] init_out;
    minisoc_aes_add_round_key u_ark_init (.state_i(block_i), .round_key_i(round_key), .state_o(init_out));

    // ---------------- escrita do estado ----------------
    // Start: bloco ^ primeira chave. Depois: resultado da rodada pedida.
    always_ff @(posedge clk) begin
        if (start_ok)    state_q <= init_out;
        else if (busy_q) state_q <= dec_q ? dec_out : enc_out;
    end

    // ---------------- saidas ----------------
    assign busy_o  = busy_q;
    assign done_o  = done_q;
    assign block_o = state_q;

endmodule : minisoc_aes_dp

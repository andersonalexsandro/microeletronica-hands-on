// ============================================================================
// minisoc_aes_dp - datapath AES-128: cifra e cifra inversa de um bloco
// ----------------------------------------------------------------------------
// Microarquitetura iterativa (microarquitetura v1.0, secao 6): um registrador
// de estado de 128 bits e uma rodada completa por ciclo de clock.
//
//   ciclo do start : state <= block_i ^ rk0          (cifra)
//                    state <= block_i ^ rk10         (cifra inversa)
//   rodadas 1..10  : state <= rodada(state, chave)   uma por ciclo
//   fim            : done_o = 1 por um ciclo; block_o fica valido
//
// Latencia: 11 ciclos do start ao done (1 da AddRoundKey inicial + 10
// rodadas). As chaves vem do minisoc_aes_key_exp, pre-computadas uma vez por
// chave (key_load_i) e lidas por indice: rk1..rk10 na cifra, rk9..rk0 na
// cifra inversa.
//
// Rodada da cifra (FIPS-197 5.1):  SubBytes -> ShiftRows -> MixColumns ->
//                                  AddRoundKey; a rodada 10 pula o MixColumns
// Rodada da inversa (FIPS-197 5.3): InvShiftRows -> InvSubBytes ->
//                                  AddRoundKey -> InvMixColumns; a ultima pula
//                                  o InvMixColumns
//
// Protocolo:
//   - key_load_i: pulso; expande key_i. key_ready_o = 1 quando terminar.
//   - start_i: pulso; aceito so com busy_o = 0, key_ready_o = 1 e sem
//     key_load_i no mesmo ciclo (a carga de chave tem prioridade). Fora
//     disso, o start e ignorado.
//   - key_load_i com busy_o = 1 e ignorado (a tabela de chaves esta em uso).
//   - block_o e mantido do done_o ate o proximo start aceito.
// ============================================================================
module minisoc_aes_dp (
    input  logic         clk,
    input  logic         rst_n,          // reset assincrono, ativo em nivel baixo
    // chave
    input  logic         key_load_i,     // pulso: carrega e expande key_i
    input  logic [127:0] key_i,
    output logic         key_ready_o,    // chaves de rodada prontas
    // bloco
    input  logic         start_i,        // pulso: processa block_i
    input  logic         decrypt_i,      // 0 = cifra; 1 = cifra inversa
    input  logic [127:0] block_i,
    output logic         busy_o,
    output logic         done_o,         // pulso de 1 ciclo: block_o valido
    output logic [127:0] block_o
);

    // ---------------- controle ----------------
    logic       busy_q;       // bloco em processamento
    logic       dec_q;        // sentido capturado no start
    logic       done_q;
    logic [3:0] rnd_q;        // rodada em execucao: 1..10
    logic       start_ok;     // start aceito neste ciclo
    logic       last_round;   // rodada 10: sem (Inv)MixColumns

    assign start_ok   = start_i && !key_load_i && !busy_q && key_ready_o;
    assign last_round = (rnd_q == 4'd10);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_q <= 1'b0;
            dec_q  <= 1'b0;
            done_q <= 1'b0;
            rnd_q  <= 4'd0;
        end else begin
            done_q <= 1'b0;                    // done e um pulso de 1 ciclo
            if (start_ok) begin
                busy_q <= 1'b1;
                dec_q  <= decrypt_i;
                rnd_q  <= 4'd1;
            end else if (busy_q) begin
                if (last_round) begin
                    busy_q <= 1'b0;
                    done_q <= 1'b1;
                    rnd_q  <= 4'd0;
                end else begin
                    rnd_q  <= rnd_q + 4'd1;
                end
            end
        end
    end

    // ---------------- chaves de rodada ----------------
    // Antes do start: rk0 (cifra) ou rk10 (inversa) para a AddRoundKey inicial.
    // Na rodada r: rk[r] (cifra) ou rk[10 - r] (inversa).
    logic [3:0]   key_idx;
    logic [127:0] round_key;

    always_comb begin
        if (!busy_q) key_idx = decrypt_i ? 4'd10 : 4'd0;
        else         key_idx = dec_q ? (4'd10 - rnd_q) : rnd_q;
    end

    minisoc_aes_key_exp u_key_exp (
        .clk         (clk),
        .rst_n       (rst_n),
        .load_i      (key_load_i && !busy_q),
        .key_i       (key_i),
        .ready_o     (key_ready_o),
        .round_i     (key_idx),
        .round_key_o (round_key)
    );

    // ---------------- registrador de estado ----------------
    logic [127:0] state_q;

    // rodada da cifra
    logic [127:0] sb, sr, mc, enc_pre, enc_out;
    minisoc_aes_sub_bytes     u_sb  (.state_i(state_q), .state_o(sb));
    minisoc_aes_shift_rows    u_sr  (.state_i(sb),      .state_o(sr));
    minisoc_aes_mix_columns   u_mc  (.state_i(sr),      .state_o(mc));
    assign enc_pre = last_round ? sr : mc;
    minisoc_aes_add_round_key u_ark_enc (.state_i(enc_pre), .round_key_i(round_key), .state_o(enc_out));

    // rodada da cifra inversa
    logic [127:0] isr, isb, iark, imc, dec_out;
    minisoc_aes_inv_shift_rows  u_isr (.state_i(state_q), .state_o(isr));
    minisoc_aes_inv_sub_bytes   u_isb (.state_i(isr),     .state_o(isb));
    minisoc_aes_add_round_key   u_ark_dec (.state_i(isb), .round_key_i(round_key), .state_o(iark));
    minisoc_aes_inv_mix_columns u_imc (.state_i(iark),    .state_o(imc));
    assign dec_out = last_round ? iark : imc;

    // AddRoundKey inicial, na carga do bloco
    logic [127:0] init_out;
    minisoc_aes_add_round_key u_ark_init (.state_i(block_i), .round_key_i(round_key), .state_o(init_out));

    // Dado sem reset: so vale com done_o. Escrito so com enable (start ou
    // rodada), o que permite clock gating na sintese.
    always_ff @(posedge clk) begin
        if (start_ok)    state_q <= init_out;
        else if (busy_q) state_q <= dec_q ? dec_out : enc_out;
    end

    assign busy_o  = busy_q;
    assign done_o  = done_q;
    assign block_o = state_q;

endmodule : minisoc_aes_dp

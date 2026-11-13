// ============================================================================
// minisoc_aes_dp - datapath AES-128: cifra e cifra inversa de um bloco
// ----------------------------------------------------------------------------
// O QUE FAZ
//   Recebe um bloco de 128 bits e devolve o bloco cifrado (decrypt_i = 0) ou
//   decifrado (decrypt_i = 1) com a chave carregada. E o "primitive
//   criptografico" da secao 8.1 do Block Guide: o minisoc_aes_top (semana 6)
//   vai usa-lo para todos os modos de operacao (ECB, CBC, PCBC, CFB, OFB, CTR).
//
// MICROARQUITETURA (microarquitetura v1.0, secao 5): ITERATIVA
//   Um registrador de estado de 128 bits (state_q) e o hardware de UMA rodada
//   da cifra e de UMA rodada da inversa, lado a lado. A cada ciclo de clock o
//   estado passa por uma rodada completa e volta para o registrador:
//
//     borda do start : state <= block_i ^ rk0          (cifra)
//                      state <= block_i ^ rk10         (cifra inversa)
//     bordas 1 a 10  : state <= rodada(state, chave da rodada)
//     depois da 10   : done_o = 1 por um ciclo; block_o tem o resultado
//
//   LATENCIA: 11 ciclos do start ao done (1 da AddRoundKey inicial + 10
//   rodadas), nos dois sentidos.
//
//   Rodada da cifra (FIPS-197 5.1):
//     SubBytes -> ShiftRows -> MixColumns -> AddRoundKey
//     (a rodada 10 pula o MixColumns)
//   Rodada da inversa (FIPS-197 5.3):
//     InvShiftRows -> InvSubBytes -> AddRoundKey -> InvMixColumns
//     (a ultima pula o InvMixColumns)
//
// CHAVES
//   O minisoc_aes_key_exp (instanciado aqui dentro) pre-computa as 11 chaves
//   uma vez por chave (key_load_i). O datapath le por indice:
//   rk1..rk10 na cifra, rk9..rk0 na cifra inversa.
//
// PROTOCOLO (microarquitetura v1.0, secao 6.2)
//   - key_load_i: pulso; expande key_i. key_ready_o = 1 quando terminar.
//   - start_i: pulso; aceito so com busy_o = 0, key_ready_o = 1 e SEM
//     key_load_i no mesmo ciclo (a carga de chave tem prioridade). Fora
//     disso, o start e ignorado.
//   - key_load_i com busy_o = 1 e ignorado (a tabela de chaves esta em uso).
//   - done_o e um pulso de 1 ciclo; block_o fica estavel do done ate o
//     proximo start aceito.
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
    // Registradores de controle (todos com reset):
    //   busy_q = 1 enquanto um bloco esta sendo processado
    //   dec_q  = sentido capturado no start (mudar decrypt_i depois nao afeta)
    //   done_q = pulso de 1 ciclo no fim do bloco
    //   rnd_q  = numero da rodada em execucao (1 a 10; 0 quando parado)
    logic       busy_q;       // bloco em processamento
    logic       dec_q;        // sentido capturado no start
    logic       done_q;
    logic [3:0] rnd_q;        // rodada em execucao: 1..10
    logic       start_ok;     // start aceito neste ciclo
    logic       last_round;   // rodada 10: sem (Inv)MixColumns

    // O start so vale com o dp livre e a chave pronta; se key_load_i vier no
    // mesmo ciclo, a carga de chave vence (mudar a tabela de chaves no meio de
    // um bloco daria resultado errado).
    assign start_ok   = start_i && !key_load_i && !busy_q && key_ready_o;
    // A ultima rodada e a 10: nela os muxes abaixo pulam o (Inv)MixColumns.
    assign last_round = (rnd_q == 4'd10);

    // Maquina de controle: parado -> (start_ok) -> rodadas 1..10 -> parado.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_q <= 1'b0;
            dec_q  <= 1'b0;
            done_q <= 1'b0;
            rnd_q  <= 4'd0;
        end else begin
            // Valor padrao a cada borda: done so fica em 1 no ciclo em que a
            // linha "done_q <= 1'b1" abaixo for executada.
            done_q <= 1'b0;                    // done e um pulso de 1 ciclo
            if (start_ok) begin
                busy_q <= 1'b1;                // comeca: a borda do start faz a
                dec_q  <= decrypt_i;           // AddRoundKey inicial e a proxima
                rnd_q  <= 4'd1;                // borda ja executa a rodada 1
            end else if (busy_q) begin
                if (last_round) begin
                    busy_q <= 1'b0;            // rodada 10 executada nesta borda:
                    done_q <= 1'b1;            // resultado pronto em state_q
                    rnd_q  <= 4'd0;
                end else begin
                    rnd_q  <= rnd_q + 4'd1;    // proxima rodada
                end
            end
        end
    end

    // ---------------- chaves de rodada ----------------
    // Antes do start: rk0 (cifra) ou rk10 (inversa) para a AddRoundKey inicial.
    // Na rodada r: rk[r] (cifra) ou rk[10 - r] (inversa).
    // E aqui que a decriptacao "consome as chaves em ordem inversa": so muda o
    // indice da leitura da tabela.
    logic [3:0]   key_idx;
    logic [127:0] round_key;

    // always_comb: logica combinacional (sem clock). key_idx escolhe qual
    // linha da tabela de chaves ler neste ciclo.
    always_comb begin
        if (!busy_q) key_idx = decrypt_i ? 4'd10 : 4'd0;
        else         key_idx = dec_q ? (4'd10 - rnd_q) : rnd_q;
    end

    // Expansao de chave: a carga so e aceita com o dp parado (!busy_q).
    minisoc_aes_key_exp u_key_exp (
        .clk         (clk),
        .rst_n       (rst_n),
        .load_i      (key_load_i && !busy_q),
        .key_i       (key_i),
        .ready_o     (key_ready_o),
        .round_i     (key_idx),
        .round_key_o (round_key)
    );

    // ---------------- estado e rodada da cifra ----------------
    // state_q e o registrador de 128 bits que guarda o bloco entre as rodadas.
    logic [127:0] state_q;

    // Rodada da cifra, toda combinacional, encadeada:
    //   state_q -> SubBytes (sb) -> ShiftRows (sr) -> MixColumns (mc)
    //   -> mux da ultima rodada (enc_pre) -> AddRoundKey (enc_out)
    // rodada da cifra
    logic [127:0] sb, sr, mc, enc_pre, enc_out;
    minisoc_aes_sub_bytes     u_sb  (.state_i(state_q), .state_o(sb));
    minisoc_aes_shift_rows    u_sr  (.state_i(sb),      .state_o(sr));
    minisoc_aes_mix_columns   u_mc  (.state_i(sr),      .state_o(mc));
    // Mux da ultima rodada: na rodada 10 usa a saida do ShiftRows (pula o
    // MixColumns, como manda o FIPS-197).
    assign enc_pre = last_round ? sr : mc;
    minisoc_aes_add_round_key u_ark_enc (.state_i(enc_pre), .round_key_i(round_key), .state_o(enc_out));

    // ---------------- rodada da cifra inversa ----------------
    // Ordem do FIPS-197 5.3, toda combinacional:
    //   state_q -> InvShiftRows (isr) -> InvSubBytes (isb) -> AddRoundKey
    //   (iark) -> InvMixColumns (imc) -> mux da ultima rodada (dec_out)
    // Este e o caminho mais longo do datapath (S-box inversa + XOR +
    // InvMixColumns): o candidato a caminho critico.
    // rodada da cifra inversa
    logic [127:0] isr, isb, iark, imc, dec_out;
    minisoc_aes_inv_shift_rows  u_isr (.state_i(state_q), .state_o(isr));
    minisoc_aes_inv_sub_bytes   u_isb (.state_i(isr),     .state_o(isb));
    minisoc_aes_add_round_key   u_ark_dec (.state_i(isb), .round_key_i(round_key), .state_o(iark));
    minisoc_aes_inv_mix_columns u_imc (.state_i(iark),    .state_o(imc));
    // Na ultima rodada da inversa, o resultado e a saida da AddRoundKey.
    assign dec_out = last_round ? iark : imc;

    // ---------------- AddRoundKey inicial ----------------
    // Na borda do start, o bloco de entrada ja entra misturado com a primeira
    // chave (rk0 na cifra, rk10 na inversa). key_idx garante a chave certa.
    // AddRoundKey inicial, na carga do bloco
    logic [127:0] init_out;
    minisoc_aes_add_round_key u_ark_init (.state_i(block_i), .round_key_i(round_key), .state_o(init_out));

    // ---------------- registrador de estado ----------------
    // Dado sem reset: so vale com done_o. Escrito so com enable (start ou
    // rodada), o que permite clock gating na sintese.
    //   - start_ok: carrega o bloco ja com a AddRoundKey inicial;
    //   - busy_q:   grava a saida da rodada do sentido escolhido no start;
    //   - parado:   mantem o valor (e por isso block_o fica estavel).
    always_ff @(posedge clk) begin
        if (start_ok)    state_q <= init_out;
        else if (busy_q) state_q <= dec_q ? dec_out : enc_out;
    end

    // ---------------- saidas ----------------
    assign busy_o  = busy_q;
    assign done_o  = done_q;
    assign block_o = state_q;

endmodule : minisoc_aes_dp

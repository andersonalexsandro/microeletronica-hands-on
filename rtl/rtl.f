// Lista de fontes RTL sintetizaveis, em ordem de compilacao.
// Caminhos relativos a raiz do repositorio. Lida pelo Makefile e, nas proximas
// fases, pelos scripts de sintese (syn/) e de equivalencia (formal/).
// Convencao: um modulo por arquivo, com o mesmo nome do arquivo (o lint usa).
//
// minisoc_aes: transformacoes de rodada (semanas 2 e 3)
rtl/minisoc_aes/minisoc_aes_sbox.sv
rtl/minisoc_aes/minisoc_aes_sub_bytes.sv
rtl/minisoc_aes/minisoc_aes_shift_rows.sv
rtl/minisoc_aes/minisoc_aes_mix_columns.sv
rtl/minisoc_aes/minisoc_aes_add_round_key.sv
// minisoc_aes: transformacoes inversas (semanas 2 e 3)
rtl/minisoc_aes/minisoc_aes_inv_sbox.sv
rtl/minisoc_aes/minisoc_aes_inv_sub_bytes.sv
rtl/minisoc_aes/minisoc_aes_inv_shift_rows.sv
rtl/minisoc_aes/minisoc_aes_inv_mix_columns.sv
// minisoc_aes: expansao de chave e datapath AES-128 (semana 4)
rtl/minisoc_aes/minisoc_aes_key_exp.sv
rtl/minisoc_aes/minisoc_aes_dp.sv

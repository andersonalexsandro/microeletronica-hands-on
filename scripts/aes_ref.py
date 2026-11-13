#!/usr/bin/env python3
"""
Modelo de referencia do AES (FIPS-197) em Python puro, sem dependencias.

Uso no projeto:
  - conferir os vetores de teste do padrao (FIPS-197, Apendices B e C);
  - gerar os vetores lidos pelos testbenches (--vectors, ou make vectors);
  - gerar valores intermediarios por rodada para os testes unitarios do RTL
    e da expansao de chave;
  - imprimir a S-box usada no RTL.

Exemplos:
  python3 scripts/aes_ref.py                      # auto-teste com os vetores do FIPS-197
  python3 scripts/aes_ref.py --vectors tb/vectors # gera os vetores dos testbenches
  python3 scripts/aes_ref.py --trace              # rodada a rodada do Apendice B
  python3 scripts/aes_ref.py --trace --decrypt --key 000102030405060708090a0b0c0d0e0f \
                             --ct 69c4e0d86a7b0430d8cdb78070b4c55a   # cifra inversa, Ap. C.1
  python3 scripts/aes_ref.py --trace --key 000102030405060708090a0b0c0d0e0f \
                             --pt 00112233445566778899aabbccddeeff
  python3 scripts/aes_ref.py --keyexp --key 2b7e151628aed2a6abf7158809cf4f3c
  python3 scripts/aes_ref.py --sbox

Convencao do estado: lista de 16 bytes na ordem de entrada; o byte in[i]
ocupa a linha r = i % 4 e a coluna c = i // 4 (ordem por colunas, FIPS-197 3.4).
"""

import argparse
import os
import random
import sys

# ---------------- aritmetica em GF(2^8) ----------------
# GF(2^8) e o corpo finito de 256 elementos do AES: cada byte e um polinomio
# com coeficientes 0 ou 1 (bit i = coeficiente de x^i). Somar e XOR (^);
# multiplicar e multiplicar polinomios e reduzir pelo polinomio do AES,
# m(x) = x^8 + x^4 + x^3 + x + 1 (0x11B), para o resultado caber em 8 bits.
# Daqui saem a S-box (inverso + afim), o MixColumns e o Rcon.

def xtime(b):
    """Multiplica por {02}: desloca 1 bit e reduz por 0x1B se houve estouro."""
    # Ex.: xtime(0x57) = 0xae; xtime(0xae) = 0x47 (bit 7 era 1: reduz com 0x1B).
    b <<= 1
    return (b ^ 0x11B) & 0xFF if b & 0x100 else b


def gmul(a, b):
    """Multiplicacao em GF(2^8) por somas de xtime (algoritmo 'shift-and-add')."""
    # Soma (XOR) de a, 2a, 4a, ... para cada bit 1 de b, como numa
    # multiplicacao no papel em binario, mas sem vai-um.
    p = 0
    while b:
        if b & 1:
            p ^= a
        a = xtime(a)
        b >>= 1
    return p


def ginv(b):
    """Inverso multiplicativo: b^254 (pois b^255 = 1). Por convencao inv(0) = 0."""
    # Forca bruta: b^254, porque b^255 = 1 para todo b != 0 em GF(2^8).
    r = 1
    for _ in range(254):
        r = gmul(r, b)
    return r if b else 0


def rotl8(b, n):
    return ((b << n) | (b >> (8 - n))) & 0xFF


def affine(b):
    """Transformacao afim da S-box: b ^ rotl1 ^ rotl2 ^ rotl3 ^ rotl4 ^ 0x63."""
    return b ^ rotl8(b, 1) ^ rotl8(b, 2) ^ rotl8(b, 3) ^ rotl8(b, 4) ^ 0x63


SBOX = [affine(ginv(x)) for x in range(256)]
INV_SBOX = [0] * 256
for _x, _s in enumerate(SBOX):
    INV_SBOX[_s] = _x

# ---------------- transformacoes de rodada ----------------
# O estado e uma lista de 16 inteiros (bytes) na ordem de entrada: o byte
# in[i] fica na linha r = i % 4 e na coluna c = i // 4 (FIPS-197 3.4). E a
# mesma ordem do RTL, onde o byte 0 fica nos bits [127:120].

def sub_bytes(s):
    return [SBOX[b] for b in s]


def inv_sub_bytes(s):
    return [INV_SBOX[b] for b in s]


def shift_rows(s):
    # Para cada posicao de saida (r, c), pega o byte da linha r, coluna
    # (c + r) mod 4 da entrada; o indice do byte e r + 4*coluna.
    # linha r gira r posicoes para a esquerda: s'[r,c] = s[r, (c+r) mod 4]
    return [s[r + 4 * ((c + r) % 4)] for c in range(4) for r in range(4)]


def inv_shift_rows(s):
    return [s[r + 4 * ((c - r) % 4)] for c in range(4) for r in range(4)]


def _mix(s, m):
    # Multiplica cada coluna (4 bytes) pela matriz m em GF(2^8): cada byte de
    # saida e a soma (XOR) dos 4 produtos gmul(coeficiente, byte).
    out = []
    for c in range(4):
        col = s[4 * c:4 * c + 4]
        for r in range(4):
            v = 0
            for k in range(4):
                v ^= gmul(m[r][k], col[k])
            out.append(v)
    return out


MIX = [[2, 3, 1, 1], [1, 2, 3, 1], [1, 1, 2, 3], [3, 1, 1, 2]]
INV_MIX = [[14, 11, 13, 9], [9, 14, 11, 13], [13, 9, 14, 11], [11, 13, 9, 14]]


def mix_columns(s):
    return _mix(s, MIX)


def inv_mix_columns(s):
    return _mix(s, INV_MIX)


def add_round_key(s, rk):
    return [a ^ b for a, b in zip(s, rk)]

# ---------------- expansao de chave ----------------
# FIPS-197 5.2. Gera as palavras w[0..4*(Nr+1)-1] (44 palavras no AES-128);
# a chave de rodada r e w[4r .. 4r+3].

RCON = [0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36]


def key_expansion(key):
    # Nk = palavras da chave (4 no AES-128); Nr = rodadas (10 no AES-128).
    # Cada w[i] = w[i-Nk] ^ temp; a cada Nk palavras, temp passa por RotWord,
    # SubWord e Rcon.
    nk = len(key) // 4
    if nk not in (4, 6, 8):
        raise ValueError("chave deve ter 128, 192 ou 256 bits")
    nr = nk + 6
    w = [list(key[4 * i:4 * i + 4]) for i in range(nk)]
    for i in range(nk, 4 * (nr + 1)):
        temp = list(w[i - 1])
        if i % nk == 0:
            temp = temp[1:] + temp[:1]                 # RotWord
            temp = [SBOX[b] for b in temp]             # SubWord
            temp[0] ^= RCON[i // nk]                   # Rcon
        elif nk > 6 and i % nk == 4:
            temp = [SBOX[b] for b in temp]             # SubWord extra do AES-256
        w.append([a ^ b for a, b in zip(w[i - nk], temp)])
    return w, nr


def round_key(w, rnd):
    return [b for word in w[4 * rnd:4 * rnd + 4] for b in word]

# ---------------- cifra e cifra inversa ----------------
# encrypt e decrypt seguem o pseudocodigo do FIPS-197 (secoes 5.1 e 5.3).
# O parametro trace, se for uma lista, recebe o estado depois de cada passo,
# na nomenclatura dos Apendices B e C.1 (start, s_box, s_row, m_col, k_sch;
# istart, is_row, is_box, ik_sch, ik_add). E daqui que saem os vetores das
# rodadas usados pelo tb_minisoc_aes_round.

def encrypt(pt, key, trace=None):
    # AddRoundKey inicial, depois Nr rodadas; a ultima sem MixColumns.
    w, nr = key_expansion(key)
    s = add_round_key(list(pt), round_key(w, 0))
    if trace is not None:
        trace.append((0, "input", list(pt)))
        trace.append((0, "k_sch", round_key(w, 0)))
    for rnd in range(1, nr + 1):
        if trace is not None:
            trace.append((rnd, "start", s))
        s = sub_bytes(s)
        if trace is not None:
            trace.append((rnd, "s_box", s))
        s = shift_rows(s)
        if trace is not None:
            trace.append((rnd, "s_row", s))
        if rnd != nr:
            s = mix_columns(s)
            if trace is not None:
                trace.append((rnd, "m_col", s))
        s = add_round_key(s, round_key(w, rnd))
        if trace is not None:
            trace.append((rnd, "k_sch", round_key(w, rnd)))
    if trace is not None:
        trace.append((nr, "output", s))
    return s


def decrypt(ct, key, trace=None):
    """Cifra inversa (FIPS-197 5.3). Com trace, registra os passos na mesma
    nomenclatura do Apendice C.1: istart, is_row, is_box, ik_sch e ik_add,
    com as rodadas numeradas de 1 a Nr na ordem em que sao executadas."""
    w, nr = key_expansion(key)
    s = add_round_key(list(ct), round_key(w, nr))
    if trace is not None:
        trace.append((0, "iinput", list(ct)))
        trace.append((0, "ik_sch", round_key(w, nr)))
    for rnd in range(1, nr + 1):
        k = nr - rnd                                   # chave de rodada usada agora
        if trace is not None:
            trace.append((rnd, "istart", s))
        s = inv_shift_rows(s)
        if trace is not None:
            trace.append((rnd, "is_row", s))
        s = inv_sub_bytes(s)
        if trace is not None:
            trace.append((rnd, "is_box", s))
        s = add_round_key(s, round_key(w, k))
        if trace is not None:
            trace.append((rnd, "ik_sch", round_key(w, k)))
            trace.append((rnd, "ik_add", s))
        if rnd != nr:
            s = inv_mix_columns(s)
    if trace is not None:
        trace.append((nr, "ioutput", s))
    return s

# ---------------- vetores dos padroes e auto-teste ----------------
# FIPS_VECTORS: os trios (chave, texto claro, texto cifrado) do FIPS-197.
# KNOWN_VALUES: valores intermediarios impressos nos padroes. Todo valor
# copiado de um padrao para um testbench passa antes por aqui (make ref).

FIPS_VECTORS = [
    # (nome, chave, texto claro, texto cifrado)
    ("Apendice B (AES-128)", "2b7e151628aed2a6abf7158809cf4f3c",
     "3243f6a8885a308d313198a2e0370734", "3925841d02dc09fbdc118597196a0b32"),
    ("Apendice C.1 (AES-128)", "000102030405060708090a0b0c0d0e0f",
     "00112233445566778899aabbccddeeff", "69c4e0d86a7b0430d8cdb78070b4c55a"),
    ("Apendice C.2 (AES-192)", "000102030405060708090a0b0c0d0e0f1011121314151617",
     "00112233445566778899aabbccddeeff", "dda97ca4864cdfe06eaf70a0ec0d7191"),
    ("Apendice C.3 (AES-256)",
     "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
     "00112233445566778899aabbccddeeff", "8ea2b7ca516745bfeafc49904b496089"),
]

# Valores intermediarios citados no texto dos padroes, conferidos no auto-teste
KNOWN_VALUES = [
    # (descricao, funcao que calcula, valor esperado)
    ("FIPS-197 A.1: w[43]",
     lambda: hx(key_expansion(bytes.fromhex(FIPS_VECTORS[0][1]))[0][43]), "b6630ca6"),
    ("FIPS-197 C.1: chave da rodada 10",
     lambda: hx(round_key(key_expansion(bytes.fromhex(FIPS_VECTORS[1][1]))[0], 10)),
     "13111d7fe3944a17f307a78b4d2b30c5"),
    ("FIPS-197 C.1: round[1].ik_add da cifra inversa",
     lambda: _trace_value(decrypt, FIPS_VECTORS[1][3], FIPS_VECTORS[1][1], (1, "ik_add")),
     "e9f74eec023020f61bf2ccf2353c21c7"),
    ("FIPS-197 B: round[1].m_col",
     lambda: _trace_value(encrypt, FIPS_VECTORS[0][2], FIPS_VECTORS[0][1], (1, "m_col")),
     "046681e5e0cb199a48f8d37a2806264c"),
    ("SP 800-38A F.1.1: ECB-AES128, bloco 1",
     lambda: hx(encrypt(bytes.fromhex("6bc1bee22e409f96e93d7e117393172a"),
                        bytes.fromhex(FIPS_VECTORS[0][1]))),
     "3ad77bb40d7a3660a89ecaf32466ef97"),
]


def hx(b):
    return bytes(b).hex()


def _trace_value(fn, data_hex, key_hex, where):
    t = []
    fn(bytes.fromhex(data_hex), bytes.fromhex(key_hex), t)
    return hx({(r, s): v for r, s, v in t}[where])


def selftest():
    # Confere S-box, os 4 vetores do FIPS-197 (cifra e decifra) e os valores
    # intermediarios de KNOWN_VALUES. Devolve o numero de falhas.
    fails = 0
    # S-box: valores citados no FIPS-197 (5.1.1) e inversa consistente
    for x, y in ((0x00, 0x63), (0x53, 0xED), (0xFF, 0x16)):
        ok = SBOX[x] == y
        fails += not ok
        print(f"[{'PASS' if ok else 'FAIL'}] S-box({x:02x}) = {SBOX[x]:02x} (esperado {y:02x})")
    for name, k, p, c in FIPS_VECTORS:
        key, pt = bytes.fromhex(k), bytes.fromhex(p)
        got = hx(encrypt(pt, key))
        back = hx(decrypt(bytes.fromhex(got), key))
        ok = got == c and back == p
        fails += not ok
        print(f"[{'PASS' if ok else 'FAIL'}] {name}: cifra={got} decifra={'ok' if back == p else back}")
    for name, fn, expected in KNOWN_VALUES:
        got = fn()
        ok = got == expected
        fails += not ok
        print(f"[{'PASS' if ok else 'FAIL'}] {name} = {got}" + ("" if ok else f" (esperado {expected})"))
    print("SELFTEST PASSED" if fails == 0 else f"SELFTEST FAILED ({fails} falhas)")
    return fails

# ---------------- vetores para os testbenches ----------------
# Arquivos .hex lidos pelos testbenches com $readmemh: um valor hexadecimal
# por token, comentarios com //. A semente fixa faz o make vectors gerar
# sempre os mesmos arquivos (git diff vazio se nada mudou no modelo).

VECTORS_HEADER = "// Gerado por scripts/aes_ref.py --vectors (make vectors). Nao editar a mao.\n"
N_RANDOM_KEYS = 20      # chaves aleatorias extras para o teste da expansao de chave
N_RANDOM_BLOCKS = 200   # trios (chave, texto claro, texto cifrado) aleatorios
RANDOM_SEED = 2026      # semente fixa: make vectors gera sempre os mesmos arquivos


def _write(outdir, fname, lines):
    with open(os.path.join(outdir, fname), "w") as f:
        f.write(VECTORS_HEADER)
        f.write("\n".join(lines) + "\n")
    print(f"[vetores] {os.path.join(outdir, fname)}")


def write_vectors(outdir):
    """Gera todos os arquivos lidos pelos testbenches em outdir."""
    # Cada bloco abaixo escreve um arquivo .hex: tabelas da S-box, rodadas
    # da cifra e da inversa, base do MixColumns, expansao de chave e trios.
    os.makedirs(outdir, exist_ok=True)
    aes128 = FIPS_VECTORS[:2]                   # Apendices B e C.1
    rng = random.Random(RANDOM_SEED)
    rand128 = lambda: rng.getrandbits(128).to_bytes(16, "big")

    # S-box e S-box inversa
    for fname, title, table in (("sbox.hex", "S-box (FIPS-197, Figura 7)", SBOX),
                                ("inv_sbox.hex", "S-box inversa (FIPS-197, Figura 14)", INV_SBOX)):
        _write(outdir, fname, [f"// {title}: a linha da entrada x contem o valor da tabela para x."] +
               [f"{y:02x}  // {x:02x}" for x, y in enumerate(table)])

    # Cifra: rodadas 1 a 10 dos Apendices B e C.1
    lines = ["// Cifra (FIPS-197 5.1), rodadas 1 a 10 dos Apendices B e C.1.",
             "// Por linha: start | s_box | s_row | m_col | k_sch | fim da rodada (apos AddRoundKey).",
             "// Na rodada 10 nao ha MixColumns: a coluna m_col repete s_row."]
    for name, k, p, _ in aes128:
        t = []
        encrypt(bytes.fromhex(p), bytes.fromhex(k), t)
        st = {(r, s): v for r, s, v in t}
        lines.append(f"// {name}: key {k}, pt {p}")
        for r in range(1, 11):
            m_col = st[(r, "m_col")] if r < 10 else st[(r, "s_row")]
            end = st[(r + 1, "start")] if r < 10 else st[(10, "output")]
            cols = [st[(r, "start")], st[(r, "s_box")], st[(r, "s_row")], m_col, st[(r, "k_sch")], end]
            lines.append(" ".join(hx(c) for c in cols) + f"  // r{r:02d}")
    _write(outdir, "fips197_cipher_rounds.hex", lines)

    # Cifra inversa: rodadas 1 a 10, decifrando os textos cifrados de C.1 e B
    lines = ["// Cifra inversa (FIPS-197 5.3), rodadas 1 a 10, na numeracao do Apendice C.1.",
             "// Por linha: istart | is_row | is_box | ik_sch | ik_add | fim da rodada (apos InvMixColumns).",
             "// Na rodada 10 nao ha InvMixColumns: a ultima coluna repete ik_add."]
    for name, k, _, c in (aes128[1], aes128[0]):
        t = []
        decrypt(bytes.fromhex(c), bytes.fromhex(k), t)
        st = {(r, s): v for r, s, v in t}
        lines.append(f"// {name}: key {k}, ct {c}")
        for r in range(1, 11):
            end = st[(r + 1, "istart")] if r < 10 else st[(10, "ik_add")]
            cols = [st[(r, s)] for s in ("istart", "is_row", "is_box", "ik_sch", "ik_add")] + [end]
            lines.append(" ".join(hx(x) for x in cols) + f"  // r{r:02d}")
    _write(outdir, "fips197_invcipher_rounds.hex", lines)

    # MixColumns e InvMixColumns nos 128 vetores de base (um unico bit em 1)
    lines = ["// MixColumns e InvMixColumns nos 128 estados com um unico bit em 1.",
             "// Por linha: x | MixColumns(x) | InvMixColumns(x). Linha i: bit i do estado em 1."]
    for i in range(128):
        x = list((1 << i).to_bytes(16, "big"))
        lines.append(f"{hx(x)} {hx(mix_columns(x))} {hx(inv_mix_columns(x))}  // bit {i}")
    _write(outdir, "mixcolumns_basis.hex", lines)

    # Expansao de chave: as 11 chaves de rodada de varias chaves
    keys = [bytes.fromhex(k) for _, k, _, _ in aes128] + [rand128() for _ in range(N_RANDOM_KEYS)]
    lines = ["// Expansao de chave AES-128 (FIPS-197 5.2): chaves dos Apendices A.1/B e C.1",
             f"// e mais {N_RANDOM_KEYS} chaves aleatorias. Por linha: rk0 (a propria chave) ... rk10."]
    for key in keys:
        w, _ = key_expansion(key)
        lines.append(" ".join(hx(round_key(w, r)) for r in range(11)))
    _write(outdir, "aes128_key_exp.hex", lines)

    # Blocos completos: Apendices B e C.1 e mais N_RANDOM_BLOCKS trios aleatorios
    lines = ["// AES-128 completo: Apendices B e C.1 do FIPS-197 e mais "
             f"{N_RANDOM_BLOCKS} trios aleatorios.",
             "// Por linha: key | plaintext | ciphertext."]
    trios = [(bytes.fromhex(k), bytes.fromhex(p)) for _, k, p, _ in aes128]
    trios += [(rand128(), rand128()) for _ in range(N_RANDOM_BLOCKS)]
    for key, pt in trios:
        lines.append(f"{hx(key)} {hx(pt)} {hx(encrypt(pt, key))}")
    _write(outdir, "aes128_vectors.hex", lines)


def main():
    # Linha de comando: sem opcoes roda o auto-teste; --vectors, --trace,
    # --keyexp e --sbox geram as outras saidas.
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--key", default=FIPS_VECTORS[0][1], help="chave em hex (128/192/256 bits)")
    ap.add_argument("--pt", default=FIPS_VECTORS[0][2], help="texto claro em hex (128 bits)")
    ap.add_argument("--ct", default=FIPS_VECTORS[0][3], help="texto cifrado em hex (com --decrypt)")
    ap.add_argument("--trace", action="store_true", help="imprime o estado rodada a rodada")
    ap.add_argument("--decrypt", action="store_true", help="com --trace: rastreia a cifra inversa de --ct")
    ap.add_argument("--keyexp", action="store_true", help="imprime as palavras w[i] da expansao de chave")
    ap.add_argument("--sbox", action="store_true", help="imprime a S-box 16x16")
    ap.add_argument("--vectors", metavar="DIR", help="gera os vetores dos testbenches em DIR")
    a = ap.parse_args()

    key, pt = bytes.fromhex(a.key), bytes.fromhex(a.pt)
    if a.vectors:
        write_vectors(a.vectors)
    elif a.sbox:
        print("     " + " ".join(f"{c:x}".rjust(2) for c in range(16)))
        for r in range(16):
            print(f"{r:x}0 | " + " ".join(f"{SBOX[16 * r + c]:02x}" for c in range(16)))
    elif a.keyexp:
        w, _ = key_expansion(key)
        for i, word in enumerate(w):
            print(f"w[{i:2d}] = {hx(word)}")
    elif a.trace:
        t = []
        if a.decrypt:
            decrypt(bytes.fromhex(a.ct), key, t)
        else:
            encrypt(pt, key, t)
        for rnd, step, s in t:
            print(f"round[{rnd:2d}].{step:<7} {hx(s)}")
    else:
        sys.exit(1 if selftest() else 0)


if __name__ == "__main__":
    main()

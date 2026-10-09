#!/usr/bin/env python3
"""
Modelo de referencia do AES (FIPS-197) em Python puro, sem dependencias.

Uso no projeto:
  - conferir os vetores de teste do padrao (FIPS-197, Apendices B e C);
  - gerar valores intermediarios por rodada para os testes unitarios do RTL
    (semana 3) e da expansao de chave (semana 4);
  - imprimir a S-box usada no RTL.

Exemplos:
  python3 scripts/aes_ref.py                      # auto-teste com os vetores do FIPS-197
  python3 scripts/aes_ref.py --trace              # rodada a rodada do Apendice B
  python3 scripts/aes_ref.py --trace --key 000102030405060708090a0b0c0d0e0f \
                             --pt 00112233445566778899aabbccddeeff
  python3 scripts/aes_ref.py --keyexp --key 2b7e151628aed2a6abf7158809cf4f3c
  python3 scripts/aes_ref.py --sbox

Convencao do estado: lista de 16 bytes na ordem de entrada; o byte in[i]
ocupa a linha r = i % 4 e a coluna c = i // 4 (ordem por colunas, FIPS-197 3.4).
"""

import argparse
import sys

# ---------------------------------------------------------------------------
# Aritmetica em GF(2^8) com o polinomio m(x) = x^8 + x^4 + x^3 + x + 1 (0x11B)
# ---------------------------------------------------------------------------

def xtime(b):
    """Multiplica por {02}: desloca 1 bit e reduz por 0x1B se houve estouro."""
    b <<= 1
    return (b ^ 0x11B) & 0xFF if b & 0x100 else b


def gmul(a, b):
    """Multiplicacao em GF(2^8) por somas de xtime (algoritmo 'shift-and-add')."""
    p = 0
    while b:
        if b & 1:
            p ^= a
        a = xtime(a)
        b >>= 1
    return p


def ginv(b):
    """Inverso multiplicativo: b^254 (pois b^255 = 1). Por convencao inv(0) = 0."""
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

# ---------------------------------------------------------------------------
# Transformacoes de rodada
# ---------------------------------------------------------------------------

def sub_bytes(s):
    return [SBOX[b] for b in s]


def inv_sub_bytes(s):
    return [INV_SBOX[b] for b in s]


def shift_rows(s):
    # linha r gira r posicoes para a esquerda: s'[r,c] = s[r, (c+r) mod 4]
    return [s[r + 4 * ((c + r) % 4)] for c in range(4) for r in range(4)]


def inv_shift_rows(s):
    return [s[r + 4 * ((c - r) % 4)] for c in range(4) for r in range(4)]


def _mix(s, m):
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

# ---------------------------------------------------------------------------
# Expansao de chave (FIPS-197 5.2)
# ---------------------------------------------------------------------------

RCON = [0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36]


def key_expansion(key):
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

# ---------------------------------------------------------------------------
# Cifra e decifra
# ---------------------------------------------------------------------------

def encrypt(pt, key, trace=None):
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


def decrypt(ct, key):
    w, nr = key_expansion(key)
    s = add_round_key(list(ct), round_key(w, nr))
    for rnd in range(nr - 1, -1, -1):
        s = inv_shift_rows(s)
        s = inv_sub_bytes(s)
        s = add_round_key(s, round_key(w, rnd))
        if rnd != 0:
            s = inv_mix_columns(s)
    return s

# ---------------------------------------------------------------------------
# Vetores do padrao e CLI
# ---------------------------------------------------------------------------

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


def hx(b):
    return bytes(b).hex()


def selftest():
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
    print("SELFTEST PASSED" if fails == 0 else f"SELFTEST FAILED ({fails} falhas)")
    return fails


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--key", default=FIPS_VECTORS[0][1], help="chave em hex (128/192/256 bits)")
    ap.add_argument("--pt", default=FIPS_VECTORS[0][2], help="texto claro em hex (128 bits)")
    ap.add_argument("--trace", action="store_true", help="imprime o estado rodada a rodada")
    ap.add_argument("--keyexp", action="store_true", help="imprime as palavras w[i] da expansao de chave")
    ap.add_argument("--sbox", action="store_true", help="imprime a S-box 16x16")
    a = ap.parse_args()

    key, pt = bytes.fromhex(a.key), bytes.fromhex(a.pt)
    if a.sbox:
        print("     " + " ".join(f"{c:x}".rjust(2) for c in range(16)))
        for r in range(16):
            print(f"{r:x}0 | " + " ".join(f"{SBOX[16 * r + c]:02x}" for c in range(16)))
    elif a.keyexp:
        w, _ = key_expansion(key)
        for i, word in enumerate(w):
            print(f"w[{i:2d}] = {hx(word)}")
    elif a.trace:
        t = []
        encrypt(pt, key, t)
        for rnd, step, s in t:
            print(f"round[{rnd:2d}].{step:<6} {hx(s)}")
    else:
        sys.exit(1 if selftest() else 0)


if __name__ == "__main__":
    main()

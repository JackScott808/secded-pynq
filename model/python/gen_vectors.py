#!/usr/bin/env python3
"""Generate test vectors for tb_crosscheck.sv from the Python SECDED model.

Each line of vectors.txt (all hex):
    data  err  sent  exp_data  exp_double
"""
import random

N_VECTORS = 5000
SEED = 1
DATA_POSITIONS = [3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]


# ---------- the model (same logic as hamming.py, without the debug print) ----------

def syndrome(cells):
    result = 0
    for address, value in enumerate(cells):
        if value:
            result ^= address
    return result


def encode(data):
    cells = [0] * 16
    for position, bit in zip(DATA_POSITIONS, data):
        cells[position] = bit
    s = syndrome(cells)
    for address in [1, 2, 4, 8]:
        if s & address:
            cells[address] = 1
    if sum(cells) % 2:
        cells[0] = 1
    return cells


def decode(cells):
    cells = list(cells)
    s = syndrome(cells)
    odd = sum(cells) % 2
    if odd:
        cells[s] ^= 1
    elif s:
        raise ValueError("Double error detected")
    return [cells[pos] for pos in DATA_POSITIONS]


# ---------- helpers ----------

def pack(bits):
    """List of bits -> integer, where bits[i] becomes bit i (matches [N:0] vectors)."""
    return sum(bit << i for i, bit in enumerate(bits))


def unpack(value, width):
    """Integer -> list of bits, bit i of value becomes list[i]."""
    return [(value >> i) & 1 for i in range(width)]


def hw_decode(cells):
    """Model of what the hardware decoder outputs: (data_bits, double_err).

    On a double error the hardware passes the *received* data cells through,
    so we catch the ValueError and read the uncorrected cells.
    """
    try:
        return decode(cells), 0
    except ValueError:
        return [cells[pos] for pos in DATA_POSITIONS], 1


# ---------- generate ----------

def main():
    random.seed(SEED)
    count = 0
    with open("vectors.txt", "w") as f:
        for _ in range(N_VECTORS):
            data = random.getrandbits(11)
            weight = random.randint(0, 5)          # includes 3, 4, 5 on purpose
            err = 0
            for cell in random.sample(range(16), weight):
                err |= 1 << cell

            sent_cells = encode(unpack(data, 11))
            sent = pack(sent_cells)
            received = unpack(sent ^ err, 16)

            exp_bits, exp_double = hw_decode(received)
            exp_data = pack(exp_bits)

            f.write(f"{data:03x} {err:04x} {sent:04x} {exp_data:03x} {exp_double:x}\n")
            count += 1
    print(f"wrote {count} vectors to vectors.txt")


if __name__ == "__main__":
    main()

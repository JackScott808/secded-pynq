#!/usr/bin/env python3
"""Generate test vectors for tb_crosscheck.sv from the Python SECDED model.

Each line of vectors.txt (all hex):
    data  err  sent  exp_data  exp_double
"""
import random

from hamming import encode, hw_decode, pack, unpack

N_VECTORS = 5000
SEED = 1


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

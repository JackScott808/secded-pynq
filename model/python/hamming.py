#!/usr/bin/env python3
"""SECDED Hamming (16,11) reference model.

This is the specification the hardware was built against: the 16 cells are laid
out as a 4x4 grid, cell i has address i, the parity cells sit at the addresses
with a single 1 in their binary form (1, 2, 4, 8), and cell 0 is overall parity.

Cells are lists of 16 bits, LSB first, so cells[i] is the cell at address i.
Data is a list of 11 bits in DATA_POSITIONS order.
"""

DATA_POSITIONS = [3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]
PARITY_POSITIONS = [1, 2, 4, 8]


def syndrome(cells):
    """XOR of the addresses of every cell holding a 1.

    For a clean word this is 0; for a single flipped cell it is that cell's
    address. Note it is the address that is XORed, not the value: getting that
    the wrong way round still passes some test grids, so test_hamming.py pins it.
    """
    result = 0
    for address, value in enumerate(cells):
        if value:
            result ^= address
    return result


def encode(data):
    """11 data bits -> 16 cells with the parity cells filled in."""
    cells = [0] * 16
    # put the 11 data bits in the non-parity positions
    for position, bit in zip(DATA_POSITIONS, data):
        cells[position] = bit

    s = syndrome(cells)
    for address in PARITY_POSITIONS:
        if s & address:  # is this bit set in s?
            cells[address] = 1

    if sum(cells) % 2:  # if odd total parity, set cell 0 to 1
        cells[0] = 1

    return cells


def decode(cells):
    """16 cells -> the 11 data bits, correcting a single error.

    Raises ValueError on a double error, which cannot be corrected: the syndrome
    then points at an innocent cell, so correcting would corrupt the word.
    """
    cells = list(cells)  # make a copy so the caller's list is not changed
    s = syndrome(cells)
    odd = sum(cells) % 2
    if odd:  # single error
        cells[s] ^= 1
    elif s:  # double error
        raise ValueError("Double error detected")
    return [cells[pos] for pos in DATA_POSITIONS]


# ---------- helpers shared by gen_vectors.py and the tests ----------

def pack(bits):
    """List of bits -> integer, where bits[i] becomes bit i (matches [N:0] vectors)."""
    return sum(bit << i for i, bit in enumerate(bits))


def unpack(value, width):
    """Integer -> list of bits, bit i of value becomes list[i]."""
    return [(value >> i) & 1 for i in range(width)]


def hw_decode(cells):
    """Model of what the hardware decoder outputs: (data_bits, double_err).

    On a double error the hardware passes the *received* data cells through
    rather than raising, so the consumer must honour double_err.
    """
    try:
        return decode(cells), 0
    except ValueError:
        return [cells[pos] for pos in DATA_POSITIONS], 1

#!/usr/bin/env python3
"""Tests for the SECDED reference model.

The guarantees SECDED makes are checked exhaustively: every one of the 2048 data
values against no error, every single flip, and every pair of flips. That is the
same coverage tb_decoder.sv has in hardware, so a disagreement between model and
RTL is a real difference and not a gap in one of the test sets.

Run with:  python3 -m pytest
"""

from itertools import combinations

import pytest

from hamming import (
    DATA_POSITIONS,
    decode,
    encode,
    hw_decode,
    pack,
    syndrome,
    unpack,
)

ALL_DATA = [unpack(value, 11) for value in range(2048)]
CELLS = range(16)
PAIRS = list(combinations(CELLS, 2))  # 120 of them


def test_clean_codewords_have_zero_syndrome_and_even_parity():
    for data in ALL_DATA:
        cells = encode(data)
        assert syndrome(cells) == 0
        assert sum(cells) % 2 == 0


def test_clean_codewords_decode_back_to_the_data():
    for data in ALL_DATA:
        assert decode(encode(data)) == data


def test_every_single_bit_error_is_corrected():
    for data in ALL_DATA:
        good = encode(data)
        for cell in CELLS:
            bad = list(good)
            bad[cell] ^= 1
            assert decode(bad) == data, f"failed at cell {cell}"


def test_every_double_bit_error_is_detected():
    for data in ALL_DATA:
        good = encode(data)
        for i, j in PAIRS:
            bad = list(good)
            bad[i] ^= 1
            bad[j] ^= 1
            with pytest.raises(ValueError):
                decode(bad)


def test_syndrome_xors_the_address_not_the_value():
    """Pins the bug the first model had: it XORed cells[value], not the address.

    The wrong version still passes some grids, so this picks a word where the
    two disagree.
    """
    cells = [0] * 16
    cells[5] = 1
    cells[9] = 1
    assert syndrome(cells) == 5 ^ 9


def test_minimum_distance_is_four():
    # SECDED needs distance 4: correct any one error, detect any two.
    weights = [sum(encode(data)) for data in ALL_DATA if any(data)]
    assert min(weights) == 4


def test_decode_does_not_modify_its_input():
    bad = encode(unpack(0x5A5, 11))
    bad[6] ^= 1
    before = list(bad)
    decode(bad)
    assert bad == before


# ---------- the hardware's view ----------


def test_hw_decode_flags_double_errors_and_passes_data_through():
    data = unpack(0x5A5, 11)
    good = encode(data)
    bad = list(good)
    bad[3] ^= 1
    bad[6] ^= 1

    bits, double_err = hw_decode(bad)
    assert double_err == 1
    assert bits == [bad[pos] for pos in DATA_POSITIONS]  # uncorrected, as documented


def test_hw_decode_reports_no_error_when_it_corrects():
    data = unpack(0x5A5, 11)
    bad = encode(data)
    bad[6] ^= 1

    bits, double_err = hw_decode(bad)
    assert double_err == 0
    assert bits == data


# ---------- documented limit ----------


def test_three_errors_are_miscorrected_silently():
    # Not a bug: SECDED guarantees nothing beyond two errors.
    data = unpack(0x5A5, 11)
    bad = encode(data)
    for cell in (3, 6, 9):
        bad[cell] ^= 1

    assert syndrome(bad) == 3 ^ 6 ^ 9 == 12
    assert decode(bad) != data  # silently wrong, and nothing flags it


# ---------- helpers ----------


def test_pack_and_unpack_round_trip():
    for value in (0, 1, 0x5A5, 0x7FF):
        assert pack(unpack(value, 11)) == value

#!/usr/bin/env python3

grid = [1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

data =  [1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0]

DATA_POSITIONS = [3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]

def syndrome(grid):
    result = 0
    for address, value in enumerate(grid):
        if value:
            result ^= address
    return result

def encode(data):
    cells = [0] * 16
    # put the 11 data bits in the non-parity positions
    # (3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15)
    for position, bit in zip(DATA_POSITIONS, data):
        cells[position] = bit

    s = syndrome(cells)
    for address in [1, 2, 4, 8]:
        if s & address: # is this bit set in s?
            cells[address] = 1
    print('parity bits set correctly check, should return zero:', syndrome(cells))

    if sum(cells) % 2: # if odd total parity, set cell 0 to 1
        cells[0] = 1

    return cells

def decode(cells):
    cells = list(cells) # make a copy so the caller's list is not changed
    s = syndrome(cells)
    odd = sum(cells) % 2
    if (odd): # single error
        cells[s] ^= 1
    elif (s): # double error
        raise ValueError("Double error detected")
    return [cells[pos] for pos in DATA_POSITIONS]

# ---------- TESTS ----------

good = encode(data)

bad = list(good); bad[6] ^= 1 # flip cell 6 which is a data cell
print(decode(bad) == data)

bad = list(good); bad[4] ^= 1 # flip cell 4 which is a parity cell
print(decode(bad) == data)

bad = list(good); bad[0] ^= 1 # flip cell 0
print(decode(bad) == data)

bad = list(good); bad[3] ^= 1; bad[6] ^= 1   # two cells
try:
    decode(bad)
except ValueError as e:
    print('caught:', e)

# exhaustive check (1 bit flip)
for i in range(16):
    bad = list(good); bad[i] ^= 1
    assert decode(bad) == data, f"failed at cell {i}"
print("All 16 single-bit errors corrected")

# exhaustive check (2 bit flip)
count = 0
for i in range(16):
    for j in range(i + 1, 16):
        bad = list(good)
        bad[i] ^= 1
        bad[j] ^= 1
        try:
            decode(bad)
        except ValueError:
            count += 1
        else:
            raise AssertionError(f"double error at cells {i}, {j} not detected")
assert count == 120
print("All 120 double-bit errors detected")

print('--------------------')
good = encode(data)
print(good)
bad = list(good)
bad[3] ^= 1
bad[6] ^= 1
bad[9] ^= 1
s = syndrome(bad)
print('syndrome is: ', s)
print('does decoding triple bit error give data?: ', decode(bad) == data)

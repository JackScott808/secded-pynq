# SECDED Hamming (16,11) Encoder/Decoder with On-Chip Self-Test

A hardware implementation of an extended Hamming code, **single-error correct,
double-error detect (SECDED)**, written in SystemVerilog, verified against a
Python reference model, and run on a PYNQ-Z2 (Zynq-7020) with a built-in
self-test that sweeps every guaranteed case on the chip.

This is the same class of code used for ECC memory. 11 data bits are protected
by 5 check bits in a 16-bit word.

I built it to learn error-correcting codes from first principles: pen-and-paper
on a 4x4 grid, then a Python model, then RTL, then silicon. Each stage was
checked against the one before it.

## How the code works

The 16 bits are laid out as a 4x4 grid. Cell `i` has address `i` (0 to 15). Four
parity cells sit at the addresses with a single 1 in their binary form (1, 2, 4,
8), and cell 0 is an overall parity bit.

```
 p0   p1   p2   d0         cell:  0  1  2  3
 p4   d1   d2   d3                4  5  6  7
 p8   d4   d5   d6                8  9 10 11
 d7   d8   d9   d10              12 13 14 15
```

Each of four checks covers the cells whose address has a given bit set, so each
check is a 16-bit mask:

| Check | Address bit | Mask |
|---|---|---|
| Q1 | bit 0 | `16'hAAAA` |
| Q2 | bit 1 | `16'hCCCC` |
| Q3 | bit 2 | `16'hF0F0` |
| Q4 | bit 3 | `16'hFF00` |

A check's result is the XOR (parity) of the masked cells. The four results, read
as a 4-bit number, form the **syndrome**, and a single flipped bit makes the
syndrome equal that bit's address. The overall parity (`odd`, the XOR of all 16
cells) separates single from double errors:

| Syndrome | Overall parity | Meaning | Action |
|---|---|---|---|
| 0 | even | no error | none |
| any | odd | single error at address `s` (cell 0 if `s = 0`) | flip cell `s` |
| non-zero | even | double error | flag `double_err`, do not correct |

Equivalent view: the syndrome is the XOR of the addresses of every cell holding
a 1. This is how the Python model computes it, and the hardware does it with
four reduction-XOR trees.

## Design

```
data[10:0] --> encoder --> cells[15:0] --XOR-- err --> received --> decoder --> data[10:0], double_err
                                                                      |
                                                                      +-- syndrome (reused module)
```

| File | Role |
|---|---|
| `syndrome.sv` | Four masked reduction-XORs plus overall parity |
| `encoder.sv` | Places the 11 data bits, computes the four parity cells, then cell 0 |
| `decoder.sv` | Syndrome, one-hot correction mask gated by `odd`, double-error flag, data extraction |
| `bist_sweep.sv` | Test sequencer: every data value against no error, each single flip, each double flip |
| `bist_top.sv` | PYNQ-Z2 top level: encoder, error injection, decoder, checker, result registers, LEDs |

Design decisions:

- **No lookup tables or loops in hardware.** The Python `for` loop over cell
  addresses becomes four XOR trees, and `cells[s] ^= 1` becomes a one-hot mask
  XORed with the word.
- **Correction is gated by overall parity.** `mask = odd ? (1 << s) : 0`. On a
  double error the decoder must not "fix" a healthy cell. The testbench checks
  the data output on every double error, and removing the gate fails 88 of the
  120 pairs per data value.
- **On a double error the decoder passes the received data through uncorrected**
  and raises `double_err`. The consumer must honour the flag. This is documented
  and enforced by the tests.
- **Self-test.** The board has 4 LEDs, 4 buttons and 2 switches, which is far
  too little to inject 16 error positions by hand, so the sweep runs on the chip
  and reports pass or fail.
- **`done` is delayed one cycle** so the final test's result is already in the
  sticky fail flag when `pass` is read.

## Verification

All testbenches are self-checking. Each prints `all tests passed` or a failure
count and reports at most the first ten failures. Simulated with Verilator 5.052
(`--binary --timing -Wall`).

| Testbench | What it checks | Cases |
|---|---|---|
| `tb_syndrome` | Clean word gives `s = 0`, every single flip gives `s = address` and `odd = 1` | 17 |
| `tb_encoder` | Every data value encodes to a valid codeword (`s = 0`, `odd = 0`) | 2,048 |
| `tb_decoder` | No error, every single flip is corrected, every double flip is flagged and data is passed through | 2,048 + 32,768 + 245,760 |
| `tb_crosscheck` | Encoder and decoder match the Python model on random data with 0 to 5 random flips (seeded, includes the 3+ flip miscorrection cases) | 5,000 |
| `tb_bist_sweep` | Sequencer output matches an independent reference model on every cycle, end state and reset | 559,104 cycles |
| `tb_bist_top` | Full BIST: a clean copy ends in PASS and a copy with fault injection ends in FAIL | 2 instances |

For the guarantees SECDED makes (any single error corrected, any double error
detected) the simulation is exhaustive over the input space: every data word and
every error pattern of weight 0, 1 or 2.

### Do the tests actually fail?

Each testbench was checked by deliberately breaking the design:

| Deliberate bug | Result |
|---|---|
| `p4 ^ p4` instead of `p4 ^ p8` in cell 0 | 1024 of 2048 encodings invalid (`tb_encoder`); 4642 failed checks in `tb_crosscheck` |
| Two data positions swapped between model and hardware | 3786 failed checks in `tb_crosscheck` |
| Correction mask not gated by `odd` | 180,224 failures (88 per data value) in `tb_decoder`; the single-error tests alone did not catch it |
| Pair condition `i < j` changed to `i <= j` | `tb_bist_sweep` reports 313,344 valid tests instead of 280,576 |
| Wrap at `t == 271` instead of 272 | `tb_bist_sweep` fails from the first wrap |
| `!done` guard removed from the sequencer | `tb_bist_sweep` fails |

The gate-removal case is worth noting: the single-error and no-error tests all
passed without the gate, because the faulty correction only changes a non-data
cell there. Only the double-error test checking the data output exposes it.

### Known limit of the code

SECDED guarantees nothing for 3 or more errors. Three flips look like a single
error and are miscorrected. Example: flipping cells 3, 6 and 9 gives syndrome 12
with odd parity, so the decoder "corrects" healthy cell 12 and returns wrong
data with no error flag. The Python model and the hardware agree on these cases,
but the code itself cannot detect them.

## Self-test on the board

`bist_sweep` runs 273 tests for each of the 2048 data values (559,104 cycles,
about 4.5 ms at 125 MHz): no error, 16 single flips, and a 16x16 grid of cell
pairs of which 120 are real double errors (`i < j`, the rest are skipped). That
makes 137 checked tests per data value and 280,576 in total. The checker expects
the correction for single and no-error tests, and `double_err` with data passed
through for pairs.

| LED | Meaning |
|---|---|
| LD0 | sweep done |
| LD1 | PASS (done and no failure) |
| LD2 | FAIL (sticky) |
| LD3 | heartbeat (about 1 Hz), shows the clock is running |

`BTN0` restarts the sweep. `SW0` deliberately flips one output bit, so the
checker must report FAIL. That shows the self-test can detect a fault rather
than only ever showing PASS.

Observed on the board: all of the following behaved as expected.

1. Power-up with `SW0` low: LD0 and LD1 on, LD2 off, LD3 blinking.
2. Hold `BTN0`: all four LEDs off while held.
3. `SW0` high: LD2 lights, LD1 goes off.
4. `SW0` back low: LD2 stays lit (sticky).
5. `BTN0` with `SW0` low: back to PASS.
6. `SW0` high then `BTN0`: FAIL, never PASS.

<!-- TODO: add a photo or short video of the board for these states -->

## Implementation results

Target: PYNQ-Z2 (Zynq-7020, `xc7z020clg400-1`), 125 MHz clock constraint (8 ns).

| Metric | Result |
|---|---|
| Worst negative slack (setup) | +4.008 ns |
| Worst hold slack | +0.175 ns |
| Worst pulse width slack | +3.500 ns |
| Failing endpoints | 0 of 126 |
| LUTs / FFs | <!-- TODO from report_utilization --> |
| Power | <!-- TODO from report_power --> |

All user timing constraints are met. I have not run implementation at a tighter
clock, so I make no claim about maximum frequency.

Pins (from the official PYNQ-Z2 constraints file):

| Port | Pin |
|---|---|
| `clk` | H16 |
| `btn_rst` | D19 (BTN0) |
| `sw_inject` | M20 (SW0) |
| `led[3:0]` | M14, N16, P14, R14 |

## Reproducing

Simulation (from the folder with the sources):

```bash
python3 gen_vectors.py                     # writes vectors.txt from the Python model

verilator --binary --timing -Wall --top-module tb_crosscheck \
    syndrome.sv encoder.sv decoder.sv tb_crosscheck.sv && ./obj_dir/Vtb_crosscheck

verilator --binary --timing -Wall --top-module tb_bist_top \
    syndrome.sv encoder.sv decoder.sv bist_sweep.sv bist_top.sv tb_bist_top.sv && ./obj_dir/Vtb_bist_top
```

Board: create a Vivado project for `xc7z020clg400-1`, add the design files and
`pynq_z2.xdc`, set `bist_top` as the top module, then run synthesis,
implementation and bitstream generation.
<!-- TODO: add your Vivado version -->

## Python reference model

`hamming.py` is the model the hardware was built against: `syndrome`, `encode`,
and `decode` (which raises `ValueError` on a double error). `gen_vectors.py`
uses it to produce the vectors that `tb_crosscheck` replays against the
hardware.

## What the testing found

- The first Python `syndrome` tested `grid[value]` instead of `value`. It passed
  my first two test grids and would have failed on the third, so I added a test
  that the wrong version fails.
- A one-token typo in the hardware (`p4 ^ p4`) is legal code and only a test
  catches it, which is why every testbench was also run against a deliberately
  broken design.
- Several early checks passed vacuously, such as checking an unassigned signal,
  or printing "passed" regardless of the result. Every testbench now fails
  loudly, counts errors and only reports success when the count is zero.

## Limitations and next steps

- 3 or more errors are not detected or corrected reliably (see above).
- Parameterise the width to generate other SECDED sizes, such as (72,64) used in
  ECC memory.
- Report results over UART with cycle and failure counters, to get a log from
  silicon.
- Replay the Python `vectors.txt` on the board (for example over AXI GPIO under
  a PYNQ image).
- Run the testbenches against the post-implementation netlist.

## Credits

The 4x4 grid presentation of Hamming codes follows the 3Blue1Brown video on
Hamming codes.

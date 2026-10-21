# Design: shuf

## Overview

`cli.app.run` parses the arguments into an `Options` class, handles
`--help`/`--version`, and calls `commands.shuf.run_shuf`, which checks the
paths, gathers the input, seeds a `Sampler` and writes a selection through
an `Output`. Everything is host.dual and builds natively.

## Modules

| Module | Contents |
| --- | --- |
| `source/main.loup` | `main()`: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, exit statuses |
| `source/cli/args.loup` | `Options`, `ArgError` (classes), `parse_args`, `parse_number`, `parse_count`, `parse_range`; getopt-style parsing with long-option prefixes |
| `source/cli/usage.loup` | `usage()`, `version_line()` |
| `source/cli/app.loup` | `run(argv)` and error reporting |
| `source/commands/shuf.loup` | `run_shuf`, `select_lines`, `select_numbers`, `repeat_pick`, `make_sampler` |
| `source/commands/sampler.loup` | `Sampler` (a seeded `core.random.Random`: `below`, `shuffled`, `pick`), `SparsePermutation`, `mix_seed` |
| `source/commands/seed.loup` | `clock_seed` (`system.time.realtimeNs`), `seed_from_bytes` (FNV-1a), `random_source_seed` (`head -c 64` through `exec`) |
| `source/commands/lines.loup` | `split_lines`, `read_input`, `range_lines` (`system.collections.rangeFrom`) |
| `source/commands/output.loup` | `Output` (blocks of lines to standard output or the -o file), `check_output` |

## Randomness

`core.random.Random` is a 64-bit linear congruential generator and
`intRange(lo, hi)` returns its next output modulo `hi - lo`. The low bits of
such a generator have short periods, so its own `shuffle` and `choice`
(which draw below small n) are biased: two-way choices alternate, and
`shuffle` reaches only 12 of the 24 orders of four lines. shuf therefore:

- mixes the seed with SplitMix64's finalizer (`mix_seed`), so that nearby
  seeds and clock readings start unrelated sequences;
- draws `below(n)` as `intRange(0, n << 32) >> 32` for n < 2^31, which
  keeps the generator's high bits (larger n use `intRange(0, n)`);
- shuffles with its own Fisher-Yates over `below`, and picks `-r` lines
  with `below`.

`SparsePermutation` is Fisher-Yates over a virtual array: a dictionary
holds only the entries that moved, so k draws from a range of any size
cost O(k). Ranges of up to 4,096 numbers are listed with `rangeFrom` and
shuffled like lines; larger ones always use the sparse permutation
(`rangeFrom` builds its list by concatenation, quadratic in its length).

## Data flow

1. Check `--random-source` exists and `-o` can be written.
2. `-n 0`: write nothing (an `-o` file is created) and stop.
3. Gather the lines (`-e` operands, a listed range, or the file's lines) or
   the size of a large range.
4. `-r` with no lines: `no lines to repeat`.
5. Make the Sampler only when there are at least two lines (a random
   source is read only then).
6. Write: picks until the count runs out (`do`/`while`, forever without
   `-n`), or the selection (`select_lines`, `select_numbers`).

## Native constraints

- `Options` and `ArgError` are classes: structs that cross modules break
  natively when another type shares field names.
- Named arguments are used only within a module (`usage_error(msg,
  try_help = false)`); across modules the native build passes them wrongly.
- No guard on the first arm of a `match`; no tuples in per-line loops (the
  only tuple is `parse_range`'s result).
- `readText` of a missing file ends a native program, so paths are checked
  first; `exec`'s fields are read in the function that called it.
- Output goes out in blocks of 4,096 lines from one reused list.

## Error handling

Command-line errors are `ArgError` values (message, Try line or not);
runtime errors are messages returned by the helpers and printed by
`run_shuf`; an unexpected exception becomes status 1 in `run`.

## Testing

- Unit tests (Stage0): `args_test` (options, prefixes, every message),
  `sampler_test` (SplitMix64 vectors, uniform draws, all 24 orders,
  sparse permutations), `input_test` (lines, ranges, FNV-1a vectors,
  random sources), `shuf_test` (selections, `run` with `-o` files and
  statuses).
- `tests/e2e.sh` runs the native binary with fixed seeds and states every
  expected output, plus unseeded runs checked by sorting.

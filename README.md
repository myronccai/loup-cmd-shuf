# loup-cmd-shuf

GNU `shuf` recreated in [Loup](https://code-craft.ai/references/loup): write a
random permutation of the input lines, the `-e` arguments or an `-i LO-HI`
range of numbers, with `-n`, `-r`, `-z`, `-o` and `--random-source`, plus a
`--seed` option that makes the output reproducible.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It is the series'
example of `core.random`, `system.collections.rangeFrom` and `system.time`.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.
- `head` (coreutils) for `--random-source`.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                 # native binary: build/shuf
make run ARGS="--seed 7 -e red green blue"   # loup run source/main.loup -- ARGS
make ci                    # check, unit tests, build, end-to-end tests
```

```text
$ cat names.txt
alice
bob
carol
dave
$ build/shuf --seed 42 names.txt
carol
dave
bob
alice
$ build/shuf --seed 42 -n 2 names.txt
carol
dave
$ build/shuf --seed 7 -e red green blue
blue
green
red
$ build/shuf --seed 3 -i 1-10 | tr '\n' ' '
9 8 4 5 7 10 6 3 2 1
$ build/shuf --seed 3 -i 1-1000000000 -n 3
956379221
866927163
90539297
$ build/shuf --seed 2 -r -n 6 -e heads tails | tr '\n' ' '
tails heads tails tails heads heads
$ build/shuf --seed 5 -r -n 1000 -e heads tails | sort | uniq -c
    484 heads
    516 tails
$ seq 5 | build/shuf --random-source=names.txt | tr '\n' ' '
3 5 1 4 2
$ time build/shuf -i 1-1000000 > /dev/null
real	0m0.337s
$ build/shuf --seed 1 -o names.txt names.txt && cat names.txt
alice
bob
dave
carol
$ build/shuf -e -i 1-3
shuf: cannot combine -e and -i options
Try 'shuf --help' for more information.
```

Without `--seed` or `--random-source` every run differs: the clock seeds
the generator.

### Options

| Option | Meaning |
|---|---|
| `-e`, `--echo` | treat each operand as an input line |
| `-i`, `--input-range=LO-HI` | the numbers LO through HI are the input lines (`5-4` is empty) |
| `-n`, `--head-count=COUNT` | write at most COUNT lines (the smallest of several `-n`; `-n 0` reads nothing) |
| `-o`, `--output=FILE` | write to FILE, after all input is read (FILE may be the input) |
| `--random-source=FILE` | seed from the first 64 bytes of FILE: the same file gives the same order |
| `-r`, `--repeat` | draw every output line from all the input lines; without `-n`, never stop |
| `-z`, `--zero-terminated` | lines end with NUL, not newline, on input and output |
| `--seed=NUMBER` | seed the generator with NUMBER (an extension: not in GNU shuf) |
| `--help` / `--version` | help text / `shuf (loup-cmd-shuf) 0.1.0` |

With no FILE, or when FILE is `-`, shuf reads standard input. Options may
come anywhere, short ones combine (`-rn5`), and long ones may be shortened
to any unambiguous prefix (`--head=2`). `--seed` and `--random-source`
exclude each other.

Exit status: `0` success, `1` any error (usage errors included, as in GNU
shuf).

## How it works

- **`core.random`**: a `Random(seed)` generator. `Random` is a 64-bit
  linear congruential generator, and `intRange(lo, hi)` returns its next
  output modulo `hi - lo`, which for small ranges uses its low bits: those
  repeat with short periods (bit 0 simply alternates). shuf therefore asks
  `intRange` for a number below `n * 2^32` and keeps the upper part, and
  scrambles the seed first with SplitMix64's finalizer so that seeds 1, 2,
  3 give unrelated orders. Every one of the 24 orders of four lines comes
  out about equally often (a unit test counts them over 1,200 seeds).
- **Large ranges are never listed.** `-i 1-1000000000 -n 3` draws three
  numbers from a sparse Fisher-Yates permutation that stores only the
  entries it has moved. Ranges of up to 4,096 numbers are listed with
  `system.collections.rangeFrom` and shuffled like lines.
- **Seeds**: `system.time.realtimeNs()` for the default; FNV-1a over the
  bytes `head -c 64` reads from a `--random-source` (reading the whole file
  would never end for `/dev/urandom`).
- The same seed gives the same output natively, under `loup run` and under
  Stage0, so the tests state exact expected output.

## Differences from GNU shuf

- The random orders differ from GNU's for the same `--random-source`:
  GNU reads its random numbers from the file as it goes, this shuf seeds
  its generator from the file's first 64 bytes. An empty random source is
  an error only when a random choice is needed, as in GNU; one shorter than
  GNU would need is fine.
- `--seed` is an extension. The generator is not cryptographic.
- core.random's own `shuffle` and `choice` are not used: drawing straight
  from `intRange(0, n)` they are biased (see above).
- Messages quote with ASCII apostrophes (`'5-3'`), as in the C locale.
- Natively, write errors on standard output (`> /dev/full`) are not
  reported.

## Layout

```text
source/main.loup              # entry point
source/appinfo.loup           # name, version, exit statuses
source/cli/args.loup          # GNU getopt-style option parsing
source/cli/usage.loup         # --help and --version text
source/cli/app.loup           # run(): parse, report, exit status
source/commands/shuf.loup     # run_shuf() and the selections
source/commands/sampler.loup  # Sampler (core.random), SparsePermutation, mix_seed
source/commands/seed.loup     # --seed, --random-source, clock seeds
source/commands/lines.loup    # input lines and listed ranges (rangeFrom)
source/commands/output.loup   # standard output or the -o file, in blocks
tests/*_test.loup             # unit tests (make test)
tests/e2e.sh                  # end-to-end tests of build/shuf (make e2e)
specs/shuf/                   # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.

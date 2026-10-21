# AGENTS.md

This repository is `shuf`, GNU `shuf` recreated in the Loup programming
language, part of the loup-cmd series of example applications. It is
`host.dual` Loup built as a native executable (`build/shuf`); `loup run`
interprets the same sources.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── LICENSE                      # MIT license (copyright Code Craft AI LLC)
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses
│   ├── cli/
│   │   ├── args.loup            # class Options, class ArgError, parse_args(), value parsers
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(): parse, report errors, --help/--version, run_shuf
│   └── commands/
│       ├── shuf.loup            # run_shuf(), select_lines(), select_numbers(), repeat_pick()
│       ├── sampler.loup         # class Sampler (core.random), class SparsePermutation, mix_seed()
│       ├── seed.loup            # clock_seed(), seed_from_bytes(), random_source_seed()
│       ├── lines.loup           # split_lines(), read_input(), range_lines() (rangeFrom)
│       └── output.loup          # class Output, check_output()
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void
│   └── e2e.sh                   # end-to-end tests of build/shuf
├── specs/shuf/                  # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup, runs `make ci`, uploads build/shuf
└── build/                       # build output and test files (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="--seed 7 -e a b c"` | `loup run source/main.loup -- ARGS` |
| Type-check | `make check` | checks `source/main.loup` and every module it imports |
| Run all tests | `make test` | every `tests/*_test.loup`, `--no-parallel`; files go to `build/tmp/` |
| Run matching tests | `make test TEST_ARGS="--filter range"` | |
| Build | `make build` | native binary at `build/shuf` |
| End-to-end tests | `make e2e` | `tests/e2e.sh build/shuf`: exact output for fixed seeds |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/shuf --version` |
| Clean | `make clean` | removes `build/` and `.temp/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`. Do not call `loup test` or `loup check` directly on
Linux x86-64: the Makefile uses `loup-bootstrap` (Stage0) for both, with
`LOUPPATH=source` for tests.

## Making a change

1. Update the spec in `specs/shuf/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update tests in `tests/` and cases in `tests/e2e.sh`. Expected
   random output comes from a fixed `--seed`; it is the same in every lane.
4. Run `make ci`.
5. Tick the finished tasks in `specs/shuf/tasks.md`.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`. Modules import each other by path from
  `source/` (`from cli.args import (Options);`).
- Behaviour lives in functions that return values; only `run_shuf` reads
  files and writes output.
- Values that cross modules are classes (`Options`, `ArgError`, `Sampler`),
  not structs: native builds corrupt such structs when another type shares
  a field name.
- Draw random numbers with `Sampler.below`, never with core.random's
  `intRange(0, n)`, `shuffle` or `choice` directly: their small draws come
  from the generator's weak low bits (see `commands/sampler.loup`).
- Native-build rules this code follows: named arguments only within a
  module; no guard on the first arm of a `match`; no tuples in per-line
  loops; check paths before `readText`/`writeText` (natively their failures
  end the program); read `exec`'s fields in the calling function.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.

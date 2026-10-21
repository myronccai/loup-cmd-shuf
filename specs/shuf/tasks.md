# Tasks: shuf

- [x] 1. Rename the template (package, Makefile, CI artifact) and add the
  `e2e` target.
  - _Requirements: 1.5_
- [x] 2. `cli/args.loup`: getopt-style parsing, prefixes, values, conflicts;
  unit tests.
  - _Requirements: 1.1, 1.2, 1.3, 1.4_
- [x] 3. `commands/lines.loup`: reading, splitting, `-z`, listed ranges;
  unit tests.
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
- [x] 4. `commands/sampler.loup`: seed mixing, `below`, Fisher-Yates,
  sparse permutation, picks; unit tests including uniformity.
  - _Requirements: 3.1, 3.3, 3.4, 4.1_
- [x] 5. `commands/seed.loup`: `--seed`, `--random-source`, the clock;
  unit tests.
  - _Requirements: 4.1, 4.2, 4.3_
- [x] 6. `commands/output.loup` and `commands/shuf.loup`: `-n`, `-r`, `-o`,
  `-n 0`; unit tests.
  - _Requirements: 3.2, 3.3, 3.5_
- [x] 7. End-to-end tests against the native binary.
  - _Requirements: all_
- [x] 8. README, AGENTS.md, file headers; `make ci` green locally and on
  GitHub.

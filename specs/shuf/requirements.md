# Requirements: shuf

## Introduction

`shuf` writes a random permutation of its input lines, like GNU coreutils
`shuf`: the lines of a file or standard input, the arguments of `-e`, or the
numbers of an `-i LO-HI` range. `-n` limits the output, `-r` draws with
replacement, `-z` uses NUL as the line delimiter and `-o` writes to a file.
A documented `--seed` extension makes the output reproducible; it is what
the tests use. The program is a host.dual Loup command built as a native
binary; its purpose in the loup-cmd series is to show `core.random`,
`system.collections.rangeFrom` and `system.time` in a program that needs
them.

## Requirements

### Requirement 1: command line

**User Story:** As a shell user, I want GNU shuf's options so that my
scripts work unchanged.

#### Acceptance Criteria

1. WHEN options are given, THE parser SHALL accept them anywhere among the
   operands, clustered short options, values attached or in the next word,
   `--name=VALUE`, unambiguous prefixes of long options, and `--` to end
   the options.
2. WHEN an option is unknown, ambiguous, misses its value or takes none,
   THE program SHALL print GNU getopt's message and `Try 'shuf --help' for
   more information.` on standard error and exit 1.
3. WHEN `-e` and `-i` are combined, or there are operands with `-i` or more
   than one FILE, THE program SHALL report it with the Try line and exit 1.
4. WHEN a count, range or seed is invalid, or `-i`, `-o` or a random source
   is given twice, THE program SHALL report it without the Try line and
   exit 1.
5. WHEN `--help` or `--version` is given, THE program SHALL print the help
   text or `shuf (loup-cmd-shuf) 0.1.0` and exit 0.

### Requirement 2: input

**User Story:** As a user, I want to shuffle lines, arguments or numbers.

#### Acceptance Criteria

1. WHEN no `-e` or `-i` is given, THE program SHALL read the lines of FILE,
   or of standard input when FILE is absent or `-`; a missing file or a
   directory SHALL be reported (`shuf: F: No such file or directory`,
   `shuf: read error: Is a directory`) with exit status 1.
2. WHEN `-e` is given, every operand SHALL be one input line.
3. WHEN `-i LO-HI` is given, the numbers LO through HI SHALL be the lines;
   HI may be LO - 1 (no lines).
4. WHEN `-z` is given, lines SHALL be delimited by NUL on input and output.
5. WHEN the last line has no delimiter, it SHALL still be a line, and the
   output SHALL end it with the delimiter.

### Requirement 3: output

**User Story:** As a user, I want random orders I can rely on.

#### Acceptance Criteria

1. WHEN shuf runs without `-r`, THE output SHALL be a permutation of the
   input lines in which every order is equally likely.
2. WHEN `-n COUNT` is given, at most COUNT lines SHALL be written; with
   several `-n` the smallest SHALL count; `-n 0` SHALL read nothing.
3. WHEN `-r` is given, every output line SHALL be drawn independently from
   all the input lines, COUNT times with `-n`, else without end; an empty
   input SHALL be reported as `no lines to repeat`.
4. WHEN `-i` has a large range, THE program SHALL not list it: drawing
   COUNT numbers SHALL take time and memory in proportion to COUNT.
5. WHEN `-o FILE` is given, the output SHALL go to FILE, written after all
   input is read (so FILE may also be the input); a directory or a missing
   parent directory SHALL be reported with exit status 1.

### Requirement 4: randomness

**User Story:** As a tester, I want reproducible output; as a user, I want
different output every run.

#### Acceptance Criteria

1. WHEN `--seed N` is given, the same N and input SHALL give the same
   output, natively and under both Loup interpreters.
2. WHEN `--random-source FILE` is given, the seed SHALL come from FILE's
   first 64 bytes, so the same file gives the same output; a missing file
   SHALL be an error at once, an empty one (`end of file`) when a random
   choice is needed.
3. WHEN neither is given, the seed SHALL come from the wall clock in
   nanoseconds.

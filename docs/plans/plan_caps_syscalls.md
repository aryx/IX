# Plan: a capability for every system call (`Cap`, `capabilities.dl`)

The author (2026-11-03), on what `capabilities.dl` called "not
authority": "the clock, pipes and, more generally, every system call
should require a capability. That was the idea behind ocaml-caps."

The short answer: **every function of lib_core's `Unix` and `Sys` falls
in one of four groups: it already needs a capability (35 of them), it
acts on a descriptor already held (26), it computes and does nothing
to the world (6), or it needs one it did not (9, plus `Sys.time` and
`Sys.getcwd`). Two capabilities are new: `clock` (what time it is, and
waiting) and `pipe` (`pipe`, `socketpair`). The process's own number,
its directory and the machine's name ask for `env`, which already
exists. In the 44 programs the sweep reads, 32 functions would need
one of them, 7 of which hold no capability at all today.** The work is
in four places: ocaml-caps (the types, which dune's builds check),
lib_core's erased `Cap` (which mini-ml compiles), `capabilities.dl`
(which says who needs what), and the 32 callers, then the programs the
sweep does not read.

**Status: steps 1 to 3 done (2026-11-04), step 4 next.** Part 1, a
capability held in a record's field, is done (98a593f4). The author's
answers to the open questions are in the last section.

## What is a system call here

lib_core's `Unix` is OCaml over one primitive, `syscall`
(`Unix.ml`'s `sys (n32, n64)`), and `Sys` is externals of mini-ml's
runtime (`sys_time`, `sys_getcwd`...). So "every system call" can be
listed, and is, below, for both. The rule that keeps the list honest is
step 3's: a `Unix` function that reaches `syscall` and is in none of
the four groups is a test's failure, so a function added to `Unix`
later must be put in one.

| group | functions |
|---|---|
| needs a capability already | `stdin stdout stderr openfile stat lstat LargeFile.stat LargeFile.lstat access readlink realpath unlink link rename chmod utimes mkdir mkfifo rmdir chdir opendir fork execv execve create_process wait waitpid kill _exit environment socket bind listen accept connect getaddrinfo setitimer`; `Sys`'s `file_exists is_directory remove rename getenv command chdir readdir mkdir`, `argv`, `exit`, `set_signal` |
| a descriptor already held | `close read write write_substring lseek ftruncate fstat fchmod isatty dup dup2 set_nonblock clear_nonblock set_close_on_exec in_channel_of_descr out_channel_of_descr readdir closedir getsockname setsockopt recvfrom sendto_substring shutdown select tcgetattr tcsetattr`, `LargeFile.lseek fstat` |
| computes only | `error_message gmtime inet_addr_any inet_addr_loopback inet_addr_of_string string_of_inet_addr` |
| new: `clock` | `time gettimeofday sleepf`, `Sys.time` |
| new: `pipe` | `pipe socketpair` |
| now `env` | `getpid getppid getcwd gethostname`, `Sys.getcwd` |

A descriptor is a capability (`Cap.mli`'s reframe), so `read`, `dup2`
and `tcsetattr` stay what they are: the authority was asked for when
the descriptor was opened. `Sys.executable_name` comes from `argv`,
already asked for.

`select` stays a descriptor's: its timeout bounds a wait on what is
held and tells no time. Each of its 25 uses in ix passes a descriptor
(TCP and UDP waits, the tty's stdin every 0.1 s, httpd, Maild,
TinyMachine). A `select` on none would be a sleep, to be written
`CapUnix.sleepf`, and there is none.

The pid, the directory and the hostname act on nothing. ix reads them
for a unique name (version_control's `tmp.<pid>`, rio's
`/srv/rio.<pid>`, the shell's `$pid`), to resolve a relative path
(version_control's `init` and `clone`, the builder), or for a default
(version_control's e-mail, `user@hostname`). Like an environment
variable, they are what the process is told about where it runs. Plan
9 keeps the machine's name in `/env/sysname`. So they ask for `env`,
not a capability of their own.

## The census: who would need them

`caps_syscalls/census.sh` adds the rows of the last three groups to a
copy of `capabilities.dl`, runs `-caps` over the 44 programs, and keeps
each function that needs one of them (`caps_syscalls/sites.txt`):

| capability | functions | directories |
|---|---|---|
| `clock` | 21 | 15 |
| `pipe` | 5 | 5 |
| `env`, not held before | 7 | 6 |
| total (a function may need two) | 32 | |

The 7 with no capability at all are where the work is: each needs a
parameter, and so do its callers up to one that has `caps`.
`Datalog_eval.apply` (`Sys.time`, for `-profile`), `St_boot`'s
(`Sys.time`), `Tty_unix`'s loop (`gettimeofday`), `Commands.now`,
`Process.pipe` (the shell's), `Window.name` (rio's, `getpid`). The 25
others hold some and need one more in their type. A function that
reads the pid and already holds `env` (the shell's and the builder's
`CLI.run`) needs nothing more.

The census is of what runs: `gettimeofday` is written 84 times in ix,
in files the 44 programs do not reach or that the sweep does not read.
Those are apps/ (pim, maps), utilities/process (sleep, spin),
raspberry/, lib_playground's platforms, and tiny/'s host side, about
40 files by `git grep`. They come in step 5.

## Steps

1. **ocaml-caps.** The two types in `Cap.mli`, where the others are.
   `clock` goes in `misc`, beside `random`: both are what makes two
   runs differ (its `Misc` said `TODO: time`). `pipe` goes in
   `process_multi`, since a pipe is for a child (its `Process` asked
   "pipe? not sure it requires a cap"). `CapUnix` gets `gettimeofday`,
   `time`, `sleepf`, `sleep` (clock), `pipe`, `socketpair` (pipe),
   `getpid`, `getppid`, `getcwd`, `gethostname` (env), and `CapSys`
   gets `time` and `getcwd`. Its Semgrep rules forbid the bare calls.
   Installed in the local opam switch (`dune install`, 0.1.1), no opam
   release yet. Only what links the opam `caps` sees it: xix keeps its
   own copy (`xix/caps/`), and osemgrep, codemap and efuns use
   semgrep's `TCB/Cap.ml`. Code that builds a whole `all_caps` object
   itself would need the two new methods; `Cap.main` builds it, and
   none other was found in ix or those repositories.
2. **lib_core/system.** The erased `CapUnix` and `CapSys` get the same
   functions, typed `< .. >`, so the code compiles under mini-ml. Only
   those both of lib_core's `Unix` have: plan9/Unix has no
   `socketpair`, `getppid` or `gethostname`, and its `Unix` has no
   socket type (mini-acid's Plan 9 build said so). Those three are
   added when a caller of step 4 needs them, where it is built.
3. **capabilities.dl.** The `requires` rows, and `cap_includes` for
   the groups. The "Not authority" comment shrinks to descriptors. The
   check of the list: `on_descriptor(F)` and `computes(F)` facts for
   the other two groups, and `unclassified(F)`, a `Unix` function that
   reaches `prim:unix_syscall` and is in no group. A test in
   `analyzers/tests/caps/` asks that none is.
   Done: the test is `analyzers/tests/run.sh`'s, on both of lib_core's
   `Unix` (Linux's 80 vals, plan9's 43), given its `.mli`'s vals as
   `unix_val`; it reports a row taken out (tried with `Unix.pipe`). It
   found what the table above missed: `Unix.LargeFile.stat` and `lstat`
   (machine/process's `Host`), now `open_in`'s, `LargeFile.lseek` and
   `fstat` a descriptor's, and plan9's `Unix.plan9_call`, Plan 9's call
   by number, under `Sys_plan9`, whose functions each take their
   capability by type, but `exits`, now `Cap.exit`'s (`raw_call`).
4. **The 32 callers.** Each takes the capability, or calls `CapUnix`'s
   function. Where a module needs only the time, a closure can be
   given instead of the object: `Datalog_eval` taking `now : unit ->
   float`, made by its CLI from `caps`, as xix's ed gives a weaker
   `open_in`. That closure is the capability, attenuated. That case
   is worth a sentence in `Cap.mli`'s header. `caps_ix.txt` is
   re-recorded. `dune build` is the check that each caller holds what
   it passes: OCaml checks it.
5. **Outside the sweep.** apps/, utilities/process, raspberry/,
   lib_playground: by `git grep`, then by OCaml once their calls are
   `CapUnix`'s. Or the sweep is taught their mkfiles; the units of
   some are computed (`sweep.sh`'s "computed units"). tiny/ is left
   out for now (the author's).

Checked at each step: `make test`, `analyzers/tests/run.sh`, the `-caps`
sweep against the one before (the only new reports are the census's,
and they go as the callers are done), and `dune build` of the whole
tree.

## The questions, answered (2026-11-04)

- **Names.** `clock` (`sleepf` with it) and `pipe`: "the names are
  good for clock and pipe". The proposed `self` was dropped ("for self
  I don't know what is it for"): its calls ask for `env` (above).
- **ocaml-caps.** "yes we should modify ocaml-caps and install it in
  our local opam after".
- **tiny/.** "let's leave tiny/ out for now".
- **`select`.** A descriptor's (above): the plan's proposal, not
  answered in so many words; to change if the author says so.

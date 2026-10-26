# Testing ix

Which test to run, and when (docs/plans/plan_tests.md says why it is
so).

| command | when | time |
|---|---|---|
| `make test` | before every commit (`tests/lite.sh`) | 2 min |
| `make test-tix`, `test-mix` | a change in one system | 1-2 min |
| `make self-quick` | a change to the toolchain, a kernel, an emulator | 5 min |
| `make test-all` | CI on each push; by hand before a large change | 30 min |
| `make self` | each night on GitHub (self.yml): both systems, all of themselves | hours |

`make test` is the gate: every program's fast checks at once.
`test-tix` and `test-mix` are its jobs of one system (and the shared
ones). `self-quick`: t-ix in tiny-kernel and m-ix in mini-9pi build a
part of themselves. `test-all`: every suite one after the other
(`tests/all.sh -l` lists them).

## make test

About 135 jobs on all the cores, a line each as it ends:

```
[t-ix]   ok     5.4 s  tiny-build: its Buildfiles
[m-ix]   ok    14.5 s  mini-git: clone, fetch, push against git's servers
...
== shared 3 ok                                   22 s
== t-ix   24 ok                                  77 s
== m-ix   108 ok                                117 s
test-lite: 135 jobs, 0 failure(s), 0 skipped, 117 s
```

- **The groups.** shared: what both systems stand on (ix's types by
  OCaml 5.5, the sources as text, lib_core by mini-ml); t-ix: the tiny
  programs, tiny-kernel booted, t-ix compiling in tiny-kernel; m-ix:
  the mini programs, ix built by ix and its programs used, m-ix
  compiling in mini-9pi. `grep '^\[t-ix\]'` keeps one.
- **A failure** prints its first lines and its log's end; the logs are
  kept (the last line says where).
- **A skip** is what this machine cannot do, with what it lacks: no
  opam switch 5.5.1, no qemu-system-arm, no ocaml-light for arm
  (`kernels/ocaml-light.sh arm`), no xv6 disk image, no arm64 to run
  mini-ml's programs. Not a failure; CI skips the ones it has not.
- **Past the budget**: the jobs over a minute, and the whole over two,
  are said at the end. Not a failure, but the next thing to make
  faster.
- **Several sessions at once** run it without waiting for each other:
  each run builds in a directory of its own, and tests/lite.sh is
  read whole before it runs. What it tests is the working tree: another
  session's work in progress can make it fail.

Nothing in it needs a reference outside the repository but those
skips. What does (goken, ocaml-light's ocamlopt, chidb, plan9port,
the playground, QEMU's C kernels) is test-all's.

## The guard

`git commit` says, before it commits, the files modified, deleted or
new in the directories the commit touches and not in it
(`tests/guard.sh`, git's pre-commit hook; `make hooks` once per clone).
`make test` tests the working tree, CI the commit: a commit that needs
one of those passes the first and breaks the second. It does not stop
the commit: another session's work in progress is listed too.

## make test-all

`tests/all.sh`: `make test` first, then `make test-long` (the long
forms: the random tests' full counts, the fuzzers, tiny-kernel's whole
check), mini-ml on today's OCaml, ix built by ix checked against
itself and for arm, the suites against references when they are on
this machine. A line for each, the logs in /tmp/ix-test-all, and a row
of times in docs/test_times.md. CI runs it on an arm64 machine
(.github/workflows/docker.yml), and `make test` with OCaml 4.14 and
5.5.

## make self, each night

`.github/workflows/self.yml`, at 2:00 UTC when main moved since the
last run that passed (or by hand: Actions, self, Run workflow):
`make self-tix` and `self-mix` side by side, each in the Dockerfile
with `--build-arg SELF=tix` or `mix` (mix adds QEMU, gcc for arm and
ocaml-light). A failure opens an issue "make self failed", or comments
on the one open; close it when fixed. The runs' times are in the
Actions tab.

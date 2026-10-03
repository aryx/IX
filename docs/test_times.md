# The tests' times

How long each suite of `make test-all` (`tests/all.sh`) takes, a row a
run: to see what a change costs, and what to shorten. The times are
this machine's (64 cores, arm64); a suite marked FAIL stopped early. A
commit with a `+` had changes not yet committed. `tests/all.sh -l`
says what each suite is.

| date | commit | the suites, minutes:seconds |
|---|---|---|
| 2026-10-03 | `81deb03` | build 0:01, test 4:00, ml 1:18, differential 1:08, goken 2:04, ocaml 2:28 (FAIL), chidb 0:13, ix 17:42, fixpoint 10:54, arm 4:57, fixpoint-arm 14:43, pi 44:45 (FAIL), kernels-ix 30:36 |

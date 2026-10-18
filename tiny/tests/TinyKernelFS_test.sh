#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyKernelFS.ml on the host, built by OCaml:
# TinyKernelFS_tests/Host.ml makes files and directories on a disk of
# bytes, writes one big enough for the double indirect block, mounts
# again after changes that were not committed (a crash), boots a few
# times for snapshots, and fills a small disk until the collector must
# give blocks back; against files.expected. The kernel's own, on
# tiny-machine, is TinyKernel's check (a file in /usr kept across two
# boots, /dump). RECORD=1 records.
# usage: TinyKernelFS_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/TinyKernelFS_tests/Host.exe}
E=$ROOT/tiny/tests/TinyKernelFS_tests/files.expected
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0

$HOST > $W/files.out 2>&1 || { echo "FAIL files: the run"; failures=$((failures + 1)); }
[ -n "${RECORD:-}" ] && cp $W/files.out $E
if diff $E $W/files.out > $W/files.diff; then echo "ok files"; else echo "FAIL files"; head -10 $W/files.diff; failures=$((failures + 1)); fi

echo "$failures failure(s)"
[ $failures = 0 ]

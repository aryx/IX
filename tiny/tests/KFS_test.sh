#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of KFS.ml on the host, built by OCaml:
# KFS_tests/Host.ml makes files and directories on a disk of
# bytes, writes one big enough for the double indirect block, mounts
# again after changes that were not committed (a crash), boots a few
# times for snapshots, fills a small disk until the collector must
# give blocks back, and mounts two disks at once, a file on each;
# against files.expected. The kernel's own, on
# tiny-machine, is TinyKernel's check (a file in /usr kept across two
# boots, /dump). Then tiny-mkfs, a disk made on the host. RECORD=1
# records.
# usage: KFS_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/KFS_tests/Host.exe}
E=$ROOT/tiny/tests/KFS_tests/files.expected
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0

$HOST > $W/files.out 2>&1 || { echo "FAIL files: the run"; failures=$((failures + 1)); }
[ -n "${RECORD:-}" ] && cp $W/files.out $E
if diff $E $W/files.out > $W/files.diff; then echo "ok files"; else echo "FAIL files"; head -10 $W/files.diff; failures=$((failures + 1)); fi

# tiny-mkfs (TinyKernel/host/TinyMkfs.ml): a disk of two files, one in
# directories made on the way, and an empty directory; listed back, a
# file read back by Cat, the same disk made again the same bytes, and the
# disk grown by truncate mounted whole (fs_mount), its files the same
MKFS=${MKFS:-$ROOT/_build/default/tiny/TinyKernel/host/TinyMkfs.exe}
CAT=${CAT:-$ROOT/_build/default/tiny/tests/KFS_tests/Cat.exe}
T=$ROOT/tiny
want=$(printf '/a/\n/a/b/\n/a/b/start.s %d\n/tmp/\n/hello.c %d\n' \
  $(wc -c < $T/runtime/c/start.s) $(wc -c < $T/examples/hello.c))
if $MKFS -m 1 $W/d.img a/b/start.s=$T/runtime/c/start.s tmp/ hello.c=$T/examples/hello.c \
   && [ "$($MKFS -l $W/d.img)" = "$want" ] \
   && $CAT $W/d.img a/b/start.s | cmp -s - $T/runtime/c/start.s \
   && $MKFS -m 1 $W/d2.img a/b/start.s=$T/runtime/c/start.s tmp/ hello.c=$T/examples/hello.c \
   && cmp -s $W/d.img $W/d2.img \
   && truncate -s 4M $W/d.img && [ "$($MKFS -l $W/d.img)" = "$want" ] \
   && $CAT $W/d.img hello.c | cmp -s - $T/examples/hello.c
then echo "ok tiny-mkfs: listed, read back, the same bytes again, grown"
else echo "FAIL tiny-mkfs"; failures=$((failures + 1)); fi

echo "$failures failure(s)"
[ $failures = 0 ]

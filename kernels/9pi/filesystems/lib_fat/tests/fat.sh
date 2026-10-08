#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Fat's writing, on the host (lib_fat is the kernel's and mini-dossrv's;
# here it runs as OCaml's, with no emulator): an image of each size
# (FAT12, 16, 32) made by mkfs.vfat, changed by Fattest, then read back
# by mtools and checked by fsck.vfat.
# usage: fat.sh   (from anywhere; dune build first)
set -u
ROOT=$(cd "$(dirname "$0")/../../../../.." && pwd)
F=$ROOT/_build/default/kernels/9pi/filesystems/lib_fat/tests/Fattest.exe; W=$(mktemp -d -p ${TMPDIR:-/tmp}); fail=0
ok() { echo "ok fat$bits: $1"; }
bad() { echo "FAIL fat$bits: $1"; fail=1; }
head -c 300000 /dev/urandom > $W/big; printf 'hello, fat\n' > $W/small; head -c 70000 /dev/urandom > $W/mid
for spec in "12 4" "16 32" "32 300"; do
  set -- $spec; bits=$1; mb=$2; img=$W/fat$bits.img
  dd if=/dev/zero of=$img bs=1M count=$mb status=none
  mkfs.vfat -F $bits $img > /dev/null || { bad "mkfs"; continue; }
  # a file there before, by mtools: read by us after
  mcopy -i $img $W/small ::BEFORE.TXT
  $F $img create /small.txt && $F $img write /small.txt 0 $W/small && [ "$(mtype -i $img ::small.txt)" = "hello, fat" ] && ok "a file made and written, read by mtype" || bad "small file"
  $F $img create /big.bin && $F $img write /big.bin 0 $W/big && mcopy -i $img ::big.bin $W/big.out && cmp -s $W/big $W/big.out && ok "300,000 bytes over many clusters" || bad "big file"; rm -f $W/big.out
  $F $img create "/A long name, with Spaces.text" && $F $img write "/A long name, with Spaces.text" 0 $W/small && [ "$(mtype -i $img "::A long name, with Spaces.text")" = "hello, fat" ] && ok "a long name" || bad "long name"
  $F $img create "/A long name, with Commas.text" && mdir -i $img :: | grep -q "A_LONG~2" && ok "a second alias" || bad "alias"
  $F $img mkdir /dir && $F $img create /dir/inner.txt && $F $img write /dir/inner.txt 0 $W/mid && mcopy -i $img ::dir/inner.txt $W/mid.out && cmp -s $W/mid $W/mid.out && ok "a directory, a file in it" || bad "directory"; rm -f $W/mid.out
  # many files: the directory grows by clusters (not FAT12's and 16's root: in a directory)
  n=0; for i in $(seq 1 90); do $F $img create "/dir/file number $i.txt" && n=$((n+1)); done; [ $n = 90 ] && [ "$($F $img ls /dir | wc -l)" = 91 ] && ok "90 long names more in a directory" || bad "many files ($n)"
  # written at an offset, past the end: zeros between
  $F $img create /gap.bin && $F $img write /gap.bin 5000 $W/small && mcopy -i $img ::gap.bin $W/gap.out && [ "$(stat -c %s $W/gap.out)" = 5011 ] && [ "$(head -c 5000 $W/gap.out | tr -d '\0' | wc -c)" = 0 ] && [ "$(tail -c 11 $W/gap.out)" = "hello, fat" ] && ok "written past the end" || bad "gap"; rm -f $W/gap.out
  # written over a part
  $F $img write /big.bin 100000 $W/small && mcopy -i $img ::big.bin $W/big.out && [ "$(stat -c %s $W/big.out)" = 300000 ] && [ "$(dd if=$W/big.out bs=1 skip=100000 count=10 status=none)" = "hello, fat" ] && cmp -s -n 100000 $W/big $W/big.out && ok "written over a part" || bad "overwrite"; rm -f $W/big.out
  $F $img trunc /big.bin && [ "$($F $img ls / | grep '^big.bin')" = "big.bin 0" ] && ok "emptied" || bad "truncate"
  # a name changed: to a long one, to a short one, in a directory; the bytes stay
  $F $img mv /small.txt "Renamed to a long name.txt" && [ "$(mtype -i $img "::Renamed to a long name.txt")" = "hello, fat" ] && ! mdir -i $img ::small.txt > /dev/null 2>&1 && $F $img mv "/Renamed to a long name.txt" small.txt && [ "$(mtype -i $img ::small.txt)" = "hello, fat" ] && $F $img mv /dir/inner.txt within.txt && mcopy -i $img ::dir/within.txt $W/mid.out && cmp -s $W/mid $W/mid.out && $F $img mv /dir moved && [ "$($F $img ls /moved | wc -l)" = 91 ] && $F $img mv /moved dir && ok "names changed (long, short, a directory's), read by mtools" || bad "rename"; rm -f $W/mid.out
  $F $img mv /small.txt BIG.BIN 2>/dev/null && bad "renamed over another file" || ok "a name that is taken refused"
  $F $img touch /small.txt 1000000000 && TZ=UTC mdir -i $img ::small.txt | grep -q "2001-09-09  *1:46" && ok "a time set, read by mdir" || bad "mtime: $(TZ=UTC mdir -i $img ::small.txt | grep -i small)"
  $F $img chmod /small.txt ro && mattrib -i $img ::small.txt | grep -q "^ *A* *R" && $F $img chmod /small.txt rw && ! mattrib -i $img ::small.txt | grep -q "^ *A* *R" && ok "made read only, and back, read by mattrib" || bad "read only: $(mattrib -i $img ::small.txt)"
  $F $img rm "/A long name, with Spaces.text" && ! mdir -i $img :: | grep -qi "ALONGN~1" && ok "removed, its long name too" || bad "remove"
  $F $img rm /dir 2>/dev/null && bad "a full directory removed" || ok "a directory that is not empty stays"
  [ "$($F $img cat /BEFORE.TXT)" = "hello, fat" ] && ok "mtools' file still read" || bad "old file"
  out=$(fsck.vfat -n $img 2>&1); echo "$out" | grep -qiE "error|bad|orphan|differ|contains a free|unused" && { bad "fsck.vfat: $(echo "$out" | grep -iE 'error|bad|orphan|differ|free|unused' | head -3)"; } || ok "fsck.vfat: $(echo "$out" | tail -1)"
done
rm -rf $W
exit $fail

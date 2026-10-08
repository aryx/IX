#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Xv6fs on the host (lib_xv6fs is the kernel's and mini-mkfs's; here it
# runs as OCaml's, with no emulator): xv6's own image read (the format
# is its mkfs's), then images made here, of each block size, changed
# and read back.
# usage: xv6fs.sh   (from anywhere; dune build first; XV6: xv6-multiarch's tree)
set -u
ROOT=$(cd "$(dirname "$0")/../../../../.." && pwd)
F=$ROOT/_build/default/kernels/9pi/filesystems/lib_xv6fs/tests/Xv6test.exe; W=$(mktemp -d -p ${TMPDIR:-/tmp}); fail=0
XV6=${XV6:-$HOME/xv6}
ok() { echo "ok xv6fs$tag: $1"; }
bad() { echo "FAIL xv6fs$tag: $1"; fail=1; }
tag=
# xv6's image: its files are there, one of them read whole (README is text)
for img in $XV6/forks/arm-pi1/user/fs.img $XV6/forks/arm64-pi4/fs.img; do
  [ -f $img ] || { echo "skip: $img not there"; continue; }
  cp $img $W/x.img
  n=$($F $W/x.img ls / | wc -l); $F $W/x.img ls / | grep -q "^sh " && $F $W/x.img ls / | grep -q "^README " && ok "$(basename $(dirname $img)): xv6's own image, $n names, sh and README among them" || bad "xv6's image $img"
  $F $W/x.img cat /README | head -1 | grep -qi "xv6" && ok "its README read" || bad "README"
done
head -c 300000 /dev/urandom > $W/big; printf 'hello, xv6\n' > $W/small; head -c 2500000 /dev/urandom > $W/huge
for bsize in 512 1024; do
  tag=" $bsize"; img=$W/fs$bsize.img; rm -f $img
  $F $img format $((8 * 1024 * 1024 / bsize)) $bsize && [ "$($F $img ls /)" = "" ] && ok "a new one, empty" || { bad "format"; continue; }
  $F $img create /small && $F $img write /small 0 $W/small && [ "$($F $img cat /small)" = "hello, xv6" ] && ok "a file made and written" || bad "small file"
  $F $img create /big && $F $img write /big 0 $W/big && $F $img cat /big | cmp -s - $W/big && ok "300,000 bytes (past the inode's blocks)" || bad "big file"
  $F $img create /huge && $F $img write /huge 0 $W/huge && $F $img cat /huge | cmp -s - $W/huge && ok "2,500,000 bytes (the second block of numbers: ix's)" || bad "huge file"
  $F $img mkdir /dir && $F $img create /dir/inner && $F $img write /dir/inner 0 $W/small && [ "$($F $img cat /dir/inner)" = "hello, xv6" ] && [ "$($F $img ls /dir)" = "inner 11" ] && ok "a directory, a file in it" || bad "directory"
  n=0; for i in $(seq 1 60); do $F $img create /dir/f$i && n=$((n+1)); done; [ $n = 60 ] && [ "$($F $img ls /dir | wc -l)" = 61 ] && ok "60 files more in a directory" || bad "many files ($n)"
  $F $img create /gap && $F $img write /gap 5000 $W/small && $F $img cat /gap > $W/gap.out && [ "$(stat -c %s $W/gap.out)" = 5011 ] && [ "$(head -c 5000 $W/gap.out | tr -d '\0' | wc -c)" = 0 ] && [ "$(tail -c 11 $W/gap.out)" = "hello, xv6" ] && ok "written past the end" || bad "gap"
  $F $img write /big 100000 $W/small && $F $img cat /big > $W/big.out && [ "$(stat -c %s $W/big.out)" = 300000 ] && [ "$(dd if=$W/big.out bs=1 skip=100000 count=10 status=none)" = "hello, xv6" ] && cmp -s -n 100000 $W/big $W/big.out && ok "written over a part" || bad "overwrite"
  $F $img mv /small renamed && $F $img mv /dir/inner within && [ "$($F $img cat /renamed)" = "hello, xv6" ] && [ "$($F $img cat /dir/within)" = "hello, xv6" ] && ! $F $img cat /small 2>/dev/null && $F $img mv /renamed small && $F $img mv /dir/within inner && ok "a name changed, and back" || bad "rename"
  $F $img mv /small big 2>/dev/null && bad "renamed over another file" || ok "a name that is taken refused"
  [ "$($F $img mtime /small)" = 0 ] && $F $img touch /small 1790380800 && [ "$($F $img mtime /small)" = 1790380800 ] && [ "$($F $img cat /small)" = "hello, xv6" ] && ok "a time written (ix's), none before" || bad "mtime"
  $F $img create /a-name-too-long 2>/dev/null && bad "a name of 15 characters taken" || ok "a name of 15 characters refused"
  $F $img rm /dir 2>/dev/null && bad "a full directory removed" || ok "a directory that is not empty stays"
  # what is given back is taken again: the huge file removed, then written again, three times, on 8 MB
  r=0; for k in 1 2 3; do $F $img rm /huge && $F $img create /huge && $F $img write /huge 0 $W/huge && r=$((r+1)); done; [ $r = 3 ] && $F $img cat /huge | cmp -s - $W/huge && ok "removed and written again, three times (its blocks given back)" || bad "blocks not given back ($r)"
  $F $img trunc /big && [ "$($F $img ls / | grep '^big ')" = "big 0" ] && ok "emptied" || bad "truncate"
  [ "$($F $img cat /small)" = "hello, xv6" ] && [ "$($F $img cat /dir/inner)" = "hello, xv6" ] && ok "the first files still read" || bad "old files"
done
rm -rf $W
exit $fail

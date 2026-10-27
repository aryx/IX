#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# m-ix building in itself, a small part, for make test (plan_tests.md;
# make self-quick takes 4 minutes, make self 3 hours). In a directory of
# its own:
#  - ix for arm and Plan 9 by mini-mk: the libraries, rc, the toolchain,
#    what boot.rc runs, self-quick's two programs (tests/self/);
#  - a mini-9pi for the Pi 2 with those in its bootdir;
#  - a small card: the toolchain (ml, cc, asm, ld) and cmp, lib_core's
#    sources and tests/self/'s in /src, the host's objects in /host.
# Then under QEMU, on the card: Pervasives.ml by ml and libc's pow.c by
# cc, as lib_core's mkfile compiles them; hello.c and Hello.ml as
# tests/self/mkfile, compiled, linked over the host's libc.a and runtime,
# and run. Each object and program the host's, byte for byte (cmp), and
# Pervasives' summary (X.inline, what ml -O3 inlines from).
# QEMU's Pi 2: mini-qemu's is 6 times slower here, a minute and a half,
# and its own checks are the kernels' (make check-ix).
# usage: kernels/9pi/tests/smoke.sh dir

set -e
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
D=$(mkdir -p "$1" && cd "$1" && pwd)
cd $ROOT
export PATH=$ROOT/bin:$PATH MKSHELL=mini-rc
X=$D/mk/5-plan9
log() { echo $D/mk.$(echo $1 | tr / _).log; }
mk() { (cd $1 && NPROC=32 mini-mk O=5 OS=plan9 B=$X "${@:2}") > $(log $1) 2>&1 ||
  { echo "mini-mk failed in $1:"; tail -3 $(log $1); return 1; }; }
mk . libs
mk assembler
pids=()
for d in shell linker languages/ml languages/c utilities/files utilities/misc \
    utilities/compare utilities/namespace kernels/9pi/devices/storage/user/fdisk \
    kernels/9pi/tests/self; do
  mk $d & pids+=($!)
done
for p in "${pids[@]}"; do wait $p; done

# mini-9pi for the Pi 2, its bootdir what boot.rc runs to mount the
# card (the date: the Makefile's KERNDATE_IX)
U=$X/utilities
boot="boot=conf/boot.rc rc=$X/shell/mini-rc echo=$U/misc/mini-echo"
boot="$boot ls=$U/files/mini-ls cat=$U/files/mini-cat"
boot="$boot bind=$U/namespace/mini-bind mount=$U/namespace/mini-mount"
boot="$boot fdisk=$X/kernels/9pi/devices/storage/user/fdisk/mini-fdisk"
make -s -C kernels/9pi BOARD=pi2 B=$D/k IMAGE=$D/kernel.img \
  KERNDATE=1790380800 BOOTDIR="$boot" $D/kernel.img > $D/kernel.log 2>&1 ||
  { echo "the kernel:"; tail -3 $D/kernel.log; exit 1; }

# the card: the toolchain and cmp in /bin (lib/namespace, as make
# card's; rc/bin/, which boot.rc binds too), lib_core's sources and
# self-quick's two programs in /src, the host's objects in /host
S=$X/kernels/9pi/tests/self
L=$X/lib_core
printf 'bind -a /root/progs/toolchain /bin\nbind -a /root/progs/misc /bin\n' > $D/namespace
files=(progs/toolchain/ml=$X/languages/ml/mini-ml progs/toolchain/cc=$X/languages/c/mini-cc
  progs/toolchain/asm=$X/assembler/mini-asm progs/toolchain/ld=$X/linker/mini-ld
  progs/misc/cmp=$U/compare/mini-cmp lib/namespace=$D/namespace
  src/self/hello.c=kernels/9pi/tests/self/hello.c
  src/self/Hello.ml=kernels/9pi/tests/self/Hello.ml
  host/Pervasives.5=$L/Pervasives.5 host/Pervasives.inline=$L/Pervasives.inline
  host/pow.5=$L/libc/port/pow.5
  host/libc.a=$L/libc.a host/runtime.5=$L/runtime.5 host/std_exit.5=$L/std_exit.5
  host/start.5=$S/hello-ml.start.5 host/Hello.5=$S/Hello.5
  host/hello-c=$S/hello-c host/hello-ml=$S/hello-ml
  rc/bin/ tmp/lib/ tmp/self/ mnt/ usr/pad/)
while read -r f; do files+=(src/$f=$f); done < <(find lib_core -type f -not -path '*/tests/*')
_build/default/kernels/tools/Mkfs.exe -m 32 -i 1024 $D/fs.img "${files[@]}" > /dev/null
_build/default/kernels/tools/Mkcard.exe -m 64 -fat 16 -date 1790380800 -fs $D/fs.img \
  $D/card.img mini9pi2.img=$D/kernel.img > /dev/null

# on the card, as mk's commands: the objects in /tmp/lib and /tmp/self,
# as mk's directories (ml reads a unit's summary, X.inline, beside the
# object it writes, and inlines from it with -O3: Hello.ml's object is
# another when Pervasives.inline is beside it)
cat > $D/session.cmds <<'END'
l=/tmp/lib; s=/tmp/self; h=/host; L=/src/lib_core
I=(); for(d in system/plan9 core base collections printing parsing system concurrency commons) I=($I -I $L/$d)
C=(-I$L/libc/include -I$L/libc/include/utf -I$L/libc -I$L/libc/include/arch/arm -Darm -Dplan9)
cd $L
ml -m 5 -O3 $I -o $l/Pervasives.5 core/Pervasives.ml
cmp $l/Pervasives.5 $h/Pervasives.5 && echo Pervasives: the host
cmp $l/Pervasives.inline $h/Pervasives.inline && echo Pervasives.inline: the host
cc -m 5 $C -o $l/pow.5 libc/port/pow.c
cmp $l/pow.5 $h/pow.5 && echo pow: the host
cd /src/self
cc -m 5 $C -o $s/hello.5 hello.c
ld -m 5 -H2 -nofollow -o $s/hello-c $s/hello.5 $h/libc.a
$s/hello-c
cmp $s/hello-c $h/hello-c && echo hello-c: the host
ml -m 5 -O3 -start Pervasives Hello Std_exit -o $s/start.5
cmp $s/start.5 $h/start.5 && echo start: the host
ml -m 5 -O3 $I -o $s/Hello.5 Hello.ml
cmp $s/Hello.5 $h/Hello.5 && echo Hello: the host
ld -m 5 -H2 -nofollow -o $s/hello-ml $s/start.5 $l/Pervasives.5 $s/Hello.5 $h/std_exit.5 $h/runtime.5 $h/libc.a
$s/hello-ml
cmp $s/hello-ml $h/hello-ml && echo hello-ml: the host
END
B="-M raspi2b -device loader,file=$D/kernel.img,addr=0x8000,cpu-num=0,force-raw=on"
for c in 1 2 3; do B="$B -device loader,addr=0x8000,cpu-num=$c"; done
kernels/lib_machine/session.py --prompt "% " --timeout 120 --out $D/session.txt \
  --lines $D/session.cmds -- qemu-system-arm $B -nographic \
  -drive file=$D/card.img,if=sd,format=raw,snapshot=on > /dev/null ||
  { echo "the session did not end:"; tail -5 $D/session.txt; exit 1; }
for l in 'Pervasives: the host' 'Pervasives.inline: the host' 'pow: the host' \
    'hello from C' 'hello-c: the host' \
    'start: the host' 'Hello: the host' 'hello from OCaml' 'hello-ml: the host'; do
  grep -q "^$l" $D/session.txt || { echo "no \"$l\":"; tail -20 $D/session.txt; exit 1; }
done
echo "ok m-ix built in mini-9pi: Pervasives.ml, pow.c, hello.c and Hello.ml, the host's"

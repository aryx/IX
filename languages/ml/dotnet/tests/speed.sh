#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Stage 4 of plan_dotnet_languages.md: mini-ml's benchmarks
# (languages/ml/tests/bench/) native (arm64, -O3, run.sh's build, run
# here), on .NET by Microsoft's dotnet, and by mini-dotnet's JIT
# (mini-ml's build, arm64); each output checked against the .out (a *
# when it differs), its time in seconds, the best of three. Hello, an
# empty program, says each one's start. MINIDOTNET: a mini-dotnet with
# a JIT, if not _mk/7's; DUNEML: a mini-ml, if not dune's.
# usage: languages/ml/dotnet/tests/speed.sh workdir [prog...]
set -u
ROOT=$(cd "$(dirname "$0")/../../../.." && pwd)
W=$(realpath -m $1); shift
B=$ROOT/languages/ml/tests/bench
progs=${*:-pixels limbs samples floats sha fib tak maps sched interp matrix}
ML=${DUNEML:-$ROOT/_build/default/languages/ml/Main.exe}
MINIDOTNET=${MINIDOTNET:-$ROOT/_mk/7/languages/dotnet/mini-dotnet}
mkdir -p $W/native $W/dotnet
echo 'let () = ()' > $W/hello.ml
printf 'exit 0\n' > $W/hello.out
ML_FLAGS=-O3 $ROOT/languages/ml/tests/run.sh 7 $W/native $W/hello.ml $(for p in $progs; do echo $B/$p.ml; done) | grep -v '^ok'

# the best of three runs' seconds, its output checked (* if not .out's)
best() {
  local expected=$1 dir=$2; shift 2
  local b= t0 t s
  for _ in 1 2 3; do
    t0=$(date +%s%N)
    (cd $dir && timeout 600 "$@") > $W/out.txt 2>/dev/null
    s=$?
    t=$(( ($(date +%s%N) - t0) / 1000000 ))
    echo "exit $s" >> $W/out.txt
    [ $s = 124 ] && { echo "timeout"; return; }
    [ -z "$b" ] || [ $t -lt $b ] && b=$t
  done
  cmp -s $W/out.txt $expected && m=" " || m="*"
  awk -v t=$b -v m="$m" 'BEGIN { printf "%.3f%s", t / 1000, m }'
}

printf "%-8s %10s %10s %12s\n" program native dotnet mini-dotnet
for p in hello $progs; do
  src=$B/$p.ml; out=$B/$p.out
  [ $p = hello ] && { src=$W/hello.ml; out=$W/hello.out; }
  if ! $ML -L $ROOT/lib_core -dotnet -o $W/dotnet/$p.dll $src 2> $W/$p.err; then
    printf "%-8s  mini-ml -dotnet: %s\n" $p "$(head -1 $W/$p.err)"; continue
  fi
  printf "%-8s %10s %10s %12s\n" $p "$(best $out $W/native ./$p)" "$(best $out $W/dotnet dotnet $p.dll)" \
    "$(best $out $W/dotnet $MINIDOTNET -jit $p.dll)"
done

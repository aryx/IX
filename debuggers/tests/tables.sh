#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-nm and mini-where on a program's tables (plan_debugger.md's
# stage 2): linker/tests/golden's hello for Plan 9, assembled by
# mini-asm and linked by mini-ld -g, its names and lines as recorded
# here; with live, mini-nm against principia's nm under mini-5i too
# (not -n: equal values in nm.c's qsort's order, which mini-nm does not
# copy).
# usage: debuggers/tests/tables.sh [live]

ROOT=$(cd $(dirname $0)/../.. && pwd)
IX=$ROOT/_build/default
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
cp $ROOT/linker/tests/golden/hello_plan9_arm.s $W/
cd $W
$IX/assembler/Main.exe -m 5 -o hello.5 hello_plan9_arm.s && $IX/linker/Main.exe -m 5 -g -H2 -o hello hello.5 || { echo "FAIL the link"; exit 1; }
n=0; failures=0
same() {   # what, expected, got
  n=$((n + 1))
  if [ "$2" != "$3" ]; then failures=$((failures + 1)); echo "FAIL $1"; diff <(echo "$2") <(echo "$3") | head -6; fi
}
same "mini-nm: the names, by name" "$(cat <<'END'
    1020 T _main
    2000 D bdata
    2010 D edata
    2010 B end
    1078 T etext
    1058 L exit
    2000 D hello
    2ffc D setR12
END
)" "$($IX/linker/tools/Nm.exe hello)"
# (-a: as nm.c sorts them, by name: a z's name its numbers, the end's
# path empty, a space after its letter)
same "mini-nm -a: the history's paths, the frames, the files" "$(printf '%s\n' \
  '      26 z ' \
  '       1 z hello_plan9_arm.s' \
  '      18 m .frame' \
  '       8 m .frame' \
  '    1020 T _main' \
  '    2000 D bdata' \
  '    2010 D edata' \
  '    2010 B end' \
  '    1078 T etext' \
  '    1058 L exit' \
  '    2000 D hello' \
  '       1 f hello_plan9_arm.s' \
  '    2ffc D setR12')" "$($IX/linker/tools/Nm.exe -a hello)"
same "mini-where: functions, offsets, lines" "$(cat <<'END'
1020 _main hello_plan9_arm.s:5
1030 _main+0x10 hello_plan9_arm.s:12
105c exit+0x4 hello_plan9_arm.s:28
2000 ?
END
)" "$($IX/debuggers/where/Where.exe hello 1020 0x1030 lr=0x105c 2000)"
if [ "$1" = live ]; then
  P=$HOME/principia/ROOT/arch/arm/bin
  if [ -x $P/nm ]; then
    for f in "" -a -g -u -s; do
      same "mini-nm $f as principia's" "$($ROOT/bin/mini-5i $P/nm $f hello 2>&1)" "$($IX/linker/tools/Nm.exe $f hello 2>&1)"
    done
  else echo "skipped: no principia's nm in $P"; fi
fi
echo "tables: $n cases, $failures failure(s)"
[ $failures = 0 ]

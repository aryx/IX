#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The JIT's test programs (tests/run.sh's jit): each .cs compiled by
# Microsoft's C# compiler to its .dll, kept in the tree as the survey's
# (plan_dotnet.md, decision 2), and what Microsoft's runtime prints for
# it, its .expected (its standard output). The rest here is not made by
# it: fib.s, ints.s, fib7.s, ints7.s are mini-dotnet's own text
# (tests/run.sh -record), fib.c and ints.c the C programs that call it.
# Needs a .NET SDK; run again when a .cs changes.
set -e
cd $(dirname $0)
SDK=$(dotnet --list-sdks | tail -1 | sed 's/ \[\(.*\)\]/ \1/' | awk '{print $2 "/" $1}')
RT=$(dotnet --list-runtimes | grep '^Microsoft.NETCore.App ' | tail -1 |
     sed 's/ \[\(.*\)\]/ \1/' | awk '{print $3 "/" $2}')
OUT=$(mktemp -d)
trap 'rm -rf $OUT' EXIT
for f in ${*:-*.cs}; do
    p=${f%.cs}
    dotnet $SDK/Roslyn/bincore/csc.dll -nologo -nostdlib -optimize+ -debug- \
        -deterministic -r:$RT/System.Private.CoreLib.dll -r:$RT/System.Console.dll \
        -r:$RT/System.Runtime.dll -r:$RT/System.Collections.dll -r:$RT/System.Linq.dll -out:$OUT/$p.dll $f
    echo '{"runtimeOptions":{"tfm":"net8.0","framework":{"name":"Microsoft.NETCore.App","version":"'$(basename $RT)'"}}}' > $OUT/$p.runtimeconfig.json
    dotnet $OUT/$p.dll > $OUT/$p.expected
    cp $OUT/$p.dll $OUT/$p.expected .
done

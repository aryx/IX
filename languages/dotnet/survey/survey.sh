#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers of docs/plans/plan_dotnet.md: programs/*.cs compiled by
# Microsoft's C# compiler, what each prints by Microsoft's runtime
# (programs/*.expected), and what their assemblies hold (Survey.cs):
# the metadata's tables, the opcodes, the library's members asked.
#
#   survey.sh            the survey, to the standard output (survey.txt)
#   survey.sh name...    of these programs only (hello fib queens shapes:
#                        TinyDotnet's)
#   survey.sh -expected  write programs/*.expected again
#
# Needs a .NET SDK (dotnet in the path); nothing is downloaded. The
# assemblies go to a temporary directory, not the tree.

set -e
cd $(dirname $0)
SDK=$(dotnet --list-sdks | tail -1 | sed 's/ \[\(.*\)\]/ \1/' | awk '{print $2 "/" $1}')
RT=$(dotnet --list-runtimes | grep '^Microsoft.NETCore.App ' | tail -1 |
     sed 's/ \[\(.*\)\]/ \1/' | awk '{print $3 "/" $2}')
VER=$(basename $RT)
OUT=$(mktemp -d)
trap 'rm -rf $OUT' EXIT

refs=""
for a in System.Runtime System.Console System.Collections System.Linq \
         System.Reflection.Metadata System.Reflection.Primitives \
         System.Collections.Immutable System.Private.CoreLib; do
    refs="$refs -r:$RT/$a.dll"
done

# compile: the options a project's Release build gives, but no file of
# debugging symbols and no nullable annotations (attributes more)
csc() {
    dotnet $SDK/Roslyn/bincore/csc.dll -nologo -nostdlib -optimize+ \
        -debug- -deterministic $refs "$@"
}
config() {
    echo '{"runtimeOptions":{"tfm":"net8.0","framework":{"name":"Microsoft.NETCore.App","version":"'$VER'"}}}' \
        > $OUT/$1.runtimeconfig.json
}

expected=
[ "$1" = -expected ] && { expected=1; shift; }
progs=${*:-$(ls programs/*.cs | xargs -n1 basename | sed 's/\.cs$//')}

for p in $progs; do
    f=programs/$p.cs
    csc -out:$OUT/$p.dll $f
    config $p
    if [ -n "$expected" ]; then
        dotnet $OUT/$p.dll > programs/$p.expected
    else
        dotnet $OUT/$p.dll | cmp -s - programs/$p.expected ||
            echo "$p: not what programs/$p.expected says"
    fi
done
[ -n "$expected" ] && exit 0

csc -out:$OUT/Survey.dll Survey.cs
config Survey
echo "dotnet $(dotnet --version), runtime $VER"
echo
dotnet $OUT/Survey.dll $(ls $OUT/*.dll | grep -v Survey.dll)
echo
echo "the same programs, the lines of C# (comments and blank lines apart):"
for p in $progs; do
    f=programs/$p.cs
    echo "  $(basename $f) $(grep -v '^ *//' $f | grep -c -v '^ *$')"
done
echo
echo "Microsoft's own, for the scale:"
for a in System.Private.CoreLib System.Console System.Collections System.Linq System.Runtime; do
    echo "  $(dotnet $OUT/Survey.dll -size $RT/$a.dll)"
done

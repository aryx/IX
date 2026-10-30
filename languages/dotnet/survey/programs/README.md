# The survey's ten programs

Ten small C# programs, the survey's (docs/plans/done/plan_dotnet.md), and
what Microsoft's tools make of them, kept in the tree so that
mini-dotnet's tests need no .NET SDK (the plan's decision 2):

| file | what it is | made by |
|---|---|---|
| `*.cs` | the programs, written for the survey (338 lines) | by hand |
| `*.dll` | their assemblies: Microsoft's C# compiler's | `../survey.sh -dll` |
| `*.expected` | what each prints, run by Microsoft's runtime | `../survey.sh -expected` |

The programs, each a part of .NET (each file's first line says it):
`hello` (one call into the library), `fib` (static methods of int32s:
a recursion, a loop), `queens` (Wirth's eight queens: arrays, a
recursion), `shapes` (classes: fields, constructors, a virtual method,
an interface), `exceptions` (thrown, caught by type, a finally, one of
the machine's), `strings` (String's methods, StringBuilder,
interpolation), `vec` (a struct: copied, passed by reference, boxed),
`generic` (a generic class and a generic method), `collections` (List,
Dictionary, foreach), `closures` (a method as a value, a lambda and
what it captures).

## How the assemblies are made

`survey.sh` (in `..`) compiles each `.cs` with the C# compiler of the
SDK installed (Roslyn's `csc.dll`, run by `dotnet`), with the options a
project's Release build gives but `-debug-` (no .pdb file) and
`-deterministic` (the same bytes each time, so the files here can be
made again and compared), against the runtime's reference assemblies:

    dotnet $SDK/Roslyn/bincore/csc.dll -nologo -nostdlib -optimize+ \
      -debug- -deterministic -r:$RT/System.Runtime.dll ... -out:hello.dll hello.cs

These were made with the SDK 8.0.133 (runtime 8.0.33): `survey.sh -dll`
and `survey.sh -expected` there write the same bytes as the files here.
Another SDK may write other bytes (decision 2's caveat); what the
programs print should not change.

## Running one

By mini-dotnet (`dune build`, then from the repository's top, or
`mini-dotnet` where it is installed, or `dotnet` on mini-9pi's card,
where these are `/lib/dotnet/*.dll`):

    _build/default/languages/dotnet/Main.exe languages/dotnet/survey/programs/hello.dll
    _build/default/languages/dotnet/Main.exe -S languages/dotnet/survey/programs/hello.dll   # its IL

By Microsoft's runtime: `dotnet hello.dll` alone fails ("libhostpolicy.so
... not found"): it wants a `hello.runtimeconfig.json` beside the
assembly naming the runtime, which a project's build writes and the
compiler alone does not. survey.sh writes it in a temporary directory:

    cp hello.dll /tmp/
    echo '{"runtimeOptions":{"tfm":"net8.0","framework":{"name":"Microsoft.NETCore.App","version":"8.0.33"}}}' > /tmp/hello.runtimeconfig.json
    dotnet /tmp/hello.dll

(the version: `dotnet --list-runtimes`'s Microsoft.NETCore.App).

## Elsewhere

mini-dotnet's own test programs are in `../../tests/programs/` (made
by its `build.sh`) and the JIT's in `../../tests/jit/` (its
`build.sh`); mini-tiger's and mini-csc's assemblies are made by their
tests, not kept.

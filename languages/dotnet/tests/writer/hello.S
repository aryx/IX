.assembly hello
.assembly extern System.Runtime
.assembly extern System.Console

.class <Module>
{
}

.class Hello extends [System.Runtime]System.Object
{
  .field static int32 count
  .method static void Main()   // RVA 0x2048, 88 bytes
  {
    .entrypoint
    .maxstack 2
    .locals (int32)
    IL_0000: ldc.i4.0
    IL_0001: stloc.0
    IL_0002: br IL_0017
    IL_0007: ldsfld int32 Hello::count
    IL_000c: ldloc.0
    IL_000d: add
    IL_000e: stsfld int32 Hello::count
    IL_0013: ldloc.0
    IL_0014: ldc.i4.1
    IL_0015: add
    IL_0016: stloc.0
    IL_0017: ldloc.0
    IL_0018: ldc.i4.3
    IL_0019: blt IL_0007
    IL_001e: ldstr "hello, world"
    IL_0023: call void [System.Console]System.Console::WriteLine(string)
    IL_0028: ldsfld int32 Hello::count
    IL_002d: call void [System.Console]System.Console::WriteLine(int32)
    IL_0032: ldstr "boom"
    IL_0037: newobj instance void [System.Runtime]System.Exception::.ctor(string)
    IL_003c: throw
    IL_003d: callvirt instance string [System.Runtime]System.Exception::get_Message()
    IL_0042: call void [System.Console]System.Console::WriteLine(string)
    IL_0047: leave IL_0057
    IL_004c: ldstr "finally"
    IL_0051: call void [System.Console]System.Console::WriteLine(string)
    IL_0056: endfinally
    IL_0057: ret
    .try IL_0032 to IL_003d catch [System.Runtime]System.Exception handler IL_003d to IL_004c
    .try IL_0032 to IL_004c finally handler IL_004c to IL_0057
  }
}

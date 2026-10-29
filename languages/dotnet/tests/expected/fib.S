.assembly fib
.assembly extern System.Private.CoreLib
.assembly extern System.Console

.class <Module>
{
}

.class Fib extends [System.Private.CoreLib]System.Object
{
  .method static int32 Rec(int32)   // RVA 0x2050, 24 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldc.i4.2
    IL_0002: bge.s IL_0006
    IL_0004: ldarg.0
    IL_0005: ret
    IL_0006: ldarg.0
    IL_0007: ldc.i4.1
    IL_0008: sub
    IL_0009: call int32 Fib::Rec(int32)
    IL_000e: ldarg.0
    IL_000f: ldc.i4.2
    IL_0010: sub
    IL_0011: call int32 Fib::Rec(int32)
    IL_0016: add
    IL_0017: ret
  }
  .method static int32 Loop(int32)   // RVA 0x206c, 24 bytes
  {
    .maxstack 2
    .locals (int32, int32, int32)
    IL_0000: ldc.i4.0
    IL_0001: stloc.0
    IL_0002: ldc.i4.1
    IL_0003: stloc.1
    IL_0004: ldc.i4.0
    IL_0005: stloc.2
    IL_0006: br.s IL_0012
    IL_0008: ldloc.0
    IL_0009: ldloc.1
    IL_000a: add
    IL_000b: ldloc.1
    IL_000c: stloc.0
    IL_000d: stloc.1
    IL_000e: ldloc.2
    IL_000f: ldc.i4.1
    IL_0010: add
    IL_0011: stloc.2
    IL_0012: ldloc.2
    IL_0013: ldarg.0
    IL_0014: blt.s IL_0008
    IL_0016: ldloc.0
    IL_0017: ret
  }
  .method static void Main()   // RVA 0x2090, 37 bytes
  {
    .entrypoint
    .maxstack 8
    IL_0000: ldc.i4.s 20
    IL_0002: call int32 Fib::Rec(int32)
    IL_0007: call void [System.Console]System.Console::WriteLine(int32)
    IL_000c: ldc.i4.s 40
    IL_000e: call int32 Fib::Loop(int32)
    IL_0013: call void [System.Console]System.Console::WriteLine(int32)
    IL_0018: ldc.i4.s 47
    IL_001a: call int32 Fib::Loop(int32)
    IL_001f: call void [System.Console]System.Console::WriteLine(int32)
    IL_0024: ret
  }
  .method instance void .ctor()   // RVA 0x20b6, 7 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ret
  }
}

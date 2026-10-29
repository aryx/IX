.assembly queens
.assembly extern System.Private.CoreLib
.assembly extern System.Console

.class <Module>
{
}

.class Queens extends [System.Private.CoreLib]System.Object
{
  .field static bool[] row
  .field static bool[] up
  .field static bool[] down
  .field static int32[] at
  .field static int32 solutions
  .method static void Place(int32)   // RVA 0x2050, 202 bytes
  {
    .maxstack 8
    .locals (int32, bool, int32)
    IL_0000: ldc.i4.0
    IL_0001: stloc.0
    IL_0002: br IL_00c2
    IL_0007: ldsfld bool[] Queens::row
    IL_000c: ldloc.0
    IL_000d: ldelem.u1
    IL_000e: brtrue IL_00be
    IL_0013: ldsfld bool[] Queens::up
    IL_0018: ldloc.0
    IL_0019: ldarg.0
    IL_001a: add
    IL_001b: ldelem.u1
    IL_001c: brtrue IL_00be
    IL_0021: ldsfld bool[] Queens::down
    IL_0026: ldloc.0
    IL_0027: ldarg.0
    IL_0028: sub
    IL_0029: ldc.i4.7
    IL_002a: add
    IL_002b: ldelem.u1
    IL_002c: brtrue IL_00be
    IL_0031: ldsfld int32[] Queens::at
    IL_0036: ldarg.0
    IL_0037: ldloc.0
    IL_0038: stelem.i4
    IL_0039: ldsfld bool[] Queens::row
    IL_003e: ldloc.0
    IL_003f: ldsfld bool[] Queens::up
    IL_0044: ldloc.0
    IL_0045: ldarg.0
    IL_0046: add
    IL_0047: ldsfld bool[] Queens::down
    IL_004c: ldloc.0
    IL_004d: ldarg.0
    IL_004e: sub
    IL_004f: ldc.i4.7
    IL_0050: add
    IL_0051: ldc.i4.1
    IL_0052: dup
    IL_0053: stloc.1
    IL_0054: stelem.i1
    IL_0055: ldloc.1
    IL_0056: dup
    IL_0057: stloc.1
    IL_0058: stelem.i1
    IL_0059: ldloc.1
    IL_005a: stelem.i1
    IL_005b: ldarg.0
    IL_005c: ldc.i4.7
    IL_005d: bne.un.s IL_0094
    IL_005f: ldsfld int32 Queens::solutions
    IL_0064: ldc.i4.1
    IL_0065: add
    IL_0066: stsfld int32 Queens::solutions
    IL_006b: ldsfld int32 Queens::solutions
    IL_0070: ldc.i4.1
    IL_0071: bne.un.s IL_009c
    IL_0073: ldc.i4.0
    IL_0074: stloc.2
    IL_0075: br.s IL_0089
    IL_0077: ldsfld int32[] Queens::at
    IL_007c: ldloc.2
    IL_007d: ldelem.i4
    IL_007e: ldc.i4.1
    IL_007f: add
    IL_0080: call void [System.Console]System.Console::Write(int32)
    IL_0085: ldloc.2
    IL_0086: ldc.i4.1
    IL_0087: add
    IL_0088: stloc.2
    IL_0089: ldloc.2
    IL_008a: ldc.i4.8
    IL_008b: blt.s IL_0077
    IL_008d: call void [System.Console]System.Console::WriteLine()
    IL_0092: br.s IL_009c
    IL_0094: ldarg.0
    IL_0095: ldc.i4.1
    IL_0096: add
    IL_0097: call void Queens::Place(int32)
    IL_009c: ldsfld bool[] Queens::row
    IL_00a1: ldloc.0
    IL_00a2: ldsfld bool[] Queens::up
    IL_00a7: ldloc.0
    IL_00a8: ldarg.0
    IL_00a9: add
    IL_00aa: ldsfld bool[] Queens::down
    IL_00af: ldloc.0
    IL_00b0: ldarg.0
    IL_00b1: sub
    IL_00b2: ldc.i4.7
    IL_00b3: add
    IL_00b4: ldc.i4.0
    IL_00b5: dup
    IL_00b6: stloc.1
    IL_00b7: stelem.i1
    IL_00b8: ldloc.1
    IL_00b9: dup
    IL_00ba: stloc.1
    IL_00bb: stelem.i1
    IL_00bc: ldloc.1
    IL_00bd: stelem.i1
    IL_00be: ldloc.0
    IL_00bf: ldc.i4.1
    IL_00c0: add
    IL_00c1: stloc.0
    IL_00c2: ldloc.0
    IL_00c3: ldc.i4.8
    IL_00c4: blt IL_0007
    IL_00c9: ret
  }
  .method static void Main()   // RVA 0x2126, 32 bytes
  {
    .entrypoint
    .maxstack 8
    IL_0000: ldc.i4.0
    IL_0001: call void Queens::Place(int32)
    IL_0006: ldsflda int32 Queens::solutions
    IL_000b: call instance string [System.Private.CoreLib]System.Int32::ToString()
    IL_0010: ldstr " solutions"
    IL_0015: call string [System.Private.CoreLib]System.String::Concat(string, string)
    IL_001a: call void [System.Console]System.Console::WriteLine(string)
    IL_001f: ret
  }
  .method instance void .ctor()   // RVA 0x2147, 7 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ret
  }
  .method static void .cctor()   // RVA 0x214f, 47 bytes
  {
    .maxstack 8
    IL_0000: ldc.i4.8
    IL_0001: newarr [System.Private.CoreLib]System.Boolean
    IL_0006: stsfld bool[] Queens::row
    IL_000b: ldc.i4.s 15
    IL_000d: newarr [System.Private.CoreLib]System.Boolean
    IL_0012: stsfld bool[] Queens::up
    IL_0017: ldc.i4.s 15
    IL_0019: newarr [System.Private.CoreLib]System.Boolean
    IL_001e: stsfld bool[] Queens::down
    IL_0023: ldc.i4.8
    IL_0024: newarr [System.Private.CoreLib]System.Int32
    IL_0029: stsfld int32[] Queens::at
    IL_002e: ret
  }
}

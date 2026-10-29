.assembly vec
.assembly extern System.Private.CoreLib
.assembly extern System.Console

.class <Module>
{
}

.class Vec extends [System.Private.CoreLib]System.ValueType
{
  .field int32 X
  .field int32 Y
  .method instance void .ctor(int32, int32)   // RVA 0x2050, 15 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldarg.1
    IL_0002: stfld int32 Vec::X
    IL_0007: ldarg.0
    IL_0008: ldarg.2
    IL_0009: stfld int32 Vec::Y
    IL_000e: ret
  }
  .method static valuetype Vec op_Addition(valuetype Vec, valuetype Vec)   // RVA 0x2060, 32 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldfld int32 Vec::X
    IL_0006: ldarg.1
    IL_0007: ldfld int32 Vec::X
    IL_000c: add
    IL_000d: ldarg.0
    IL_000e: ldfld int32 Vec::Y
    IL_0013: ldarg.1
    IL_0014: ldfld int32 Vec::Y
    IL_0019: add
    IL_001a: newobj instance void Vec::.ctor(int32, int32)
    IL_001f: ret
  }
  .method virtual instance string ToString()   // RVA 0x2084, 64 bytes
  {
    .maxstack 4
    IL_0000: ldc.i4.5
    IL_0001: newarr [System.Private.CoreLib]System.String
    IL_0006: dup
    IL_0007: ldc.i4.0
    IL_0008: ldstr "("
    IL_000d: stelem.ref
    IL_000e: dup
    IL_000f: ldc.i4.1
    IL_0010: ldarg.0
    IL_0011: ldflda int32 Vec::X
    IL_0016: call instance string [System.Private.CoreLib]System.Int32::ToString()
    IL_001b: stelem.ref
    IL_001c: dup
    IL_001d: ldc.i4.2
    IL_001e: ldstr ","
    IL_0023: stelem.ref
    IL_0024: dup
    IL_0025: ldc.i4.3
    IL_0026: ldarg.0
    IL_0027: ldflda int32 Vec::Y
    IL_002c: call instance string [System.Private.CoreLib]System.Int32::ToString()
    IL_0031: stelem.ref
    IL_0032: dup
    IL_0033: ldc.i4.4
    IL_0034: ldstr ")"
    IL_0039: stelem.ref
    IL_003a: call string [System.Private.CoreLib]System.String::Concat(string[])
    IL_003f: ret
  }
}

.class VecMain extends [System.Private.CoreLib]System.Object
{
  .method static void Double(valuetype Vec&)   // RVA 0x20d0, 23 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldflda int32 Vec::X
    IL_0006: dup
    IL_0007: ldind.i4
    IL_0008: ldc.i4.2
    IL_0009: mul
    IL_000a: stind.i4
    IL_000b: ldarg.0
    IL_000c: ldflda int32 Vec::Y
    IL_0011: dup
    IL_0012: ldind.i4
    IL_0013: ldc.i4.2
    IL_0014: mul
    IL_0015: stind.i4
    IL_0016: ret
  }
  .method static void Halve(valuetype Vec)   // RVA 0x20e8, 25 bytes
  {
    .maxstack 8
    IL_0000: ldarga.s 0
    IL_0002: ldflda int32 Vec::X
    IL_0007: dup
    IL_0008: ldind.i4
    IL_0009: ldc.i4.2
    IL_000a: div
    IL_000b: stind.i4
    IL_000c: ldarga.s 0
    IL_000e: ldflda int32 Vec::Y
    IL_0013: dup
    IL_0014: ldind.i4
    IL_0015: ldc.i4.2
    IL_0016: div
    IL_0017: stind.i4
    IL_0018: ret
  }
  .method static void Main()   // RVA 0x2104, 183 bytes
  {
    .entrypoint
    .maxstack 3
    .locals (valuetype Vec, valuetype Vec, valuetype Vec, int64)
    IL_0000: ldloca.s 0
    IL_0002: ldc.i4.1
    IL_0003: ldc.i4.2
    IL_0004: call instance void Vec::.ctor(int32, int32)
    IL_0009: ldloc.0
    IL_000a: stloc.1
    IL_000b: ldloca.s 1
    IL_000d: ldc.i4.s 10
    IL_000f: stfld int32 Vec::X
    IL_0014: ldloc.0
    IL_0015: box Vec
    IL_001a: call void [System.Console]System.Console::WriteLine(object)
    IL_001f: ldloc.0
    IL_0020: ldloc.1
    IL_0021: call valuetype Vec Vec::op_Addition(valuetype Vec, valuetype Vec)
    IL_0026: box Vec
    IL_002b: call void [System.Console]System.Console::WriteLine(object)
    IL_0030: ldloca.s 0
    IL_0032: call void VecMain::Double(valuetype Vec&)
    IL_0037: ldloc.0
    IL_0038: call void VecMain::Halve(valuetype Vec)
    IL_003d: ldloc.0
    IL_003e: box Vec
    IL_0043: call void [System.Console]System.Console::WriteLine(object)
    IL_0048: ldloc.0
    IL_0049: box Vec
    IL_004e: ldloca.s 0
    IL_0050: ldc.i4.0
    IL_0051: stfld int32 Vec::X
    IL_0056: dup
    IL_0057: call void [System.Console]System.Console::WriteLine(object)
    IL_005c: unbox.any Vec
    IL_0061: stloc.2
    IL_0062: ldloc.2
    IL_0063: ldfld int32 Vec::X
    IL_0068: call void [System.Console]System.Console::WriteLine(int32)
    IL_006d: ldc.i4.3
    IL_006e: newarr Vec
    IL_0073: dup
    IL_0074: ldc.i4.1
    IL_0075: ldelema Vec
    IL_007a: ldc.i4.7
    IL_007b: stfld int32 Vec::Y
    IL_0080: ldc.i4.1
    IL_0081: ldelem Vec
    IL_0086: box Vec
    IL_008b: call void [System.Console]System.Console::WriteLine(object)
    IL_0090: ldc.i8 1099511627776
    IL_0099: stloc.3
    IL_009a: ldc.r8 1.5
    IL_00a3: ldloc.2
    IL_00a4: ldfld int32 Vec::X
    IL_00a9: conv.r8
    IL_00aa: mul
    IL_00ab: ldloc.3
    IL_00ac: call void [System.Console]System.Console::WriteLine(int64)
    IL_00b1: call void [System.Console]System.Console::WriteLine(float64)
    IL_00b6: ret
  }
  .method instance void .ctor()   // RVA 0x21c7, 7 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ret
  }
}

.assembly exceptions
.assembly extern System.Private.CoreLib
.assembly extern System.Console

.class <Module>
{
}

.class Refused extends [System.Private.CoreLib]System.Exception
{
  .field int32 Code
  .method instance void .ctor(string, int32)   // RVA 0x2050, 15 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldarg.1
    IL_0002: call instance void [System.Private.CoreLib]System.Exception::.ctor(string)
    IL_0007: ldarg.0
    IL_0008: ldarg.2
    IL_0009: stfld int32 Refused::Code
    IL_000e: ret
  }
}

.class Exceptions extends [System.Private.CoreLib]System.Object
{
  .method static int32 Check(int32)   // RVA 0x2060, 21 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldc.i4.0
    IL_0002: bge.s IL_0010
    IL_0004: ldstr "negative"
    IL_0009: ldarg.0
    IL_000a: newobj instance void Refused::.ctor(string, int32)
    IL_000f: throw
    IL_0010: ldc.i4.s 100
    IL_0012: ldarg.0
    IL_0013: div
    IL_0014: ret
  }
  .method static void Try(int32)   // RVA 0x2078, 85 bytes
  {
    .maxstack 3
    .locals (class Refused)
    IL_0000: ldarg.0
    IL_0001: call int32 Exceptions::Check(int32)
    IL_0006: call void [System.Console]System.Console::WriteLine(int32)
    IL_000b: leave.s IL_0054
    IL_000d: stloc.0
    IL_000e: ldloc.0
    IL_000f: callvirt instance string [System.Private.CoreLib]System.Exception::get_Message()
    IL_0014: ldstr " "
    IL_0019: ldloc.0
    IL_001a: ldflda int32 Refused::Code
    IL_001f: call instance string [System.Private.CoreLib]System.Int32::ToString()
    IL_0024: call string [System.Private.CoreLib]System.String::Concat(string, string, string)
    IL_0029: call void [System.Console]System.Console::WriteLine(string)
    IL_002e: leave.s IL_0054
    IL_0030: pop
    IL_0031: ldstr "by zero"
    IL_0036: call void [System.Console]System.Console::WriteLine(string)
    IL_003b: leave.s IL_0054
    IL_003d: ldstr "tried "
    IL_0042: ldarga.s 0
    IL_0044: call instance string [System.Private.CoreLib]System.Int32::ToString()
    IL_0049: call string [System.Private.CoreLib]System.String::Concat(string, string)
    IL_004e: call void [System.Console]System.Console::WriteLine(string)
    IL_0053: endfinally
    IL_0054: ret
    .try IL_0000 to IL_000d catch Refused handler IL_000d to IL_0030
    .try IL_0000 to IL_000d catch [System.Private.CoreLib]System.DivideByZeroException handler IL_0030 to IL_003d
    .try IL_0000 to IL_003d finally handler IL_003d to IL_0054
  }
  .method static void Main()   // RVA 0x2104, 101 bytes
  {
    .entrypoint
    .maxstack 3
    .locals (int32[], string, object)
    IL_0000: ldc.i4.5
    IL_0001: call void Exceptions::Try(int32)
    IL_0006: ldc.i4.m1
    IL_0007: call void Exceptions::Try(int32)
    IL_000c: ldc.i4.0
    IL_000d: call void Exceptions::Try(int32)
    IL_0012: ldc.i4.2
    IL_0013: newarr [System.Private.CoreLib]System.Int32
    IL_0018: stloc.0
    IL_0019: ldloc.0
    IL_001a: ldc.i4.2
    IL_001b: ldc.i4.1
    IL_001c: stelem.i4
    IL_001d: leave.s IL_002c
    IL_001f: pop
    IL_0020: ldstr "out of range"
    IL_0025: call void [System.Console]System.Console::WriteLine(string)
    IL_002a: leave.s IL_002c
    IL_002c: ldnull
    IL_002d: stloc.1
    IL_002e: ldloc.1
    IL_002f: callvirt instance int32 [System.Private.CoreLib]System.String::get_Length()
    IL_0034: call void [System.Console]System.Console::WriteLine(int32)
    IL_0039: leave.s IL_0048
    IL_003b: pop
    IL_003c: ldstr "null"
    IL_0041: call void [System.Console]System.Console::WriteLine(string)
    IL_0046: leave.s IL_0048
    IL_0048: ldstr "text"
    IL_004d: stloc.2
    IL_004e: ldloc.2
    IL_004f: castclass Exceptions
    IL_0054: pop
    IL_0055: leave.s IL_0064
    IL_0057: pop
    IL_0058: ldstr "bad cast"
    IL_005d: call void [System.Console]System.Console::WriteLine(string)
    IL_0062: leave.s IL_0064
    IL_0064: ret
    .try IL_0019 to IL_001f catch [System.Private.CoreLib]System.IndexOutOfRangeException handler IL_001f to IL_002c
    .try IL_002e to IL_003b catch [System.Private.CoreLib]System.NullReferenceException handler IL_003b to IL_0048
    .try IL_004e to IL_0057 catch [System.Private.CoreLib]System.InvalidCastException handler IL_0057 to IL_0064
  }
  .method instance void .ctor()   // RVA 0x21a0, 7 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ret
  }
}

.assembly generic
.assembly extern System.Private.CoreLib
.assembly extern System.Console

.class <Module>
{
}

.class Stack`1 extends [System.Private.CoreLib]System.Object
{
  .field !0[] items
  .field int32 n
  .method instance void Push(!0)   // RVA 0x2050, 103 bytes
  {
    .maxstack 4
    .locals (!0[], int32, int32)
    IL_0000: ldarg.0
    IL_0001: ldfld int32 class Stack`1<!0>::n
    IL_0006: ldarg.0
    IL_0007: ldfld !0[] class Stack`1<!0>::items
    IL_000c: ldlen
    IL_000d: conv.i4
    IL_000e: bne.un.s IL_0049
    IL_0010: ldc.i4.2
    IL_0011: ldarg.0
    IL_0012: ldfld int32 class Stack`1<!0>::n
    IL_0017: mul
    IL_0018: newarr !0
    IL_001d: stloc.0
    IL_001e: ldc.i4.0
    IL_001f: stloc.1
    IL_0020: br.s IL_0039
    IL_0022: ldloc.0
    IL_0023: ldloc.1
    IL_0024: ldarg.0
    IL_0025: ldfld !0[] class Stack`1<!0>::items
    IL_002a: ldloc.1
    IL_002b: ldelem !0
    IL_0030: stelem !0
    IL_0035: ldloc.1
    IL_0036: ldc.i4.1
    IL_0037: add
    IL_0038: stloc.1
    IL_0039: ldloc.1
    IL_003a: ldarg.0
    IL_003b: ldfld int32 class Stack`1<!0>::n
    IL_0040: blt.s IL_0022
    IL_0042: ldarg.0
    IL_0043: ldloc.0
    IL_0044: stfld !0[] class Stack`1<!0>::items
    IL_0049: ldarg.0
    IL_004a: ldfld !0[] class Stack`1<!0>::items
    IL_004f: ldarg.0
    IL_0050: ldarg.0
    IL_0051: ldfld int32 class Stack`1<!0>::n
    IL_0056: stloc.2
    IL_0057: ldloc.2
    IL_0058: ldc.i4.1
    IL_0059: add
    IL_005a: stfld int32 class Stack`1<!0>::n
    IL_005f: ldloc.2
    IL_0060: ldarg.1
    IL_0061: stelem !0
    IL_0066: ret
  }
  .method instance !0 Pop()   // RVA 0x20c4, 29 bytes
  {
    .maxstack 4
    .locals (int32)
    IL_0000: ldarg.0
    IL_0001: ldfld !0[] class Stack`1<!0>::items
    IL_0006: ldarg.0
    IL_0007: ldarg.0
    IL_0008: ldfld int32 class Stack`1<!0>::n
    IL_000d: ldc.i4.1
    IL_000e: sub
    IL_000f: stloc.0
    IL_0010: ldloc.0
    IL_0011: stfld int32 class Stack`1<!0>::n
    IL_0016: ldloc.0
    IL_0017: ldelem !0
    IL_001c: ret
  }
  .method instance bool get_Empty()   // RVA 0x20ed, 10 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldfld int32 class Stack`1<!0>::n
    IL_0006: ldc.i4.0
    IL_0007: ceq
    IL_0009: ret
  }
  .method instance string What()   // RVA 0x20f8, 26 bytes
  {
    .maxstack 8
    IL_0000: ldstr "a stack of "
    IL_0005: ldtoken !0
    IL_000a: call class [System.Private.CoreLib]System.Type [System.Private.CoreLib]System.Type::GetTypeFromHandle(valuetype [System.Private.CoreLib]System.RuntimeTypeHandle)
    IL_000f: callvirt instance string [System.Private.CoreLib]System.Reflection.MemberInfo::get_Name()
    IL_0014: call string [System.Private.CoreLib]System.String::Concat(string, string)
    IL_0019: ret
  }
  .method instance void .ctor()   // RVA 0x2113, 19 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldc.i4.4
    IL_0002: newarr !0
    IL_0007: stfld !0[] class Stack`1<!0>::items
    IL_000c: ldarg.0
    IL_000d: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0012: ret
  }
}

.class Pair`2 extends [System.Private.CoreLib]System.Object
{
  .field !0 First
  .field !1 Second
  .method instance void .ctor(!0, !1)   // RVA 0x2127, 21 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ldarg.0
    IL_0007: ldarg.1
    IL_0008: stfld !0 class Pair`2<!0, !1>::First
    IL_000d: ldarg.0
    IL_000e: ldarg.2
    IL_000f: stfld !1 class Pair`2<!0, !1>::Second
    IL_0014: ret
  }
}

.class Generic extends [System.Private.CoreLib]System.Object
{
  .method static void Swap<!!0>(!!0&, !!0&)   // RVA 0x2140, 27 bytes
  {
    .maxstack 2
    .locals (!!0)
    IL_0000: ldarg.0
    IL_0001: ldobj !!0
    IL_0006: stloc.0
    IL_0007: ldarg.0
    IL_0008: ldarg.1
    IL_0009: ldobj !!0
    IL_000e: stobj !!0
    IL_0013: ldarg.1
    IL_0014: ldloc.0
    IL_0015: stobj !!0
    IL_001a: ret
  }
  .method static class Pair`2<!!1, !!0> Flip<!!0, !!1>(class Pair`2<!!0, !!1>)   // RVA 0x2167, 18 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldfld !1 class Pair`2<!!0, !!1>::Second
    IL_0006: ldarg.0
    IL_0007: ldfld !0 class Pair`2<!!0, !!1>::First
    IL_000c: newobj instance void class Pair`2<!!1, !!0>::.ctor(!0, !1)
    IL_0011: ret
  }
  .method static void Main()   // RVA 0x217c, 236 bytes
  {
    .entrypoint
    .maxstack 3
    .locals (class Stack`1<int32>, class Stack`1<string>, int32, string, string, class Pair`2<string, int32>, int32)
    IL_0000: newobj instance void class Stack`1<int32>::.ctor()
    IL_0005: stloc.0
    IL_0006: newobj instance void class Stack`1<string>::.ctor()
    IL_000b: stloc.1
    IL_000c: ldc.i4.0
    IL_000d: stloc.s 6
    IL_000f: br.s IL_0022
    IL_0011: ldloc.0
    IL_0012: ldloc.s 6
    IL_0014: ldloc.s 6
    IL_0016: mul
    IL_0017: callvirt instance void class Stack`1<int32>::Push(!0)
    IL_001c: ldloc.s 6
    IL_001e: ldc.i4.1
    IL_001f: add
    IL_0020: stloc.s 6
    IL_0022: ldloc.s 6
    IL_0024: ldc.i4.s 10
    IL_0026: blt.s IL_0011
    IL_0028: ldloc.1
    IL_0029: ldstr "a"
    IL_002e: callvirt instance void class Stack`1<string>::Push(!0)
    IL_0033: ldloc.1
    IL_0034: ldstr "b"
    IL_0039: callvirt instance void class Stack`1<string>::Push(!0)
    IL_003e: ldloc.0
    IL_003f: callvirt instance string class Stack`1<int32>::What()
    IL_0044: call void [System.Console]System.Console::WriteLine(string)
    IL_0049: ldloc.1
    IL_004a: callvirt instance string class Stack`1<string>::What()
    IL_004f: call void [System.Console]System.Console::WriteLine(string)
    IL_0054: ldc.i4.0
    IL_0055: stloc.2
    IL_0056: br.s IL_0061
    IL_0058: ldloc.2
    IL_0059: ldloc.0
    IL_005a: callvirt instance !0 class Stack`1<int32>::Pop()
    IL_005f: add
    IL_0060: stloc.2
    IL_0061: ldloc.0
    IL_0062: callvirt instance bool class Stack`1<int32>::get_Empty()
    IL_0067: brfalse.s IL_0058
    IL_0069: ldloc.2
    IL_006a: call void [System.Console]System.Console::WriteLine(int32)
    IL_006f: ldstr "left"
    IL_0074: stloc.3
    IL_0075: ldstr "right"
    IL_007a: stloc.s 4
    IL_007c: ldloca.s 3
    IL_007e: ldloca.s 4
    IL_0080: call void Generic::Swap<!!0>(!!0&, !!0&) with <string>
    IL_0085: ldloc.3
    IL_0086: ldstr " "
    IL_008b: ldloc.1
    IL_008c: callvirt instance !0 class Stack`1<string>::Pop()
    IL_0091: call string [System.Private.CoreLib]System.String::Concat(string, string, string)
    IL_0096: call void [System.Console]System.Console::WriteLine(string)
    IL_009b: ldc.i4.1
    IL_009c: ldstr "one"
    IL_00a1: newobj instance void class Pair`2<int32, string>::.ctor(!0, !1)
    IL_00a6: call class Pair`2<!!1, !!0> Generic::Flip<!!0, !!1>(class Pair`2<!!0, !!1>) with <int32, string>
    IL_00ab: stloc.s 5
    IL_00ad: ldloc.s 5
    IL_00af: ldfld !0 class Pair`2<string, int32>::First
    IL_00b4: ldstr " "
    IL_00b9: ldloc.s 5
    IL_00bb: ldflda !1 class Pair`2<string, int32>::Second
    IL_00c0: call instance string [System.Private.CoreLib]System.Int32::ToString()
    IL_00c5: call string [System.Private.CoreLib]System.String::Concat(string, string, string)
    IL_00ca: call void [System.Console]System.Console::WriteLine(string)
    IL_00cf: ldloc.0
    IL_00d0: dup
    IL_00d1: isinst class Stack`1<int32>
    IL_00d6: ldnull
    IL_00d7: cgt.un
    IL_00d9: call void [System.Console]System.Console::WriteLine(bool)
    IL_00de: isinst class Stack`1<string>
    IL_00e3: ldnull
    IL_00e4: cgt.un
    IL_00e6: call void [System.Console]System.Console::WriteLine(bool)
    IL_00eb: ret
  }
  .method instance void .ctor()   // RVA 0x2274, 7 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ret
  }
}

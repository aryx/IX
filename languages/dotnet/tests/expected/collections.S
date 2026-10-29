.assembly collections
.assembly extern System.Private.CoreLib
.assembly extern System.Console

.class <Module>
{
}

.class Collections extends [System.Private.CoreLib]System.Object
{
  .method static void Main()   // RVA 0x2050, 310 bytes
  {
    .entrypoint
    .maxstack 4
    .locals (class [System.Private.CoreLib]System.Collections.Generic.List`1<int32>, class [System.Private.CoreLib]System.Collections.Generic.Dictionary`2<string, int32>, int32, int32, int32, bool, valuetype [System.Private.CoreLib]System.Collections.Generic.List`1/Enumerator<int32>, int32, string[], int32, string)
    IL_0000: newobj instance void class [System.Private.CoreLib]System.Collections.Generic.List`1<int32>::.ctor()
    IL_0005: stloc.0
    IL_0006: ldc.i4.2
    IL_0007: stloc.s 4
    IL_0009: br.s IL_0058
    IL_000b: ldc.i4.1
    IL_000c: stloc.s 5
    IL_000e: ldloc.0
    IL_000f: callvirt instance valuetype [System.Private.CoreLib]System.Collections.Generic.List`1/Enumerator<!0> class [System.Private.CoreLib]System.Collections.Generic.List`1<int32>::GetEnumerator()
    IL_0014: stloc.s 6
    IL_0016: br.s IL_002d
    IL_0018: ldloca.s 6
    IL_001a: call instance !0 valuetype [System.Private.CoreLib]System.Collections.Generic.List`1/Enumerator<int32>::get_Current()
    IL_001f: stloc.s 7
    IL_0021: ldloc.s 4
    IL_0023: ldloc.s 7
    IL_0025: rem
    IL_0026: brtrue.s IL_002d
    IL_0028: ldc.i4.0
    IL_0029: stloc.s 5
    IL_002b: leave.s IL_0046
    IL_002d: ldloca.s 6
    IL_002f: call instance bool valuetype [System.Private.CoreLib]System.Collections.Generic.List`1/Enumerator<int32>::MoveNext()
    IL_0034: brtrue.s IL_0018
    IL_0036: leave.s IL_0046
    IL_0038: ldloca.s 6
    IL_003a: constrained. valuetype [System.Private.CoreLib]System.Collections.Generic.List`1/Enumerator<int32>
    IL_0040: callvirt instance void [System.Private.CoreLib]System.IDisposable::Dispose()
    IL_0045: endfinally
    IL_0046: ldloc.s 5
    IL_0048: brfalse.s IL_0052
    IL_004a: ldloc.0
    IL_004b: ldloc.s 4
    IL_004d: callvirt instance void class [System.Private.CoreLib]System.Collections.Generic.List`1<int32>::Add(!0)
    IL_0052: ldloc.s 4
    IL_0054: ldc.i4.1
    IL_0055: add
    IL_0056: stloc.s 4
    IL_0058: ldloc.s 4
    IL_005a: ldc.i4.s 50
    IL_005c: blt.s IL_000b
    IL_005e: ldloc.0
    IL_005f: callvirt instance int32 class [System.Private.CoreLib]System.Collections.Generic.List`1<int32>::get_Count()
    IL_0064: call void [System.Console]System.Console::WriteLine(int32)
    IL_0069: ldloc.0
    IL_006a: ldloc.0
    IL_006b: callvirt instance int32 class [System.Private.CoreLib]System.Collections.Generic.List`1<int32>::get_Count()
    IL_0070: ldc.i4.1
    IL_0071: sub
    IL_0072: callvirt instance !0 class [System.Private.CoreLib]System.Collections.Generic.List`1<int32>::get_Item(int32)
    IL_0077: call void [System.Console]System.Console::WriteLine(int32)
    IL_007c: newobj instance void class [System.Private.CoreLib]System.Collections.Generic.Dictionary`2<string, int32>::.ctor()
    IL_0081: stloc.1
    IL_0082: ldloc.1
    IL_0083: ldstr "ada"
    IL_0088: ldc.i4.s 36
    IL_008a: callvirt instance void class [System.Private.CoreLib]System.Collections.Generic.Dictionary`2<string, int32>::set_Item(!0, !1)
    IL_008f: ldloc.1
    IL_0090: ldstr "alan"
    IL_0095: ldc.i4.s 41
    IL_0097: callvirt instance void class [System.Private.CoreLib]System.Collections.Generic.Dictionary`2<string, int32>::set_Item(!0, !1)
    IL_009c: ldloc.1
    IL_009d: ldstr "ada"
    IL_00a2: ldloc.1
    IL_00a3: ldstr "ada"
    IL_00a8: callvirt instance !1 class [System.Private.CoreLib]System.Collections.Generic.Dictionary`2<string, int32>::get_Item(!0)
    IL_00ad: ldc.i4.1
    IL_00ae: add
    IL_00af: callvirt instance void class [System.Private.CoreLib]System.Collections.Generic.Dictionary`2<string, int32>::set_Item(!0, !1)
    IL_00b4: ldloc.1
    IL_00b5: ldstr "alan"
    IL_00ba: ldloca.s 2
    IL_00bc: callvirt instance bool class [System.Private.CoreLib]System.Collections.Generic.Dictionary`2<string, int32>::TryGetValue(!0, !1&)
    IL_00c1: brfalse.s IL_00c9
    IL_00c3: ldloc.2
    IL_00c4: call void [System.Console]System.Console::WriteLine(int32)
    IL_00c9: ldloc.1
    IL_00ca: ldstr "grace"
    IL_00cf: callvirt instance bool class [System.Private.CoreLib]System.Collections.Generic.Dictionary`2<string, int32>::ContainsKey(!0)
    IL_00d4: call void [System.Console]System.Console::WriteLine(bool)
    IL_00d9: ldloc.1
    IL_00da: ldstr "ada"
    IL_00df: callvirt instance !1 class [System.Private.CoreLib]System.Collections.Generic.Dictionary`2<string, int32>::get_Item(!0)
    IL_00e4: call void [System.Console]System.Console::WriteLine(int32)
    IL_00e9: ldc.i4.3
    IL_00ea: newarr [System.Private.CoreLib]System.String
    IL_00ef: dup
    IL_00f0: ldc.i4.0
    IL_00f1: ldstr "one"
    IL_00f6: stelem.ref
    IL_00f7: dup
    IL_00f8: ldc.i4.1
    IL_00f9: ldstr "two"
    IL_00fe: stelem.ref
    IL_00ff: dup
    IL_0100: ldc.i4.2
    IL_0101: ldstr "three"
    IL_0106: stelem.ref
    IL_0107: ldc.i4.0
    IL_0108: stloc.3
    IL_0109: stloc.s 8
    IL_010b: ldc.i4.0
    IL_010c: stloc.s 9
    IL_010e: br.s IL_0127
    IL_0110: ldloc.s 8
    IL_0112: ldloc.s 9
    IL_0114: ldelem.ref
    IL_0115: stloc.s 10
    IL_0117: ldloc.3
    IL_0118: ldloc.s 10
    IL_011a: callvirt instance int32 [System.Private.CoreLib]System.String::get_Length()
    IL_011f: add
    IL_0120: stloc.3
    IL_0121: ldloc.s 9
    IL_0123: ldc.i4.1
    IL_0124: add
    IL_0125: stloc.s 9
    IL_0127: ldloc.s 9
    IL_0129: ldloc.s 8
    IL_012b: ldlen
    IL_012c: conv.i4
    IL_012d: blt.s IL_0110
    IL_012f: ldloc.3
    IL_0130: call void [System.Console]System.Console::WriteLine(int32)
    IL_0135: ret
    .try IL_0016 to IL_0038 finally handler IL_0038 to IL_0046
  }
  .method instance void .ctor()   // RVA 0x21a4, 7 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ret
  }
}

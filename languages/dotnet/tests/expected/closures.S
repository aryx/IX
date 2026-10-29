.assembly closures
.assembly extern System.Private.CoreLib
.assembly extern System.Console

.class <Module>
{
}

.class Binary extends [System.Private.CoreLib]System.MulticastDelegate
{
  .method instance void .ctor(object, native int)   // runtime
  .method virtual instance int32 Invoke(int32, int32)   // runtime
  .method virtual instance class [System.Private.CoreLib]System.IAsyncResult BeginInvoke(int32, int32, class [System.Private.CoreLib]System.AsyncCallback, object)   // runtime
  .method virtual instance int32 EndInvoke(class [System.Private.CoreLib]System.IAsyncResult)   // runtime
}

.class Closures extends [System.Private.CoreLib]System.Object
{
  .method static int32 Add(int32, int32)   // RVA 0x2050, 4 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldarg.1
    IL_0002: add
    IL_0003: ret
  }
  .method static class [System.Private.CoreLib]System.Func`1<int32> Counter()   // RVA 0x2055, 24 bytes
  {
    .maxstack 8
    IL_0000: newobj instance void Closures/<>c__DisplayClass1_0::.ctor()
    IL_0005: dup
    IL_0006: ldc.i4.0
    IL_0007: stfld int32 Closures/<>c__DisplayClass1_0::n
    IL_000c: ldftn instance int32 Closures/<>c__DisplayClass1_0::<Counter>b__0()
    IL_0012: newobj instance void class [System.Private.CoreLib]System.Func`1<int32>::.ctor(object, native int)
    IL_0017: ret
  }
  .method static int32 Twice(class [System.Private.CoreLib]System.Func`2<int32, int32>, int32)   // RVA 0x206e, 14 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldarg.0
    IL_0002: ldarg.1
    IL_0003: callvirt instance !1 class [System.Private.CoreLib]System.Func`2<int32, int32>::Invoke(!0)
    IL_0008: callvirt instance !1 class [System.Private.CoreLib]System.Func`2<int32, int32>::Invoke(!0)
    IL_000d: ret
  }
  .method static void Main()   // RVA 0x2080, 197 bytes
  {
    .entrypoint
    .maxstack 4
    .locals (class [System.Private.CoreLib]System.Func`1<int32>)
    IL_0000: newobj instance void Closures/<>c__DisplayClass3_0::.ctor()
    IL_0005: ldsfld class Binary Closures/<>O::<0>__Add
    IL_000a: dup
    IL_000b: brtrue.s IL_0020
    IL_000d: pop
    IL_000e: ldnull
    IL_000f: ldftn int32 Closures::Add(int32, int32)
    IL_0015: newobj instance void Binary::.ctor(object, native int)
    IL_001a: dup
    IL_001b: stsfld class Binary Closures/<>O::<0>__Add
    IL_0020: ldc.i4.2
    IL_0021: ldc.i4.3
    IL_0022: callvirt instance int32 Binary::Invoke(int32, int32)
    IL_0027: call void [System.Console]System.Console::WriteLine(int32)
    IL_002c: ldsfld class Binary Closures/<>c::<>9__3_0
    IL_0031: dup
    IL_0032: brtrue.s IL_004b
    IL_0034: pop
    IL_0035: ldsfld class Closures/<>c Closures/<>c::<>9
    IL_003a: ldftn instance int32 Closures/<>c::<Main>b__3_0(int32, int32)
    IL_0040: newobj instance void Binary::.ctor(object, native int)
    IL_0045: dup
    IL_0046: stsfld class Binary Closures/<>c::<>9__3_0
    IL_004b: ldc.i4.2
    IL_004c: ldc.i4.3
    IL_004d: callvirt instance int32 Binary::Invoke(int32, int32)
    IL_0052: call void [System.Console]System.Console::WriteLine(int32)
    IL_0057: call class [System.Private.CoreLib]System.Func`1<int32> Closures::Counter()
    IL_005c: call class [System.Private.CoreLib]System.Func`1<int32> Closures::Counter()
    IL_0061: stloc.0
    IL_0062: dup
    IL_0063: callvirt instance !0 class [System.Private.CoreLib]System.Func`1<int32>::Invoke()
    IL_0068: pop
    IL_0069: dup
    IL_006a: callvirt instance !0 class [System.Private.CoreLib]System.Func`1<int32>::Invoke()
    IL_006f: pop
    IL_0070: callvirt instance !0 class [System.Private.CoreLib]System.Func`1<int32>::Invoke()
    IL_0075: ldloc.0
    IL_0076: callvirt instance !0 class [System.Private.CoreLib]System.Func`1<int32>::Invoke()
    IL_007b: add
    IL_007c: call void [System.Console]System.Console::WriteLine(int32)
    IL_0081: dup
    IL_0082: ldc.i4.s 10
    IL_0084: stfld int32 Closures/<>c__DisplayClass3_0::k
    IL_0089: ldftn instance int32 Closures/<>c__DisplayClass3_0::<Main>b__1(int32)
    IL_008f: newobj instance void class [System.Private.CoreLib]System.Func`2<int32, int32>::.ctor(object, native int)
    IL_0094: ldc.i4.1
    IL_0095: call int32 Closures::Twice(class [System.Private.CoreLib]System.Func`2<int32, int32>, int32)
    IL_009a: call void [System.Console]System.Console::WriteLine(int32)
    IL_009f: ldsfld class [System.Private.CoreLib]System.Action`1<string> Closures/<>O::<1>__WriteLine
    IL_00a4: dup
    IL_00a5: brtrue.s IL_00ba
    IL_00a7: pop
    IL_00a8: ldnull
    IL_00a9: ldftn void [System.Console]System.Console::WriteLine(string)
    IL_00af: newobj instance void class [System.Private.CoreLib]System.Action`1<string>::.ctor(object, native int)
    IL_00b4: dup
    IL_00b5: stsfld class [System.Private.CoreLib]System.Action`1<string> Closures/<>O::<1>__WriteLine
    IL_00ba: ldstr "done"
    IL_00bf: callvirt instance void class [System.Private.CoreLib]System.Action`1<string>::Invoke(!0)
    IL_00c4: ret
  }
  .method instance void .ctor()   // RVA 0x2151, 7 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ret
  }
}

.class Closures/<>O extends [System.Private.CoreLib]System.Object
{
  .field static class Binary <0>__Add
  .field static class [System.Private.CoreLib]System.Action`1<string> <1>__WriteLine
}

.class Closures/<>c extends [System.Private.CoreLib]System.Object
{
  .field static class Closures/<>c <>9
  .field static class Binary <>9__3_0
  .method static void .cctor()   // RVA 0x2159, 11 bytes
  {
    .maxstack 8
    IL_0000: newobj instance void Closures/<>c::.ctor()
    IL_0005: stsfld class Closures/<>c Closures/<>c::<>9
    IL_000a: ret
  }
  .method instance void .ctor()   // RVA 0x2165, 7 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ret
  }
  .method instance int32 <Main>b__3_0(int32, int32)   // RVA 0x216d, 4 bytes
  {
    .maxstack 8
    IL_0000: ldarg.1
    IL_0001: ldarg.2
    IL_0002: mul
    IL_0003: ret
  }
}

.class Closures/<>c__DisplayClass1_0 extends [System.Private.CoreLib]System.Object
{
  .field int32 n
  .method instance void .ctor()   // RVA 0x2172, 7 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ret
  }
  .method instance int32 <Counter>b__0()   // RVA 0x217c, 18 bytes
  {
    .maxstack 2
    .locals (int32)
    IL_0000: ldarg.0
    IL_0001: ldfld int32 Closures/<>c__DisplayClass1_0::n
    IL_0006: ldc.i4.1
    IL_0007: add
    IL_0008: stloc.0
    IL_0009: ldarg.0
    IL_000a: ldloc.0
    IL_000b: stfld int32 Closures/<>c__DisplayClass1_0::n
    IL_0010: ldloc.0
    IL_0011: ret
  }
}

.class Closures/<>c__DisplayClass3_0 extends [System.Private.CoreLib]System.Object
{
  .field int32 k
  .method instance void .ctor()   // RVA 0x219a, 7 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ret
  }
  .method instance int32 <Main>b__1(int32)   // RVA 0x21a2, 9 bytes
  {
    .maxstack 8
    IL_0000: ldarg.1
    IL_0001: ldarg.0
    IL_0002: ldfld int32 Closures/<>c__DisplayClass3_0::k
    IL_0007: add
    IL_0008: ret
  }
}

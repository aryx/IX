.assembly shapes
.assembly extern System.Private.CoreLib
.assembly extern System.Console

.class <Module>
{
}

.class interface INamed
{
  .method virtual abstract instance string Name()   // no body
}

.class Shape extends [System.Private.CoreLib]System.Object implements INamed
{
  .field int32 x
  .field int32 y
  .field static int32 count
  .method instance void .ctor(int32, int32)   // RVA 0x2050, 33 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ldarg.0
    IL_0007: ldarg.1
    IL_0008: stfld int32 Shape::x
    IL_000d: ldarg.0
    IL_000e: ldarg.2
    IL_000f: stfld int32 Shape::y
    IL_0014: ldsfld int32 Shape::count
    IL_0019: ldc.i4.1
    IL_001a: add
    IL_001b: stsfld int32 Shape::count
    IL_0020: ret
  }
  .method virtual abstract instance int32 Area()   // no body
  .method virtual instance string Name()   // RVA 0x2072, 6 bytes
  {
    .maxstack 8
    IL_0000: ldstr "shape"
    IL_0005: ret
  }
  .method static int32 get_Count()   // RVA 0x2079, 6 bytes
  {
    .maxstack 8
    IL_0000: ldsfld int32 Shape::count
    IL_0005: ret
  }
  .method virtual instance string ToString()   // RVA 0x2080, 31 bytes
  {
    .maxstack 3
    .locals (int32)
    IL_0000: ldarg.0
    IL_0001: callvirt instance string Shape::Name()
    IL_0006: ldstr " of area "
    IL_000b: ldarg.0
    IL_000c: callvirt instance int32 Shape::Area()
    IL_0011: stloc.0
    IL_0012: ldloca.s 0
    IL_0014: call instance string [System.Private.CoreLib]System.Int32::ToString()
    IL_0019: call string [System.Private.CoreLib]System.String::Concat(string, string, string)
    IL_001e: ret
  }
}

.class Square extends Shape
{
  .field int32 side
  .method instance void .ctor(int32, int32, int32)   // RVA 0x20ab, 16 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldarg.1
    IL_0002: ldarg.2
    IL_0003: call instance void Shape::.ctor(int32, int32)
    IL_0008: ldarg.0
    IL_0009: ldarg.3
    IL_000a: stfld int32 Square::side
    IL_000f: ret
  }
  .method virtual instance int32 Area()   // RVA 0x20bc, 14 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldfld int32 Square::side
    IL_0006: ldarg.0
    IL_0007: ldfld int32 Square::side
    IL_000c: mul
    IL_000d: ret
  }
  .method virtual instance string Name()   // RVA 0x20cb, 6 bytes
  {
    .maxstack 8
    IL_0000: ldstr "square"
    IL_0005: ret
  }
}

.class Rect extends Shape
{
  .field int32 w
  .field int32 h
  .method instance void .ctor(int32, int32, int32, int32)   // RVA 0x20d2, 24 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldarg.1
    IL_0002: ldarg.2
    IL_0003: call instance void Shape::.ctor(int32, int32)
    IL_0008: ldarg.0
    IL_0009: ldarg.3
    IL_000a: stfld int32 Rect::w
    IL_000f: ldarg.0
    IL_0010: ldarg.s 4
    IL_0012: stfld int32 Rect::h
    IL_0017: ret
  }
  .method virtual instance int32 Area()   // RVA 0x20eb, 14 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: ldfld int32 Rect::w
    IL_0006: ldarg.0
    IL_0007: ldfld int32 Rect::h
    IL_000c: mul
    IL_000d: ret
  }
}

.class Shapes extends [System.Private.CoreLib]System.Object
{
  .method static void Main()   // RVA 0x20fc, 111 bytes
  {
    .entrypoint
    .maxstack 7
    .locals (class Shape[], int32, int32)
    IL_0000: ldc.i4.2
    IL_0001: newarr Shape
    IL_0006: dup
    IL_0007: ldc.i4.0
    IL_0008: ldc.i4.0
    IL_0009: ldc.i4.0
    IL_000a: ldc.i4.3
    IL_000b: newobj instance void Square::.ctor(int32, int32, int32)
    IL_0010: stelem.ref
    IL_0011: dup
    IL_0012: ldc.i4.1
    IL_0013: ldc.i4.1
    IL_0014: ldc.i4.1
    IL_0015: ldc.i4.2
    IL_0016: ldc.i4.5
    IL_0017: newobj instance void Rect::.ctor(int32, int32, int32, int32)
    IL_001c: stelem.ref
    IL_001d: stloc.0
    IL_001e: ldc.i4.0
    IL_001f: stloc.1
    IL_0020: ldc.i4.0
    IL_0021: stloc.2
    IL_0022: br.s IL_003b
    IL_0024: ldloc.0
    IL_0025: ldloc.2
    IL_0026: ldelem.ref
    IL_0027: call void [System.Console]System.Console::WriteLine(object)
    IL_002c: ldloc.1
    IL_002d: ldloc.0
    IL_002e: ldloc.2
    IL_002f: ldelem.ref
    IL_0030: callvirt instance int32 Shape::Area()
    IL_0035: add
    IL_0036: stloc.1
    IL_0037: ldloc.2
    IL_0038: ldc.i4.1
    IL_0039: add
    IL_003a: stloc.2
    IL_003b: ldloc.2
    IL_003c: ldloc.0
    IL_003d: ldlen
    IL_003e: conv.i4
    IL_003f: blt.s IL_0024
    IL_0041: ldloc.0
    IL_0042: ldc.i4.1
    IL_0043: ldelem.ref
    IL_0044: callvirt instance string INamed::Name()
    IL_0049: call void [System.Console]System.Console::WriteLine(string)
    IL_004e: ldloc.0
    IL_004f: ldc.i4.0
    IL_0050: ldelem.ref
    IL_0051: isinst Square
    IL_0056: ldnull
    IL_0057: cgt.un
    IL_0059: call void [System.Console]System.Console::WriteLine(bool)
    IL_005e: call int32 Shape::get_Count()
    IL_0063: call void [System.Console]System.Console::WriteLine(int32)
    IL_0068: ldloc.1
    IL_0069: call void [System.Console]System.Console::WriteLine(int32)
    IL_006e: ret
  }
  .method instance void .ctor()   // RVA 0x2177, 7 bytes
  {
    .maxstack 8
    IL_0000: ldarg.0
    IL_0001: call instance void [System.Private.CoreLib]System.Object::.ctor()
    IL_0006: ret
  }
}
